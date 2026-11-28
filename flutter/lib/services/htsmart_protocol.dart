import 'dart:convert';
import '../core/utils/crc16.dart';
import '../models/watch_alarm.dart';
import '../models/notification_settings.dart';

/// HTSmart / Realtek BLE packet serializer and framing utility
/// Implemented according to clean companion app specifications.
class HtsmartProtocol {
  /// Builds a standard 8-byte header + CmdPacket + KeyPacket frame
  static List<int> buildPacket({
    required int cmdId,
    required int keyId,
    List<int> payload = const [],
    int seq = 1,
  }) {
    final keyPacket = [
      keyId,
      (payload.length >> 8) & 0xFF,
      payload.length & 0xFF,
      ...payload,
    ];

    final cmdPacket = [cmdId, 0x00, ...keyPacket];
    final len = cmdPacket.length;
    final crc = Crc16.compute(cmdPacket);

    return [
      0xAB, 0x00,                    // Magic bytes & flags
      (len >> 8) & 0xFF, len & 0xFF,  // Payload length (Big Endian)
      (crc >> 8) & 0xFF, crc & 0xFF,  // CRC16 (Big Endian)
      (seq >> 8) & 0xFF, seq & 0xFF,  // Sequence ID
      ...cmdPacket,
    ];
  }

  /// Builds a 17-byte time synchronization packet for DateTime
  static List<int> buildTimeSyncPacket(DateTime dt, {int seq = 1}) {
    final yearVal = dt.year - 2000;
    final month = dt.month;
    final day = dt.day;
    final hour = dt.hour;
    final minute = dt.minute;
    final second = dt.second;

    final b0 = ((yearVal << 2) | (month >> 2)) & 0xFF;
    final b1 = ((month << 6) | (day << 1) | (hour >> 4)) & 0xFF;
    final b2 = ((hour << 4) | (minute >> 2)) & 0xFF;
    final b3 = ((minute << 6) | second) & 0xFF;

    return buildPacket(
      cmdId: 0x02, // Set
      keyId: 0x01, // Time key
      payload: [b0, b1, b2, b3],
      seq: seq,
    );
  }

  /// Builds a Login authentication packet (Cmd 0x03, Key 0x13) with 32-byte userId
  static List<int> buildLoginPacket({String userId = 'DizoUser', int seq = 1}) {
    final payload = List<int>.filled(32, 0);
    final userBytes = userId.codeUnits;
    for (int i = 0; i < userBytes.length && i < 28; i++) {
      payload[i] = userBytes[i];
    }
    return buildPacket(
      cmdId: 0x03, // CMD_BOND_REG
      keyId: 0x13, // Login key (19)
      payload: payload,
      seq: seq,
    );
  }

  /// Builds a Bind registration packet (Cmd 0x03, Key 0x11) with 32-byte userId
  static List<int> buildBindPacket({String userId = 'DizoUser', int seq = 1}) {
    final payload = List<int>.filled(32, 0);
    final userBytes = userId.codeUnits;
    for (int i = 0; i < userBytes.length && i < 28; i++) {
      payload[i] = userBytes[i];
    }
    return buildPacket(
      cmdId: 0x03, // CMD_BOND_REG
      keyId: 0x11, // Bind key (17)
      payload: payload,
      seq: seq,
    );
  }

  /// Builds a Battery Status query packet (Cmd 0x02, Key 0x1B)
  static List<int> buildBatteryQueryPacket({int seq = 1}) {
    return buildPacket(
      cmdId: 0x02,
      keyId: 0x1B,
      payload: const [],
      seq: seq,
    );
  }

  /// Builds a Dial / Watchface info query packet (Cmd 0x02, Key 0x43)
  static List<int> buildDialInfoQueryPacket({int seq = 1}) {
    return buildPacket(
      cmdId: 0x02,
      keyId: 0x43,
      payload: const [],
      seq: seq,
    );
  }

