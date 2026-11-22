import '../core/utils/crc16.dart';

/// HTSmart / Realtek BLE packet serializer and framing utility
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

  /// Builds a Battery / Status query packet (Cmd 0x02, Key 0x52)
  static List<int> buildBatteryQueryPacket({int seq = 1}) {
    return buildPacket(
      cmdId: 0x02,
      keyId: 0x52,
      payload: const [],
      seq: seq,
    );
  }

  /// Builds a Find Watch vibration trigger packet (Cmd 0x02, Key 0x1B)
  static List<int> buildFindWatchPacket({int seq = 1}) {
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
