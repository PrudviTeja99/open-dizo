import 'package:flutter_test/flutter_test.dart';
import 'package:open_dizo/services/htsmart_protocol.dart';
import 'package:open_dizo/models/watch_telemetry.dart';

void main() {
  group('HtsmartProtocol & Telemetry Decoding Tests', () {
    test('TodayTotalData Big-Endian decoding and telemetry formatting', () {
      // 30 bytes TodayTotalData:
      // steps = 5432 (0x00001538)
      // distance = 3500 meters (0x00000DAC)
      // calories = 145000 cal (0x00023678) -> 145 kcal
      // deepSleep = 120 mins (0x00000078)
      // lightSleep = 360 mins (0x00000168)
      // hr = 72 bpm (0x00000048)
      final payload = <int>[
        0x00, 0x00, 0x15, 0x38, // Steps: 5432
        0x00, 0x00, 0x0D, 0xAC, // Distance: 3500 m
        0x00, 0x02, 0x36, 0x78, // Calories: 145000 cal
        0x00, 0x00, 0x00, 0x78, // Deep sleep: 120 min
        0x00, 0x00, 0x01, 0x68, // Light sleep: 360 min
        0x00, 0x00, 0x00, 0x48, // HR: 72 BPM
      ];

      int bytesToIntBE(List<int> bytes, int offset, int length) {
        int value = 0;
        for (int i = 0; i < length; i++) {
          if (offset + i < bytes.length) {
            value = (value << 8) | (bytes[offset + i] & 0xFF);
          }
        }
        return value;
      }

      final steps = bytesToIntBE(payload, 0, 4);
      final distMeters = bytesToIntBE(payload, 4, 4).toDouble();
      final calories = bytesToIntBE(payload, 8, 4);
      final deepSleep = bytesToIntBE(payload, 12, 4);
      final lightSleep = bytesToIntBE(payload, 16, 4);
      final hr = bytesToIntBE(payload, 20, 4);

      expect(steps, 5432);
      expect(distMeters, 3500.0);
      expect(calories, 145016);
      expect(deepSleep, 120);
      expect(lightSleep, 360);
      expect(hr, 72);

      final telemetry = WatchTelemetry(
        steps: steps,
        distanceMeters: distMeters,
        calories: calories,
        deepSleepMinutes: deepSleep,
        lightSleepMinutes: lightSleep,
        heartRate: hr,
      );

      expect(telemetry.distanceKmFormatted, '3.50');
      expect(telemetry.caloriesKcal, 145);
      expect(telemetry.totalSleepFormatted, '8h');
    });

    test('RealTimeHealth packet generation matches protocol specification', () {
      final startPacket = HtsmartProtocol.buildRealTimeHealthPacket(
        healthyType: 0x07,
        durationMinutes: 2,
        enable: true,
      );
      // CmdPacket starts at byte 8: [cmdId=5, 0x00, keyId=35, len_hi=0, len_lo=4, keyData=[0, 7, 5, 2]]
      expect(startPacket[8], 0x05);
      expect(startPacket[10], 0x23); // 35
      expect(startPacket.sublist(13, 17), [0x00, 0x07, 0x05, 0x02]);

      final stopPacket = HtsmartProtocol.buildRealTimeHealthPacket(
        healthyType: 0x07,
        durationMinutes: 0,
        enable: false,
      );
      expect(stopPacket[8], 0x05);
      expect(stopPacket[10], 0x23);
      expect(stopPacket.sublist(13, 17), [0x00, 0x00, 0x05, 0x00]);
    });

    test('BrightnessVibrateConfig packet contains mandatory 38 bytes and presets', () {
      final packet = HtsmartProtocol.buildBrightnessVibratePacket(
        brightness: 4,
        timeoutSeconds: 10,
        vibration: 2,
      );

      // Packet has 8-byte transport header + 5-byte cmd/key header + 38-byte payload = 51 bytes
      expect(packet.length, 51);
      final payload = packet.sublist(13);
      expect(payload.length, 38);

      // Timeout (offset 0..6)
      expect(payload[0], 10);
      expect(payload[1], 3);

      // TurnWristBrightDuration (offset 7..13) must be non-zero
      expect(payload[7], 5);
      expect(payload[8], 3);

      // Brightness (offset 24..30)
      expect(payload[24], 4);
      expect(payload[25], 5);

      // Vibration (offset 31..37)
      expect(payload[31], 2);
      expect(payload[32], 3);
    });

    test('BrightnessVibrateConfig preserves raw watch configuration presets', () {
      // Create a mock raw 38-byte config with 20..100 brightness scale
      final mockRaw = List<int>.filled(38, 0);
      mockRaw[0] = 5;
      mockRaw[1] = 3;
      mockRaw[2] = 5; mockRaw[3] = 10; mockRaw[4] = 15;
      mockRaw[7] = 5; mockRaw[8] = 3;
      mockRaw[24] = 60; // Currently at level 3 (60)
      mockRaw[25] = 5;
      mockRaw[26] = 20; mockRaw[27] = 40; mockRaw[28] = 60; mockRaw[29] = 80; mockRaw[30] = 100;
      mockRaw[31] = 1; mockRaw[32] = 3;

      final packet = HtsmartProtocol.buildBrightnessVibratePacket(
        brightness: 5, // Request max level 5
        timeoutSeconds: 15,
        vibration: 0,
        rawConfig: mockRaw,
      );

      final payload = packet.sublist(13);
      expect(payload[0], 15);
      expect(payload[24], 100); // Mapped to 5th preset: 100!
      expect(payload[31], 0);
    });

    test('Battery status payload extraction (charging, level, percentage)', () {
      // 3 bytes payload: [isCharging=0, level=4, percentage=85]
      final batteryPayload = [0x00, 0x04, 0x55];
      final isCharging = batteryPayload[0] == 1;
      final percent = batteryPayload.length >= 3 ? batteryPayload[2] : 0;

      expect(isCharging, false);
      expect(percent, 85);
    });
  });
}
