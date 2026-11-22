import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart' show Color, Colors;
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import '../core/utils/crc16.dart';
import '../models/clock_style.dart';

/// Injects custom wallpaper and digital clock position/color into DIZO Watch D dial template
class DialBuilderService {
  static const String _templateAsset = 'assets/ota.bin';

  /// Generates a complete 529,860-byte dial binary ready for flashing
  static Future<Uint8List> buildDialBinary({
    required Uint8List wallpaperPngBytes,
    ClockPosition clockPosition = ClockPosition.center,
    bool isClockVisible = true,
    Color textColor = Colors.white,
    int hardwareStyleIndex = 1,
    int clockWidth = 120,
    int clockHeight = 73,
  }) async {
    // 1. Load base template from Flutter assets
    final ByteData assetData = await rootBundle.load(_templateAsset);
    final Uint8List binData = Uint8List.fromList(assetData.buffer.asUint8List());

    if (binData.length != 529860) {
      throw Exception('Invalid base template size: ${binData.length} (expected 529,860 bytes)');
    }

    final ByteData bd = ByteData.sublistView(binData);

    // 2. Decode user's image using pure Dart 'image' package
    final img.Image? decoded = img.decodeImage(wallpaperPngBytes);
    if (decoded == null) {
      throw Exception('Failed to decode wallpaper image bytes');
    }

    // 3. Inject 240x286 Background into Bitmap #180
    final List<Uint8List> bgRows = _imageToRgb565Rows(decoded, 240, 286);
    const int addr180 = 328328;
    for (int y = 0; y < 286; y++) {
      final int ptrOffset = addr180 + y * 4 + 1536;
      final int rowAddr = bd.getUint32(ptrOffset, Endian.little) + 1536;
      binData.setRange(rowAddr, rowAddr + 480, bgRows[y]);
    }

    // 4. Inject 160x190 Preview Thumbnail into Bitmap #181
    final List<Uint8List> thumbRows = _imageToRgb565Rows(decoded, 160, 190);
    const int addr181 = 466756;
    for (int y = 0; y < 190; y++) {
      final int ptrOffset = addr181 + y * 4 + 1536;
      final int rowAddr = bd.getUint32(ptrOffset, Endian.little) + 1536;
      binData.setRange(rowAddr, rowAddr + 320, thumbRows[y]);
    }

    // 5. Position Digital Clock (120x73 box clamped within 240x286 LCD screen)
    final int addrOffset = bd.getUint32(1552, Endian.little);
    final int offsetC = addrOffset + 1536;
    final int controlOffset = bd.getUint32(offsetC, Endian.little);
    final int controlSize = bd.getUint16(offsetC + 6, Endian.little);

    final int maxX = (240 - clockWidth).clamp(0, 240);
    final int maxY = (286 - clockHeight).clamp(0, 286);
    final int targetX = isClockVisible ? clockPosition.x.clamp(0, maxX) : -400;
    final int targetY = isClockVisible ? clockPosition.y.clamp(0, maxY) : -400;

    // Update cVar.q[0] clock coordinates
    bd.setInt16(addrOffset + 1536 + 38, targetX, Endian.little);
    bd.setInt16(addrOffset + 1536 + 40, targetY, Endian.little);

    // Update Control #4 (TIME_STYLE) clock coordinates
    final int ctrl4Base = controlOffset + 4 * controlSize + 1536;
    final int ctrl4Addr = ctrl4Base + 4;
    bd.setInt16(ctrl4Addr, targetX, Endian.little);
    bd.setInt16(ctrl4Addr + 2, targetY, Endian.little);

    // Update RGB Text Color at offset 1544 (clean protocol specification)
    final int argb = textColor.toARGB32();
    final int r = (argb >> 16) & 0xFF;
    final int g = (argb >> 8) & 0xFF;
    final int b = argb & 0xFF;
    binData[1544] = b;
    binData[1545] = g;
    binData[1546] = r;

    // Map to closest hardware style index in Control #4
    int resolvedStyle = hardwareStyleIndex;
    if (resolvedStyle == 1) {
      if (r > 200 && g > 200 && b < 100) {
        resolvedStyle = 4; // Yellow (Bitmap #179)
      } else if (g > 180 && r < 150) {
        resolvedStyle = 2; // Green / Cyan (Bitmap #177)
      } else if (r < 80 && g < 80 && b < 80) {
        resolvedStyle = 3; // Slate / Dark (Bitmap #178)
      }
    }
    binData[ctrl4Base + 18] = resolvedStyle.clamp(0, 4);

    // 6. Recalculate CRC16 and update offset 518..519
    _updateDialCrc16(binData);

    return binData;
  }

  /// Converts an image to RGB565 big-endian rows with aspect-ratio preserving center crop
  static List<Uint8List> _imageToRgb565Rows(img.Image src, int targetW, int targetH) {
    final double scale = math.max(targetW / src.width, targetH / src.height);
    final int newW = (src.width * scale).round();
    final int newH = (src.height * scale).round();
    final img.Image resized = img.copyResize(src, width: newW, height: newH, interpolation: img.Interpolation.linear);
    final int left = ((newW - targetW) / 2).floor();
    final int top = ((newH - targetH) / 2).floor();
    final img.Image cropped = img.copyCrop(resized, x: left, y: top, width: targetW, height: targetH);

    final List<Uint8List> rows = [];
    for (int y = 0; y < targetH; y++) {
      final Uint8List row = Uint8List(targetW * 2);
      for (int x = 0; x < targetW; x++) {
        final pixel = cropped.getPixel(x, y);
        int r = pixel.r.toInt();
        int g = pixel.g.toInt();
        int b = pixel.b.toInt();
        final int a = pixel.a.toInt();

        if (a <= 90) {
          r = 0;
          g = 0;
          b = 0;
        }

        // RGB565 big-endian format:
        // Byte 0: (g >> 5) | (r & 0xF8)
        // Byte 1: ((g << 3) & 0xE0) | (b >> 3)
        row[x * 2] = ((g >> 5) | (r & 0xF8)) & 0xFF;
        row[x * 2 + 1] = (((g << 3) & 0xE0) | (b >> 3)) & 0xFF;
      }
      rows.add(row);
    }
    return rows;
  }

  /// Recalculates and updates the dial image CRC16 at offset 518..519
  static int _updateDialCrc16(Uint8List binBytes) {
    final int length = binBytes.length;
    final Uint8List bArr = Uint8List.fromList(binBytes.sublist(512));

    for (int i = 372; i < 404; i++) {
      bArr[i] = 0xFF;
    }

    final int i4 = length - 1520;
    int crc1 = Crc16.computeSlice(bArr, 12, 740, 0);
    int crc2 = Crc16.computeSlice(bArr, 1008, i4, crc1);

    if (crc2 == 0) {
      bArr[372] = 0;
      crc1 = Crc16.computeSlice(bArr, 12, 740, 0);
      crc2 = Crc16.computeSlice(bArr, 1008, i4, crc1);
    }

    binBytes[518] = crc2 & 0xFF;
    binBytes[519] = (crc2 >> 8) & 0xFF;
    return crc2;
  }
}
