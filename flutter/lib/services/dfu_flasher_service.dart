import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:pointycastle/export.dart';

import '../core/constants/dizo_uuids.dart';
import 'htsmart_protocol.dart';

/// Progress callback reporting current progress from 0.0 to 1.0, transfer speed in KB/s, and status message
typedef DfuProgressCallback = void Function(
  double progress,
  int bytesSent,
  int totalBytes,
  double speedKbps,
  String statusMessage,
);

/// Flashes a custom dial binary to DIZO Watch D over BLE with AES-256 ECB encryption
class DfuFlasherService {
  // Realtek 32-byte hardware AES-256 key
  static final Uint8List _aesKey = Uint8List.fromList([
    0x4E, 0x46, 0xF8, 0xC5, 0x09, 0x2B, 0x29, 0xE2,
    0x9A, 0x97, 0x1A, 0x0C, 0xD1, 0xF6, 0x10, 0xFB,
    0x1F, 0x67, 0x63, 0xDF, 0x80, 0x7A, 0x7E, 0x70,
    0x96, 0x0D, 0x4C, 0xD3, 0x11, 0x8E, 0x60, 0x1A,
  ]);

  static Uint8List _encryptBlock(Uint8List block16) {
    final cipher = ECBBlockCipher(AESEngine());
    cipher.init(true, KeyParameter(_aesKey));
    final out = Uint8List(16);
    cipher.processBlock(block16, 0, out, 0);
    return out;
  }

  static Uint8List _encryptPacket(Uint8List data) {
    final length = data.length;
    final blocks = length ~/ 16;
    final cipher = ECBBlockCipher(AESEngine());
    cipher.init(true, KeyParameter(_aesKey));

    final result = Uint8List(length);
    for (int i = 0; i < blocks; i++) {
      cipher.processBlock(data, i * 16, result, i * 16);
    }
    final remainder = length % 16;
    if (remainder != 0) {
      final start = blocks * 16;
      for (int i = 0; i < remainder; i++) {
        result[start + i] = data[start + i];
      }
    }
    return result;
  }

