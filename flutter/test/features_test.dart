import 'package:flutter_test/flutter_test.dart';
import 'package:open_dizo/core/l10n/app_strings.dart';
import 'package:open_dizo/models/watch_alarm.dart';
import 'package:open_dizo/models/watch_settings.dart';
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

  group('Music Sync & Health Warning Thresholds Tests', () {
    test('Music info & state packets comply with Cmd 0x02 Key 0x94 & 0x93', () {
      final infoPkt = HtsmartProtocol.buildMusicInfoPacket(
        title: 'Starboy',
        artist: 'The Weeknd',
        durationMs: 230000,
      );
      expect(infoPkt[8], equals(0x02));
      expect(infoPkt[10], equals(0x94));

      final statePkt = HtsmartProtocol.buildMusicStatePacket(
        isPlaying: true,
        positionMs: 45000,
      );
      expect(statePkt[8], equals(0x02));
      expect(statePkt[10], equals(0x93));
      expect(statePkt[13], equals(1)); // 1 = Playing
    });

    test('Heart Rate & Blood Pressure warning packets comply with Key 0x46 & 0x49', () {
      final hrWarn = HtsmartProtocol.buildWarnHeartRatePacket(
        staticEnable: true,
        staticBpm: 120,
        dynamicEnable: true,
        dynamicBpm: 175,
      );
      expect(hrWarn[8], equals(0x02));
      expect(hrWarn[10], equals(0x46));
      expect(hrWarn.sublist(13), equals([1, 120, 1, 175]));

      final bpWarn = HtsmartProtocol.buildWarnBloodPressurePacket(
        enable: true,
        sbpUpper: 145,
        sbpLower: 90,
        dbpUpper: 95,
        dbpLower: 60,
      );
      expect(bpWarn[8], equals(0x02));
      expect(bpWarn[10], equals(0x49));
      expect(bpWarn.sublist(13), equals([1, 145, 90, 95, 60]));
    });

    test('buildSetLanguagePacket uses Cmd 0x02 Key 0x3A with watch code', () {
      final teluguPacket = HtsmartProtocol.buildSetLanguagePacket(
        AppLanguage.telugu.watchCode,
      );
      expect(teluguPacket[8], equals(0x02));
      expect(teluguPacket[10], equals(0x3A));
      expect(teluguPacket.sublist(13), equals([67, 0, 0, 0]));

      final hindiPacket = HtsmartProtocol.buildSetLanguagePacket(
        AppLanguage.hindi.watchCode,
      );
      expect(hindiPacket.sublist(13), equals([19, 0, 0, 0]));
    });

    test('buildNotificationPushPacket and buildIncomingCallPacket encode body & call type', () {
      final notifExt = HtsmartProtocol.buildNotificationPushPacket(
        type: 12,
        name: 'Alice',
        content: 'Full message body line 1\nLine 2',
        useExtendedFormat: true,
      );
      expect(notifExt[8], equals(0x04));
      expect(notifExt[10], equals(12));
      // keyData[0] = nameLen (5), followed by 'Alice', 2-byte contentLen (31), and body
      expect(notifExt[13], equals(5));
      expect(notifExt[19], equals(0));
      expect(notifExt[20], equals(31));

      final notifLegacy = HtsmartProtocol.buildNotificationPushPacket(
        type: 12,
        name: 'Alice',
        content: 'Legacy body',
        useExtendedFormat: false,
      );
      expect(notifLegacy[8], equals(0x04));
      expect(notifLegacy[10], equals(12));
      // Legacy format: 20-byte space-padded name, 2-byte contentLen (11) at offset 13+20
      expect(notifLegacy[13 + 20], equals(0));
      expect(notifLegacy[13 + 21], equals(11));

      final callPkt = HtsmartProtocol.buildIncomingCallPacket(
        callerName: 'Bob🫡',
        phoneNumber: '+919876543210',
      );
      expect(callPkt[8], equals(0x04));
      expect(callPkt[10], equals(0x01)); // TYPE_TELEPHONE_COMING
      expect(HtsmartProtocol.stripUnsupportedChars('Pedha Rayudu🫡'), equals('Pedha Rayudu'));
    });
  });

  group('Multi-Language & Apply Target Tests', () {
    test('AppLanguage maps Telugu (67) and Hindi (19) correctly', () {
      expect(AppLanguage.telugu.code, equals('te'));
      expect(AppLanguage.telugu.watchCode, equals(67));
      expect(AppLanguage.fromCode('te'), equals(AppLanguage.telugu));
      expect(AppLanguage.hindi.watchCode, equals(19));
      expect(AppLanguage.fromCode('unknown'), equals(AppLanguage.english));
    });

    test('AppStrings switches active language and falls back cleanly', () {
      AppStrings.setLanguage(AppLanguage.telugu);
      expect(AppStrings.currentLanguage.value, equals(AppLanguage.telugu));
      expect(AppStrings.t('steps'), equals('అడుగులు'));

      AppStrings.setLanguage(AppLanguage.hindi);
      expect(AppStrings.t('steps'), equals('कदम'));

      // Verify all 10 supported languages resolve core keys without falling back to raw key
      for (final lang in AppLanguage.values) {
        AppStrings.setLanguage(lang);
        expect(AppStrings.t('tab_health'), isNot(equals('tab_health')));
        expect(AppStrings.t('steps'), isNot(equals('steps')));
        expect(AppStrings.t('ble_logs'), isNot(equals('ble_logs')));
      }

      // Reset to English
      AppStrings.setLanguage(AppLanguage.english);
      expect(AppStrings.t('steps'), equals('Steps'));
    });

    test('WatchSettings persists languageCode and languageTarget', () {
      const settings = WatchSettings(
        languageCode: 'te',
        languageTarget: 'watchOnly',
      );
      final map = settings.toMap();
      final decoded = WatchSettings.fromMap(map);
      expect(decoded.languageCode, equals('te'));
      expect(decoded.languageTarget, equals('watchOnly'));
      expect(
        LanguageApplyTarget.fromId(decoded.languageTarget),
        equals(LanguageApplyTarget.watchOnly),
      );
    });
  });
}