  /// Builds a Switch Dial packet (Cmd 0x02, Key 0x70) to activate a dial slot (e.g. 4 for custom dial)
  static List<int> buildSwitchDialPacket(int dialPosition, {int seq = 1}) {
    return buildPacket(
      cmdId: 0x02,
      keyId: 0x70,
      payload: [dialPosition & 0xFF],
      seq: seq,
    );
  }

  /// Builds Today's Total Metrics query packet (Cmd 0x05, Key 0x21)
  /// Returns 30-byte TodayTotalData: Steps, Distance, Calories, Sleep, Heart Rate
  static List<int> buildTodayTotalDataPacket({int seq = 1}) {
    return buildPacket(
      cmdId: 0x05,
      keyId: 0x21,
      payload: const [],
      seq: seq,
    );
  }

  /// Builds Latest Healthy Data query packet (Cmd 0x05, Key 0x42 / 66)
  /// Watch responds with Cmd 0x05, Key 0x43 containing latest HR, SpO2, DBP, SBP
  static List<int> buildLatestHealthyPacket({int seq = 1}) {
    return buildPacket(
      cmdId: 0x05,
      keyId: 0x42,
      payload: const [],
      seq: seq,
    );
  }

  /// Builds Real-Time Health Measurement command packet (Cmd 0x05, Key 0x23)
  /// healthyType bitmask: 1=HR, 2=SpO2, 4=BP, 8=Respiratory, 16=ECG, 32=Temp, 64=Pressure
  static List<int> buildRealTimeHealthPacket({
    int healthyType = 0x07, // HR + SpO2 + BP
    int durationMinutes = 2,
    bool enable = true,
    int seq = 1,
  }) {
    return buildPacket(
      cmdId: 0x05,
      keyId: 0x23, // 35
      payload: [
        enable ? ((healthyType >> 8) & 0xFF) : 0,
        enable ? (healthyType & 0xFF) : 0,
        5,
        enable ? (durationMinutes & 0xFF) : 0,
      ],
      seq: seq,
    );
  }

  /// Builds historical data sync query packet (Cmd 0x05, Key 0x01)
  /// dataType: 1=Step, 2=Sleep, 3=HR, 4=SpO2, 5=BP, 6=Respiratory, 16=Sport
  static List<int> buildSyncDataPacket(int dataType, {int seq = 1}) {
    return buildPacket(
      cmdId: 0x05,
      keyId: 0x01,
      payload: [dataType & 0xFF],
      seq: seq,
    );
  }

  /// Builds data sync acknowledgement packet (Cmd 0x05, Key 0x20)
  static List<int> buildSyncAckPacket({bool success = true, int seq = 1}) {
    return buildPacket(
      cmdId: 0x05,
      keyId: 0x20, // 32
      payload: [success ? 0x00 : 0x01],
      seq: seq,
    );
  }

  /// Builds standard transport ACK frame (8 bytes) acknowledging sequence ID
  static List<int> buildTransportAckPacket(int seq, {bool isError = false}) {
    return [
      0xAB,
      isError ? 0x30 : 0x10,
      0x00,
      0x00,
      0x00,
      0x00,
      (seq >> 8) & 0xFF,
      seq & 0xFF,
    ];
  }

  /// Builds Watch Configuration Query packet (Cmd 0x02, Key 0x20)
  static List<int> buildConfigQueryPacket({int seq = 1}) {
    return buildPacket(
      cmdId: 0x02,
      keyId: 0x20, // 32
      payload: const [],
      seq: seq,
    );
  }

