import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import '../core/utils/crc16.dart';
import '../models/clock_style.dart';

/// Injects custom wallpaper and digital clock position into DIZO Watch D dial template
class DialBuilderService {
  static const String _templateAsset = 'assets/ota.bin';

  /// Generates a complete 529,860-byte dial binary ready for flashing
  static Future<Uint8List> buildDialBinary({
    required Uint8List wallpaperPngBytes,
    ClockPosition clockPosition = ClockPosition.bottom,
  }) async {
    // 1. Load base template from Flutter assets
    final ByteData assetData = await rootBundle.load(_templateAsset);
    final Uint8List binData = Uint8List.fromList(assetData.buffer.asUint8List());

    if (binData.length != 529860) {
      throw Exception('Invalid base template size: ${binData.length} (expected 529,860 bytes)');
    }

    final ByteData bd = ByteData.sublistView(binData);

    // 2. Decode user's 240x286 image using pure Dart 'image' package
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

    // 5. Position Digital Clock (Bottom, Top, Left, Right)
    final int addrOffset = bd.getUint32(1552, Endian.little);
    final int offsetC = addrOffset + 1536;
    final int controlOffset = bd.getUint32(offsetC, Endian.little);
    final int ctrl0Addr = controlOffset + 1536;

    bd.setUint16(ctrl0Addr + 8, clockPosition.x, Endian.little);
    bd.setUint16(ctrl0Addr + 10, clockPosition.y, Endian.little);

    // 6. Recalculate CRC16 and update offset 518..519
    _updateDialCrc16(binData);

    return binData;
  }

  /// Converts an image to RGB565 big-endian rows
  static List<Uint8List> _imageToRgb565Rows(img.Image src, int targetW, int targetH) {
    // Resize with aspect ratio preserved (center crop)
    final img.Image resized = img.copyResizeCropSquare(src, size: targetW < targetH ? targetW : targetH);
    final img.Image scaled = img.copyResize(resized, width: targetW, height: targetH, interpolation: img.Interpolation.cubic);

    final List<Uint8List> rows = [];
    for (int y = 0; y < targetH; y++) {
      final Uint8List row = Uint8List(targetW * 2);
      for (int x = 0; x < targetW; x++) {
        final pixel = scaled.getPixel(x, y);
        int r = pixel.r.toInt();
        int g = pixel.g.toInt();
        int b = pixel.b.toInt();
        final int a = pixel.a.toInt();

        if (a <= 90) {
          r = 0;
          g = 0;
          b = 0;
        }

        // RGB565 big-endian:
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
    int crc1 = _calcPartialCrc(bArr, 12, 740, 0);
    int crc2 = _calcPartialCrc(bArr, 1008, i4, crc1);

    if (crc2 == 0) {
      bArr[372] = 0;
      crc1 = _calcPartialCrc(bArr, 12, 740, 0);
      crc2 = _calcPartialCrc(bArr, 1008, i4, crc1);
    }

    binBytes[518] = crc2 & 0xFF;
    binBytes[519] = (crc2 >> 8) & 0xFF;
    return crc2;
  }

  static int _calcPartialCrc(Uint8List data, int start, int len, int initialCrc) {
    int crc = initialCrc;
    final end = start + len;
    for (int i = start; i < end; i++) {
      crc = ((crc >> 8) ^ Crc16computeByte((crc ^ data[i]) & 0xFF)) & 0xFFFF;
    }
    return crc;
  }

  static int Crc16computeByte(int index) {
    return Crc16.compute([index]);
  }
}
