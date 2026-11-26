import 'package:flutter_test/flutter_test.dart';
import 'package:open_dizo/models/watch_alarm.dart';
import 'package:open_dizo/models/notification_settings.dart';
import 'package:open_dizo/models/historical_health.dart';
import 'package:open_dizo/services/htsmart_protocol.dart';

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
}