  /// Builds Brightness and Screen Timeout packet (Cmd 0x02, Key 0x7B / 123)
  /// 38-byte configuration frame matching official companion app specification
  static List<int> buildBrightnessVibratePacket({
    required int brightness, // 1..5
    required int timeoutSeconds, // 5, 10, 15
    int vibration = 1, // 0..2
    List<int>? rawConfig,
    int seq = 1,
  }) {
    List<int> payload;
    if (rawConfig != null && rawConfig.isNotEmpty) {
      payload = List<int>.filled(38, 0);
      for (int i = 0; i < rawConfig.length && i < 38; i++) {
        payload[i] = rawConfig[i];
      }
    } else {
      payload = List<int>.filled(38, 0);

      // Default timeout durations: 5s, 10s, 15s
      payload[0] = timeoutSeconds.clamp(5, 30);
      payload[1] = 3;
      payload[2] = 5;
      payload[3] = 10;
      payload[4] = 15;

      // Default turn wrist lighting duration: 5s (presets: 3, 5, 7)
      payload[7] = 5;
      payload[8] = 3;
      payload[9] = 3;
      payload[10] = 5;
      payload[11] = 7;

      // Default brightness options: 5 levels (1, 2, 3, 4, 5)
      payload[25] = 5;
      payload[26] = 1;
      payload[27] = 2;
      payload[28] = 3;
      payload[29] = 4;
      payload[30] = 5;

      // Default vibration options: 3 levels (0, 1, 2)
      payload[32] = 3;
      payload[33] = 0;
      payload[34] = 1;
      payload[35] = 2;
    }

    // Set screen timeout duration at offset 0
    payload[0] = timeoutSeconds.clamp(5, 30);

    // Set brightness level at offset 24 from the available preset levels at [26..26+count-1]
    final brightCount = payload[25] > 0 ? payload[25] : 5;
    if (payload[25] == 0) {
      payload[25] = 5;
      payload[26] = 1;
      payload[27] = 2;
      payload[28] = 3;
      payload[29] = 4;
      payload[30] = 5;
    }
    final brightIdx = (brightness - 1).clamp(0, brightCount - 1);
    payload[24] = payload[26 + brightIdx];

    // Set vibration level at offset 31 from presets at [33..33+count-1]
    final vibCount = payload[32] > 0 ? payload[32] : 3;
    if (payload[32] == 0) {
      payload[32] = 3;
      payload[33] = 0;
      payload[34] = 1;
      payload[35] = 2;
    }
    final vibIdx = vibration.clamp(0, vibCount - 1);
    payload[31] = payload[33 + vibIdx];

    return buildPacket(
      cmdId: 0x02,
      keyId: 0x7B, // 123
      payload: payload,
      seq: seq,
    );
  }

  /// Builds Raise to Wake (Turn Wrist Lighting) packet (Cmd 0x02, Key 0x2B / 43)
  static List<int> buildTurnWristPacket({
    required bool enable,
    int startMinute = 480,  // 08:00 AM
    int endMinute = 1320,   // 10:00 PM
    int seq = 1,
  }) {
    final payload = [
      enable ? 1 : 0,
      (startMinute >> 8) & 0xFF,
      startMinute & 0xFF,
      (endMinute >> 8) & 0xFF,
      endMinute & 0xFF,
      0, 0, 0, 0,
    ];
    return buildPacket(
      cmdId: 0x02,
      keyId: 0x2B, // 43
      payload: payload,
      seq: seq,
    );
  }

  /// Builds Do Not Disturb (DND) packet (Cmd 0x02, Key 0x4C / 76)
  static List<int> buildNotDisturbPacket({
    required bool enableAllDay,
    required bool enablePeriod,
    int startMinute = 0,
    int endMinute = 1439,
    int seq = 1,
  }) {
    final payload = [
      enableAllDay ? 1 : 0,
      enablePeriod ? 1 : 0,
      (startMinute >> 8) & 0xFF,
      startMinute & 0xFF,
      (endMinute >> 8) & 0xFF,
      endMinute & 0xFF,
    ];
    return buildPacket(
      cmdId: 0x02,
      keyId: 0x4C, // 76
      payload: payload,
      seq: seq,
    );
  }

