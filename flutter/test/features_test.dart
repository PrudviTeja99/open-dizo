import 'package:flutter_test/flutter_test.dart';
import 'package:open_dizo/models/watch_alarm.dart';
import 'package:open_dizo/models/notification_settings.dart';
import 'package:open_dizo/models/historical_health.dart';
import 'package:open_dizo/services/htsmart_protocol.dart';
import 'package:open_dizo/services/weather_service.dart';
import 'package:open_dizo/services/history_sync_parser.dart';

void main() {
  group('WatchAlarm Tests', () {
    test('Correctly computes repeatBitmask and repeatSummary', () {
      const alarmDaily = WatchAlarm(
        id: 0,
        hour: 7,
        minute: 30,
        repeatDays: {0, 1, 2, 3, 4, 5, 6},
        isEnabled: true,
      );
      expect(alarmDaily.repeatBitmask, equals(0x7F));
      expect(alarmDaily.repeatSummary, equals('Every day'));

      const alarmWeekdays = WatchAlarm(
        id: 1,
        hour: 8,
        minute: 0,
        repeatDays: {1, 2, 3, 4, 5},
        isEnabled: true,
      );
      expect(alarmWeekdays.repeatBitmask, equals(0x3E));
      expect(alarmWeekdays.repeatSummary, equals('Weekdays'));

      const alarmOnce = WatchAlarm(
        id: 2,
        hour: 9,
        minute: 15,
        repeatDays: {},
        isEnabled: true,
      );
      expect(alarmOnce.repeatBitmask, equals(0));
      expect(alarmOnce.repeatSummary, equals('Once'));
    });

    test('Serializes to HTSmart 6-byte format and round-trips correctly', () {
      final alarm = WatchAlarm(
        id: 3,
        hour: 14,
        minute: 45,
        repeatDays: {1, 3, 5},
        isEnabled: true,
        label: 'Workout',
      );

      final bytes = alarm.toHtsmartBytes(targetDate: DateTime(2026, 11, 26));
      expect(bytes.length, greaterThanOrEqualTo(6));

      final parsed = WatchAlarm.fromHtsmartBytes(bytes, 0);
      expect(parsed, isNotNull);
      expect(parsed!.id, equals(3));
      expect(parsed.hour, equals(14));
      expect(parsed.minute, equals(45));
      expect(parsed.repeatDays, equals({1, 3, 5}));
      expect(parsed.isEnabled, isTrue);
      expect(parsed.label, equals('Workout'));
    });

    test('HtsmartProtocol builds alarm packet and parses list', () {
      final list = [
        const WatchAlarm(id: 0, hour: 7, minute: 0, repeatDays: {1, 2, 3, 4, 5}, isEnabled: true),
        const WatchAlarm(id: 1, hour: 9, minute: 30, repeatDays: {0, 6}, isEnabled: false),
      ];

      final packet = HtsmartProtocol.buildSetAlarmsPacket(list);
      expect(packet.length, greaterThan(8));
      expect(packet[8], equals(0x02)); // Cmd 0x02
      expect(packet[10], equals(0x02)); // Key 0x02

      // Extract payload
      final payload = packet.sublist(13);
      final parsed = HtsmartProtocol.parseAlarmList(payload);
      expect(parsed.length, equals(2));
      expect(parsed[0].id, equals(0));
      expect(parsed[0].hour, equals(7));
      expect(parsed[1].id, equals(1));
      expect(parsed[1].hour, equals(9));
      expect(parsed[1].isEnabled, isFalse);
    });
  });

  group('NotificationSettings & Calls Tests', () {
    test('Builds 4-byte bitmask and decodes back', () {
      const settings = NotificationSettings(
        masterEnabled: true,
        incomingCalls: true,
        sms: true,
        whatsapp: true,
        telegram: true,
        email: true,
        others: true,
      );

      final bytes = settings.toConfigBytes();
      expect(bytes.length, equals(4));

      final decoded = NotificationSettings.fromConfigBytes(bytes);
      expect(decoded.masterEnabled, isTrue);
      expect(decoded.incomingCalls, isTrue);
      expect(decoded.sms, isTrue);
      expect(decoded.whatsapp, isTrue);
      expect(decoded.telegram, isTrue);
      expect(decoded.email, isTrue);
      expect(decoded.others, isTrue);
    });

    test('Disabled master configuration emits zero bitmask', () {
      const disabled = NotificationSettings(masterEnabled: false);
      expect(disabled.toConfigBytes(), equals([0, 0, 0, 0]));
    });

    test('Incoming Call packet generation complies with Cmd 0x04 Key 0x01', () {
      final packet = HtsmartProtocol.buildIncomingCallPacket(
        callerName: 'Alice',
        phoneNumber: '+1 555-0100',
      );
      expect(packet.length, greaterThan(8));
      expect(packet[8], equals(0x04)); // Cmd 0x04
      expect(packet[10], equals(0x01)); // Key 0x01 (TYPE_TELEPHONE_COMING)
    });

    test('End Call packet generation complies with Cmd 0x04 Key 0x03', () {
      final packet = HtsmartProtocol.buildEndCallPacket();
      expect(packet.length, greaterThan(8));
      expect(packet[8], equals(0x04)); // Cmd 0x04
      expect(packet[10], equals(0x03)); // Key 0x03 (TYPE_TELEPHONE_REJECT)
    });
  });

  group('Historical Health Tests', () {
    test('Generates 7-day realistic trailing week history', () {
      final history = DailyHealthRecord.generateTrailingWeek(
        todaySteps: 8500,
        todayCalories: 320,
        todayDistance: 5.6,
        todayHeartRate: 74,
      );
      expect(history.length, equals(7));
      expect(history.last.steps, equals(8500));
      expect(history.last.caloriesKcal, equals(320));
      expect(history.last.avgHeartRate, equals(74));
    });
  });

  group('Weather & Find Phone Tests', () {
    test('Maps WMO weather codes to HTSmart watch codes', () {
      expect(WeatherService.mapWmoToWatchCode(0), equals(1)); // Sunny
      expect(WeatherService.mapWmoToWatchCode(2), equals(2)); // Partly Cloudy
      expect(WeatherService.mapWmoToWatchCode(3), equals(3)); // Overcast
      expect(WeatherService.mapWmoToWatchCode(61), equals(4)); // Rain
      expect(WeatherService.mapWmoToWatchCode(73), equals(5)); // Snow
      expect(WeatherService.mapWmoToWatchCode(95), equals(6)); // Thunderstorm
    });

    test('Weather packet generation complies with Cmd 0x02 Key 0x36', () {
      final packet = HtsmartProtocol.buildWeatherPacket(
        city: 'Bengaluru',
        currentTempC: 26,
        lowTempC: 19,
        highTempC: 29,
        weatherCode: 1,
        forecasts: [
          (low: 20, high: 30, code: 2),
          (low: 19, high: 28, code: 4),
        ],
      );
      expect(packet.length, greaterThan(20));
      expect(packet[8], equals(0x02)); // Cmd 0x02
      expect(packet[10], equals(0x36)); // Key 0x36 (54)
    });

    test('Stop Find Phone packet complies with Cmd 0x02 Key 0x98', () {
      final packet = HtsmartProtocol.buildStopFindPhonePacket();
      expect(packet[8], equals(0x02));
      expect(packet[10], equals(0x98));
    });
  });

  group('HistorySyncParser Tests', () {
    // Packed timestamp for 2026-11-26 10:00:00
    // yearVal=26 (0b011010), month=11 (0b1011), day=26 (0b11010), hour=10 (0b01010), min=0, sec=0
    final b0 = ((26 << 2) | (11 >> 2)) & 0xFF;
    final b1 = ((11 << 6) | (26 << 1) | (10 >> 4)) & 0xFF;
    final b2 = ((10 << 4) | (0 >> 2)) & 0xFF;
    final b3 = 0;

    test('Parses packed 4-byte timestamp accurately', () {
      final dt = HistorySyncParser.parse4BytesTimestamp([b0, b1, b2, b3], 0);
      expect(dt.year, equals(2026));
      expect(dt.month, equals(11));
      expect(dt.day, equals(26));
      expect(dt.hour, equals(10));
    });

    test('Parses Step Stream into daily totals', () {
      // 8-byte header: count=2, ts=[b0,b1,b2,b3], interval=30min
      final stream = [
        0x00, 0x02, b0, b1, b2, b3, 0x00, 0x1E,
        0x01, 0xF4, // 500 steps
        0x03, 0xE8, // 1000 steps
      ];
      final days = HistorySyncParser.parseStepStream(stream);
      expect(days[DateTime(2026, 11, 26)], equals(1500));
    });

    test('Parses Sleep Stream into deep/light/awake minutes', () {
      // 8-byte header: count=4, ts=[b0,b1,b2,b3], interval=5min
      final stream = [
        0x00, 0x04, b0, b1, b2, b3, 0x00, 0x05,
        0x01, 0x01, // 10m deep
        0x02,       // 5m light
        0x03,       // 5m awake
      ];
      final sleep = HistorySyncParser.parseSleepStream(stream);
      final summary = sleep[DateTime(2026, 11, 26)];
      expect(summary, isNotNull);
      expect(summary!.deepMinutes, equals(10));
      expect(summary.lightMinutes, equals(5));
      expect(summary.awakeMinutes, equals(5));
    });

    test('Parses Heart Rate & SpO2 streams accurately', () {
      final hrStream = [
        0x00, 0x03, b0, b1, b2, b3, 0x00, 0x1E,
        60, 80, 100,
      ];
      final hrDays = HistorySyncParser.parseHeartRateStream(hrStream);
      final hr = hrDays[DateTime(2026, 11, 26)];
      expect(hr, isNotNull);
      expect(hr!.minBpm, equals(60));
      expect(hr.maxBpm, equals(100));
      expect(hr.avgBpm, equals(80));

      final spo2Stream = [
        0x00, 0x02, b0, b1, b2, b3, 0x00, 0x1E,
        97, 99,
      ];
      final spo2Days = HistorySyncParser.parseSpo2Stream(spo2Stream);
      expect(spo2Days[DateTime(2026, 11, 26)], equals(98));
    });
  });
}
