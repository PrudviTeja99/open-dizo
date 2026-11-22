import '../core/utils/crc16.dart';

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
    final payload = (rawConfig != null && rawConfig.length >= 38)
        ? List<int>.from(rawConfig)
        : List<int>.filled(38, 0);

    // Timeout duration options [0..6]: current selected at offset 0
    final durationCount = payload[1] > 0 ? payload[1] : 3;
    payload[0] = timeoutSeconds.clamp(5, 30);
    payload[1] = durationCount;
    if (payload[2] == 0) payload[2] = 5;
    if (payload[3] == 0) payload[3] = 10;
    if (payload[4] == 0) payload[4] = 15;

    // Turn wrist lighting duration [7..13]: mandatory structure for watch firmware acceptance
    if (payload[8] == 0) {
      payload[7] = 5;
      payload[8] = 3;
      payload[9] = 3;
      payload[10] = 5;
      payload[11] = 7;
    }

    // Brightness options [24..30]: current selected at offset 24
    final brightCount = payload[25] > 0 ? payload[25] : 5;
    payload[25] = brightCount;
    if (payload[26] == 0) {
      payload[26] = 1;
      payload[27] = 2;
      payload[28] = 3;
      payload[29] = 4;
      payload[30] = 5;
    }
    final brightIdx = (brightness - 1).clamp(0, brightCount - 1);
    payload[24] = payload[26 + brightIdx];

    // Vibration options [31..37]: current selected at offset 31
    final vibCount = payload[32] > 0 ? payload[32] : 3;
    payload[32] = vibCount;
    if (payload[33] == 0 && payload[34] == 0) {
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
}