  /// Builds Continuous Health Monitoring (All-Day HR) packet (Cmd 0x02, Key 0x22 / 34)
  static List<int> buildHealthyMonitorPacket({
    required bool enable,
    int startMinute = 0,
    int endMinute = 1439,
    int intervalMinutes = 30,
    int seq = 1,
  }) {
    final payload = [
      enable ? 1 : 0,
      (startMinute >> 8) & 0xFF,
      startMinute & 0xFF,
      (endMinute >> 8) & 0xFF,
      endMinute & 0xFF,
      (intervalMinutes >> 8) & 0xFF,
      intervalMinutes & 0xFF,
    ];
    return buildPacket(
      cmdId: 0x02,
      keyId: 0x22, // 34
      payload: payload,
      seq: seq,
    );
  }

  /// Builds Sedentary Inactivity Reminder packet (Cmd 0x02, Key 0x25 / 37)
  static List<int> buildSedentaryPacket({
    required bool enable,
    bool dndLunch = true,
    int startMinute = 540,  // 09:00 AM
    int endMinute = 1080,   // 06:00 PM
    int intervalMinutes = 60,
    int seq = 1,
  }) {
    final flag = (enable ? 1 : 0) | (dndLunch ? 2 : 0);
    final payload = [
      flag,
      (startMinute >> 8) & 0xFF,
      startMinute & 0xFF,
      (endMinute >> 8) & 0xFF,
      endMinute & 0xFF,
      (intervalMinutes >> 8) & 0xFF,
      intervalMinutes & 0xFF,
    ];
    return buildPacket(
      cmdId: 0x02,
      keyId: 0x25, // 37
      payload: payload,
      seq: seq,
    );
  }

  /// Builds Drink Water Reminder packet (Cmd 0x02, Key 0x28 / 40)
  static List<int> buildDrinkWaterPacket({
    required bool enable,
    int startMinute = 540, // 09:00 AM
    int endMinute = 1200,  // 08:00 PM
    int intervalMinutes = 60,
    int seq = 1,
  }) {
    final payload = [
      enable ? 1 : 0,
      (intervalMinutes >> 8) & 0xFF,
      intervalMinutes & 0xFF,
      (startMinute >> 8) & 0xFF,
      startMinute & 0xFF,
      (endMinute >> 8) & 0xFF,
      endMinute & 0xFF,
      0, 0,
    ];
    return buildPacket(
      cmdId: 0x02,
      keyId: 0x28, // 40
      payload: payload,
      seq: seq,
    );
  }

  /// Builds Watch Preferences / Function Config packet (Cmd 0x02, Key 0x18 / 24)
  /// Flags: wear_way (bit 0), hour_style (bit 2), length_unit (bit 3), temp_unit (bit 4), weather (bit 5)
  static List<int> buildFunctionConfigPacket({
    bool is24Hour = true,
    bool isMetric = true,
    bool isRightHand = false,
    bool weatherEnabled = true,
    bool disconnectReminder = false,
    int seq = 1,
  }) {
    int byte1 = 0;
    if (isRightHand) byte1 |= (1 << 0);
    // Bit 2: 1 = 12-hour, 0 = 24-hour
    if (!is24Hour) byte1 |= (1 << 2);
    // Bit 3: 1 = Imperial (miles), 0 = Metric (km)
    if (!isMetric) byte1 |= (1 << 3);
    // Bit 5: Weather switch
    if (weatherEnabled) byte1 |= (1 << 5);
    // Bit 6: Disconnect reminder
    if (disconnectReminder) byte1 |= (1 << 6);

    return buildPacket(
      cmdId: 0x02,
      keyId: 0x18, // 24
      payload: [0x00, byte1],
      seq: seq,
    );
  }

  /// Builds Daily Exercise Target packet (Cmd 0x02, Key 0x06)
  static List<int> buildExerciseTargetPacket({
    int steps = 10000,
    int distanceMeters = 5000,
    int calories = 300,
    int seq = 1,
  }) {
    return buildPacket(
      cmdId: 0x02,
      keyId: 0x06,
      payload: [
        // Steps (uint32 Little Endian)
        steps & 0xFF, (steps >> 8) & 0xFF, (steps >> 16) & 0xFF, (steps >> 24) & 0xFF,
        // Distance (uint32 Little Endian)
        distanceMeters & 0xFF, (distanceMeters >> 8) & 0xFF, (distanceMeters >> 16) & 0xFF, (distanceMeters >> 24) & 0xFF,
        // Calories (uint32 Little Endian)
        calories & 0xFF, (calories >> 8) & 0xFF, (calories >> 16) & 0xFF, (calories >> 24) & 0xFF,
      ],
      seq: seq,
    );
  }