  /// Executes complete DFU session to flash custom watch face
  static Future<void> flashDialBinary({
    required BluetoothDevice device,
    required Uint8List dialBinary,
    required DfuProgressCallback onProgress,
  }) async {
    if (dialBinary.length != 529860) {
      throw Exception('Invalid dial binary size: ${dialBinary.length} (expected 529,860 bytes)');
    }

    onProgress(0.0, 0, 529336, 0, 'Discovering Realtek DFU services...');
    final services = await device.discoverServices();

    // Primary FF02 characteristic (for Enter OTA and Switch Dial)
    final primaryService = services.firstWhere(
      (s) => s.uuid == DizoUuids.servicePrimary,
      orElse: () => throw Exception('Primary service FF01 not found'),
    );
    final charFF02 = primaryService.characteristics.firstWhere(
      (c) => c.uuid == DizoUuids.charFF02Write,
      orElse: () => throw Exception('Characteristic FF02 not found'),
    );

    // Realtek DFU Service (00006287)
    final dfuService = services.firstWhere(
      (s) => s.uuid == DizoUuids.serviceDfu,
      orElse: () => throw Exception('Realtek DFU service 6287 not found on watch'),
    );
    final charDfuControl = dfuService.characteristics.firstWhere(
      (c) => c.uuid == DizoUuids.charDfuControl,
      orElse: () => throw Exception('DFU Control Point 6487 not found'),
    );
    final charDfuData = dfuService.characteristics.firstWhere(
      (c) => c.uuid == DizoUuids.charDfuData,
      orElse: () => throw Exception('DFU Data Endpoint 6387 not found'),
    );

    // Setup notification listener on DFU Control Point (6487) with event queue
    await charDfuControl.setNotifyValue(true);
    final List<List<int>> eventQueue = [];
    final Map<int, Completer<List<int>>> completers = {};

    final sub = charDfuControl.onValueReceived.listen((data) {
      debugPrint('[DFU] 6487 ← ${data.map((b) => b.toRadixString(16).padLeft(2, "0").toUpperCase()).join(" ")}');
      if (data.isNotEmpty && data[0] == 0x10 && data.length >= 2) {
        final opcode = data[1];
        if (completers.containsKey(opcode) && !completers[opcode]!.isCompleted) {
          completers[opcode]!.complete(data);
          completers.remove(opcode);
        } else {
          eventQueue.add(data);
        }
      }
    });

    // Helper to wait for specific opcode response from watch
    Future<List<int>> waitForOpcode(int opcode, {Duration timeout = const Duration(seconds: 4)}) async {
      final existingIdx = eventQueue.indexWhere((d) => d.length >= 2 && d[1] == opcode);
      if (existingIdx >= 0) {
        return eventQueue.removeAt(existingIdx);
      }
      final completer = Completer<List<int>>();
      completers[opcode] = completer;
      return await completer.future.timeout(timeout).whenComplete(() {
        completers.remove(opcode);
      });
    }

    try {
      // Step 1: Request Watch OTA Mode via HTSmart packet on FF02
      onProgress(0.0, 0, 529336, 0, 'Requesting Watch OTA Mode...');
      final enterOtaPkt = HtsmartProtocol.buildPacket(cmdId: 0x01, keyId: 0x01, payload: const []);
      await charFF02.write(enterOtaPkt, withoutResponse: false);
      await Future.delayed(const Duration(milliseconds: 1000));

      // Step 2: Enable Buffer Check Mode (0x09) on 6487
      onProgress(0.01, 0, 529336, 0, 'Configuring Buffer Check Mode...');
      await charDfuControl.write([0x09], withoutResponse: false);
      try {
        await waitForOpcode(0x09, timeout: const Duration(seconds: 3));
      } catch (_) {
        // Continue if timeout (watch defaults to standard buffer check)
      }

      // Step 3: START_DFU (0x01) with AES-256 encrypted 16-byte header
      onProgress(0.02, 0, 529336, 0, 'Initializing DFU session...');
      final imageHeader12 = dialBinary.sublist(512, 524);
      final hdr16 = Uint8List(16);
      hdr16.setRange(0, 12, imageHeader12);
      final encHdr = _encryptBlock(hdr16);
      await charDfuControl.write([0x01, ...encHdr], withoutResponse: false);
      final res01 = await waitForOpcode(0x01, timeout: const Duration(seconds: 4));
      if (res01.length < 3 || res01[2] != 0x01) {
        throw Exception('Watch rejected START_DFU (Status: ${res01.length >= 3 ? res01[2] : "unknown"})');
      }

      // Step 4: RECEIVE_FW_IMAGE (0x02) - Image ID 0x27A1, Offset 12
      const int imageId = 0x27A1;
      const int initialOffset = 12;
      await charDfuControl.write([
        0x02,
        imageId & 0xFF,
        (imageId >> 8) & 0xFF,
        initialOffset & 0xFF,
        (initialOffset >> 8) & 0xFF,
        (initialOffset >> 16) & 0xFF,
        (initialOffset >> 24) & 0xFF,
      ], withoutResponse: false);
      await Future.delayed(const Duration(milliseconds: 100));

      // Step 5: Stream 529,336 bytes payload with AES encryption in 130 sectors
      final streamData = dialBinary.sublist(524);
      final totalBytes = streamData.length;
      const int packetSize = 240;

      // Define 130 sector chunks (Chunk 0 = 4,084B, Chunks 1..128 = 4,096B, Chunk 129 = 952B)
      final List<int> chunkSizes = [4084];
      for (int i = 0; i < 128; i++) {
        chunkSizes.add(4096);
      }
      chunkSizes.add(952);

      int streamOffset = 0;
      final stopwatch = Stopwatch()..start();

      for (int chunkIdx = 0; chunkIdx < chunkSizes.length; chunkIdx++) {
        final chunkSize = chunkSizes[chunkIdx];
        final chunk = streamData.sublist(streamOffset, streamOffset + chunkSize);

        final encChunk = Uint8List(chunkSize);
        int encChunkPos = 0;

        // Stream sub-packets with AES encryption
        for (int i = 0; i < chunkSize; i += packetSize) {
          final end = (i + packetSize < chunkSize) ? i + packetSize : chunkSize;
          final subPacket = chunk.sublist(i, end);
          final encSubPacket = _encryptPacket(subPacket);

          encChunk.setRange(encChunkPos, encChunkPos + encSubPacket.length, encSubPacket);
          encChunkPos += encSubPacket.length;

          await charDfuData.write(encSubPacket, withoutResponse: true);
          await Future.delayed(const Duration(milliseconds: 5));
        }

        // Send Buffer Check (0x0A) using Realtek 16-bit word XOR checksum
        final int sA = _calcDfuChecksum(encChunk);
        final bufCheckCmd = [
          0x0A,
          chunkSize & 0xFF,
          (chunkSize >> 8) & 0xFF,
          sA & 0xFF,
          (sA >> 8) & 0xFF,
        ];
        await charDfuControl.write(bufCheckCmd, withoutResponse: false);

        // Wait for ACK (10 0A 01 <offset>)
        final ack = await waitForOpcode(0x0A, timeout: const Duration(seconds: 4));
        if (ack.length < 3 || ack[2] != 0x01) {
          throw Exception('Buffer check failed at sector $chunkIdx');
        }

        streamOffset += chunkSize;
        final progress = streamOffset / totalBytes;
        final elapsedSec = stopwatch.elapsedMilliseconds / 1000.0;
        final speed = elapsedSec > 0 ? (streamOffset / 1024.0) / elapsedSec : 0.0;

        onProgress(
          progress,
          streamOffset,
          totalBytes,
          speed,
          'Flashing dial: ${(progress * 100).toStringAsFixed(1)}% (${speed.toStringAsFixed(1)} KB/s)',
        );
      }

      // Step 6: Validate Firmware Image (0x03)
      onProgress(0.99, totalBytes, totalBytes, 0, 'Verifying watch face CRC checksum on watch...');
      await charDfuControl.write([0x03, imageId & 0xFF, (imageId >> 8) & 0xFF], withoutResponse: false);
      final res03 = await waitForOpcode(0x03, timeout: const Duration(seconds: 25));

      if (res03.length < 3 || res03[2] != 0x01) {
        throw Exception('Watch CRC verification failed (Status: ${res03.length >= 3 ? res03[2] : "unknown"})');
      }

      // Step 7: ACTIVE_IMAGE_RESET (0x04) to reboot watch
      onProgress(1.0, totalBytes, totalBytes, 0, 'Rebooting DIZO Watch D...');
      try {
        await charDfuControl.write([0x04], withoutResponse: false);
      } catch (_) {
        // Disconnection on reboot is expected
      }

      onProgress(1.0, totalBytes, totalBytes, 0, 'Watch face flashed & verified successfully!');
    } finally {
      await sub.cancel();
    }
  }

  /// Realtek 16-bit word XOR checksum with byteswap as specified in clean protocol
  static int _calcDfuChecksum(Uint8List data) {
    int s = 0;
    final int halfLen = data.length ~/ 2;
    for (int i = 0; i < halfLen; i++) {
      final int val = data[i * 2] | (data[i * 2 + 1] << 8);
      s = (s ^ val) & 0xFFFF;
    }
    return ((s & 0xFF) << 8) | ((s & 0xFF00) >> 8);
  }
}