  /// Builds User Profile packet (Cmd 0x02, Key 0x05)
  static List<int> buildUserInfoPacket({
    bool isMale = true,
    int age = 25,
    double heightCm = 175.0,
    double weightKg = 70.0,
    int seq = 1,
  }) {
    final h = ((heightCm * 10.0) / 5).round();
    final w = ((weightKg * 10.0) / 5).round();

    return buildPacket(
      cmdId: 0x02,
      keyId: 0x05,
      payload: [
        ((isMale ? 128 : 0) | (age.clamp(1, 120) & 0x7F)),
        (h >> 1) & 0xFF,
        (((h << 7) | (w >> 3)) & 0xFF),
        ((w << 5) & 0xFF),
      ],
      seq: seq,
    );
  }

  /// Builds Find Watch vibration trigger packet (Cmd 0x02, Key 0x3B / 59)
  static List<int> buildFindWatchPacket({int seq = 1}) {
    return buildPacket(
      cmdId: 0x02,
      keyId: 0x3B,
      payload: const [],
      seq: seq,
    );
  }

  /// Builds Watch Reboot / Restart packet (Cmd 0x02, Key 0x42 / 66)
  static List<int> buildRestartPacket({int seq = 1}) {
    return buildPacket(
      cmdId: 0x02,
      keyId: 0x42,
      payload: const [],
      seq: seq,
    );
  }

  /// Builds Watch Power Off packet (Cmd 0x02, Key 0x41 / 65)
  static List<int> buildTurnOffPacket({int seq = 1}) {
    return buildPacket(
      cmdId: 0x02,
      keyId: 0x41,
      payload: const [],
      seq: seq,
    );
  }

  /// Builds Watch Factory Reset packet (Cmd 0x02, Key 0x40 / 64)
  static List<int> buildResetPacket({int seq = 1}) {
    return buildPacket(
      cmdId: 0x02,
      keyId: 0x40,
      payload: const [],
      seq: seq,
    );
  }

  /// Calculates Linwear binding key from random challenge and MAC address
  static int calcBindingKey(int randomVal, String mac) {
    final cleanMac = mac.replaceAll(':', '').replaceAll('-', '').trim();
    int macSum = 0;
    if (cleanMac.length == 12) {
      for (int i = 0; i < 12; i += 2) {
        macSum += int.parse(cleanMac.substring(i, i + 2), radix: 16);
      }
    } else {
      // Default fallback MAC for DIZO Watch D: CC:EA:FF:AA:42:7F
      macSum = 0xCC + 0xEA + 0xFF + 0xAA + 0x42 + 0x7F; // 1056
    }
    return ((randomVal % 10000) + macSum) % 1000000;
  }

  // ==========================================
  // Alarms (Cmd 0x02, Key 0x02)
  // ==========================================

  /// Builds a Set Watch Alarms packet (Cmd 0x02, Key 0x02)
  static List<int> buildSetAlarmsPacket(List<WatchAlarm> alarms, {int seq = 1}) {
    final payload = <int>[];
    for (final alarm in alarms) {
      payload.addAll(alarm.toHtsmartBytes());
    }
    return buildPacket(
      cmdId: 0x02,
      keyId: 0x02,
      payload: payload,
      seq: seq,
    );
  }

  /// Builds an Alarm List Query packet (Cmd 0x02, Key 0x02)
  static List<int> buildAlarmQueryPacket({int seq = 1}) {
    return buildPacket(
      cmdId: 0x02,
      keyId: 0x02,
      payload: const [],
      seq: seq,
    );
  }

  /// Parses alarm list from watch response packet payload
  static List<WatchAlarm> parseAlarmList(List<int> payload) {
    final alarms = <WatchAlarm>[];
    int offset = 0;
    while (offset < payload.length) {
      if (payload.length < offset + 6) break;
      final itemLen = payload[offset] & 0xFF;
      if (itemLen < 5) break;
      final alarm = WatchAlarm.fromHtsmartBytes(payload, offset);
      if (alarm != null) {
        alarms.add(alarm);
      }
      offset += (1 + itemLen);
    }
    return alarms;
  }

  // ==========================================
  // Notifications & Calls (Cmd 0x02 Key 0x12 & Cmd 0x04)
  // ==========================================

  /// Builds Notification Configuration packet (Cmd 0x02, Key 0x12)
  static List<int> buildNotificationConfigPacket(NotificationSettings settings, {int seq = 1}) {
    return buildPacket(
      cmdId: 0x02,
      keyId: 0x12, // 18
      payload: settings.toConfigBytes(),
      seq: seq,
    );
  }

  /// Builds Notification Configuration Query packet (Cmd 0x02, Key 0x12)
  static List<int> buildNotificationConfigQueryPacket({int seq = 1}) {
    return buildPacket(
      cmdId: 0x02,
      keyId: 0x12,
      payload: const [],
      seq: seq,
    );
  }

  /// Strips 4-byte UTF-8 emojis, variation selectors, and zero-width joiners
  /// that the watch's bitmap font renderer cannot display.
  static String stripUnsupportedChars(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      // Skip supplementary plane emojis (>= U+10000), variation selectors (FE00-FE0F), ZWJ (200D)
      if (rune >= 0x10000 || (rune >= 0xFE00 && rune <= 0xFE0F) || rune == 0x200D) {
        continue;
      }
      buffer.writeCharCode(rune);
    }
    return buffer.toString().trim();
  }

  /// Builds an App Notification Push packet (Cmd 0x04, Key = type)
  /// Types: 1=Phone coming, 2=Phone answered, 3=Phone reject, 4=SMS, 12=WhatsApp, 18=Telegram, 0xFF=Others
  static List<int> buildNotificationPushPacket({
    required int type,
    required String name,
    required String content,
    bool useExtendedFormat = true,
    int seq = 1,
  }) {
    final cleanName = stripUnsupportedChars(name);
    final cleanContent = stripUnsupportedChars(content);
    final nameBytes = utf8.encode(cleanName);
    final contentBytes = utf8.encode(cleanContent);
    final List<int> keyData;

    if (useExtendedFormat) {
      final nameLen = nameBytes.length.clamp(0, 64);
      final maxContent = 240 - nameLen;
      final contentLen = contentBytes.length.clamp(0, maxContent);

      keyData = List<int>.filled(nameLen + 3 + contentLen, 0);
      keyData[0] = nameLen & 0xFF;
      for (int i = 0; i < nameLen; i++) {
        keyData[1 + i] = nameBytes[i];
      }
      keyData[nameLen + 1] = (contentLen >> 8) & 0xFF;
      keyData[nameLen + 2] = contentLen & 0xFF;
      for (int i = 0; i < contentLen; i++) {
        keyData[nameLen + 3 + i] = contentBytes[i];
      }
    } else {
      // Legacy fixed 20-byte name layout
      final contentLen = contentBytes.length.clamp(0, 220);
      keyData = List<int>.filled(22 + contentLen, 0x20); // Pad with spaces

      final copyNameLen = nameBytes.length.clamp(0, 20);
      for (int i = 0; i < copyNameLen; i++) {
        keyData[i] = nameBytes[i];
      }
      keyData[20] = (contentLen >> 8) & 0xFF;
      keyData[21] = contentLen & 0xFF;
      for (int i = 0; i < contentLen; i++) {
        keyData[22 + i] = contentBytes[i];
      }
    }

    return buildPacket(
      cmdId: 0x04,
      keyId: type & 0xFF,
      payload: keyData,
      seq: seq,
    );
  }

  /// Pushes an incoming call notification to the watch (Cmd 0x04, Key 0x01)
  static List<int> buildIncomingCallPacket({
    required String callerName,
    required String phoneNumber,
    bool useExtendedFormat = true,
    int seq = 1,
  }) {
    return buildNotificationPushPacket(
      type: 0x01, // TYPE_TELEPHONE_COMING
      name: callerName.isNotEmpty ? callerName : phoneNumber,
      content: phoneNumber.isNotEmpty ? phoneNumber : 'Incoming Call',
      useExtendedFormat: useExtendedFormat,
      seq: seq,
    );
  }

  /// Sends a call ended / rejected packet to dismiss incoming call alert on the watch (Cmd 0x04, Key 0x03)
  static List<int> buildEndCallPacket({
    bool useExtendedFormat = true,
    int seq = 1,
  }) {
    return buildNotificationPushPacket(
      type: 0x03, // TYPE_TELEPHONE_REJECT
      name: '',
      content: '',
      useExtendedFormat: useExtendedFormat,
      seq: seq,
    );
  }

  // ==========================================
  // Weather & Find Phone (Cmd 0x02)
  // ==========================================

  /// Builds a Weather + Multi-Day Forecast sync packet (Cmd 0x02, Key 0x36 / 54)
  /// Forecasts: list of maps/records with {low, high, code}
  static List<int> buildWeatherPacket({
    required String city,
    required int currentTempC,
    required int lowTempC,
    required int highTempC,
    required int weatherCode,
    int pressureHpa = 1013,
    int windForce = 2,
    int visibilityKm = 10,
    List<({int low, int high, int code})> forecasts = const [],
    DateTime? timestamp,
    int seq = 1,
  }) {
    final cityBytes = utf8.encode(city);
    final cityLen = cityBytes.length.clamp(0, 64);
    final dt = timestamp ?? DateTime.now();

    final yearVal = (dt.year - 2000).clamp(0, 127);
    final b0 = ((yearVal << 2) | (dt.month >> 2)) & 0xFF;
    final b1 = ((dt.month << 6) | (dt.day << 1) | (dt.hour >> 4)) & 0xFF;
    final b2 = ((dt.hour << 4) | (dt.minute >> 2)) & 0xFF;
    final b3 = ((dt.minute << 6) | dt.second) & 0xFF;

    final forecastCount = forecasts.length.clamp(0, 7);
    final payload = <int>[
      currentTempC & 0xFF,
      lowTempC & 0xFF,
      highTempC & 0xFF,
      weatherCode & 0xFF,
      cityLen & 0xFF,
      ...cityBytes.take(cityLen),
      b0, b1, b2, b3,
      forecastCount & 0xFF,
    ];

    for (int i = 0; i < forecastCount; i++) {
      payload.add(forecasts[i].low & 0xFF);
      payload.add(forecasts[i].high & 0xFF);
      payload.add(forecasts[i].code & 0xFF);
    }

    // 4-byte pressure (Big Endian) + windForce + visibility
    payload.addAll([
      (pressureHpa >> 24) & 0xFF,
      (pressureHpa >> 16) & 0xFF,
      (pressureHpa >> 8) & 0xFF,
      pressureHpa & 0xFF,
      windForce & 0xFF,
      visibilityKm & 0xFF,
    ]);

    return buildPacket(
      cmdId: 0x02,
      keyId: 0x36, // 54
      payload: payload,
      seq: seq,
    );
  }

  /// Builds a Stop Find Phone acknowledgement packet (Cmd 0x02, Key 0x98)
  static List<int> buildStopFindPhonePacket({int seq = 1}) {
    return buildPacket(
      cmdId: 0x02,
      keyId: 0x98,
      payload: const [],
      seq: seq,
    );
  }

  // ==========================================
  // Music Sync & Health Warning Thresholds (Cmd 0x02)
  // ==========================================

  /// Builds Now-Playing Music Track Info packet (Cmd 0x02, Key 0x94 / 148)
  static List<int> buildMusicInfoPacket({
    required String title,
    required String artist,
    int durationMs = 0,
    int seq = 1,
  }) {
    final titleBytes = utf8.encode(title);
    final artistBytes = utf8.encode(artist);
    final titleLen = titleBytes.length.clamp(0, 127);
    final artistLen = artistBytes.length.clamp(0, 96);

    final payload = <int>[
      titleLen & 0xFF,
      artistLen & 0xFF,
      (durationMs >> 24) & 0xFF,
      (durationMs >> 16) & 0xFF,
      (durationMs >> 8) & 0xFF,
      durationMs & 0xFF,
      ...titleBytes.take(titleLen),
      ...artistBytes.take(artistLen),
    ];

    return buildPacket(
      cmdId: 0x02,
      keyId: 0x94,
      payload: payload,
      seq: seq,
    );
  }

  /// Builds Now-Playing Music Playback State packet (Cmd 0x02, Key 0x93 / 147)
  /// playState: 1 = Playing, 2 = Paused
  static List<int> buildMusicStatePacket({
    required bool isPlaying,
    int positionMs = 0,
    double volume = 1.0,
    int seq = 1,
  }) {
    final volScaled = (volume.clamp(0.0, 1.0) * 100.0).round();
    final payload = <int>[
      isPlaying ? 1 : 2,
      (positionMs >> 24) & 0xFF,
      (positionMs >> 16) & 0xFF,
      (positionMs >> 8) & 0xFF,
      positionMs & 0xFF,
      (volScaled >> 8) & 0xFF,
      volScaled & 0xFF,
    ];

    return buildPacket(
      cmdId: 0x02,
      keyId: 0x93,
      payload: payload,
      seq: seq,
    );
  }

  /// Builds Heart Rate Warning Thresholds packet (Cmd 0x02, Key 0x46 / 70)
  static List<int> buildWarnHeartRatePacket({
    required bool staticEnable,
    required int staticBpm,
    required bool dynamicEnable,
    required int dynamicBpm,
    int seq = 1,
  }) {
    return buildPacket(
      cmdId: 0x02,
      keyId: 0x46,
      payload: [
        staticEnable ? 1 : 0,
        staticBpm.clamp(40, 220) & 0xFF,
        dynamicEnable ? 1 : 0,
        dynamicBpm.clamp(60, 220) & 0xFF,
      ],
      seq: seq,
    );
  }

  /// Builds Blood Pressure Warning Thresholds packet (Cmd 0x02, Key 0x49 / 73)
  static List<int> buildWarnBloodPressurePacket({
    required bool enable,
    required int sbpUpper,
    required int sbpLower,
    required int dbpUpper,
    required int dbpLower,
    int seq = 1,
  }) {
    return buildPacket(
      cmdId: 0x02,
      keyId: 0x49,
      payload: [
        enable ? 1 : 0,
        sbpUpper.clamp(80, 240) & 0xFF,
        sbpLower.clamp(50, 160) & 0xFF,
        dbpUpper.clamp(50, 160) & 0xFF,
        dbpLower.clamp(30, 120) & 0xFF,
      ],
      seq: seq,
    );
  }

  /// Builds Watch UI Language packet (Cmd 0x02, Key 0x3A / 58)
  /// languageCode: 3=English, 19=Hindi, 61=Kannada, 63=Malayalam, 64=Marathi, 65=Tamil, 67=Telugu, etc.
  static List<int> buildSetLanguagePacket(int languageCode, {int seq = 1}) {
    return buildPacket(
      cmdId: 0x02,
      keyId: 0x3A,
      payload: [languageCode & 0xFF, 0, 0, 0],
      seq: seq,
    );
  }

  /// Enters or exits Remote Camera Shutter mode on the watch (Cmd 0x07, Key 0x02)
  /// Payload: [0x00] to enter camera mode, [0x01] to exit camera mode
  static List<int> buildCameraStatusPacket(bool enabled, {int seq = 1}) {
    return buildPacket(
      cmdId: 0x07,
      keyId: 0x02,
      payload: [enabled ? 0x00 : 0x01],
      seq: seq,
    );
  }
}
