import 'dart:math' as math;

class HistoryDataHeader {
  final int itemCount;
  final DateTime timestamp;
  final int intervalMinutes;

  const HistoryDataHeader({
    required this.itemCount,
    required this.timestamp,
    required this.intervalMinutes,
  });
}

class HistorySleepSummary {
  final int deepMinutes;
  final int lightMinutes;
  final int awakeMinutes;

  const HistorySleepSummary({
    required this.deepMinutes,
    required this.lightMinutes,
    required this.awakeMinutes,
  });
}

class HistoryHeartRateSummary {
  final int minBpm;
  final int maxBpm;
  final int avgBpm;

  const HistoryHeartRateSummary({
    required this.minBpm,
    required this.maxBpm,
    required this.avgBpm,
  });
}

/// Decodes HTSmart historical data streams (Cmd 0x05) stored in the watch flash memory
/// according to clean protocol specifications.
class HistorySyncParser {
  /// Parses packed 4-byte HTSmart timestamp
  static DateTime parse4BytesTimestamp(List<int> bytes, int offset) {
    if (bytes.length < offset + 4) return DateTime.now();
    final b0 = bytes[offset] & 0xFF;
    final b1 = bytes[offset + 1] & 0xFF;
    final b2 = bytes[offset + 2] & 0xFF;
    final b3 = bytes[offset + 3] & 0xFF;

    final year = 2000 + ((b0 & 0xFC) >> 2);
    final month = (((b0 & 0x03) << 2) | ((b1 & 0xC0) >> 6)).clamp(1, 12);
    final day = ((b1 & 0x3E) >> 1).clamp(1, 31);
    final hour = (((b1 & 0x01) << 4) | ((b2 & 0xF0) >> 4)).clamp(0, 23);
    final minute = (((b2 & 0x0F) << 2) | ((b3 & 0xC0) >> 6)).clamp(0, 59);
    final second = (b3 & 0x3F).clamp(0, 59);

    return DateTime(year, month, day, hour, minute, second);
  }

  /// Parses 8-byte HistoryDataHeader
  static HistoryDataHeader? parseHeader(List<int> bytes, int offset) {
    if (bytes.length < offset + 8) return null;
    final itemCount = ((bytes[offset] & 0xFF) << 8) | (bytes[offset + 1] & 0xFF);
    final ts = parse4BytesTimestamp(bytes, offset + 2);
    final interval = ((bytes[offset + 6] & 0xFF) << 8) | (bytes[offset + 7] & 0xFF);
    return HistoryDataHeader(
      itemCount: itemCount,
      timestamp: ts,
      intervalMinutes: interval > 0 ? interval : 30,
    );
  }

  static DateTime _dayKey(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  /// Parses Step Data stream (Key 0x02 / DataType 1) into daily step totals
  /// Each item is 2 bytes (steps uint16 BE) or 4 bytes (steps uint16 BE + extra)
  static Map<DateTime, int> parseStepStream(List<int> bytes, {int itemSize = 2}) {
    final result = <DateTime, int>{};
    int offset = 0;
    while (offset + 8 <= bytes.length) {
      final header = parseHeader(bytes, offset);
      offset += 8;
      if (header == null || header.itemCount == 0) continue;

      for (int i = 0; i < header.itemCount && offset + itemSize <= bytes.length; i++) {
        final steps = ((bytes[offset] & 0xFF) << 8) | (bytes[offset + 1] & 0xFF);
        offset += itemSize;
        if (steps > 0 && steps < 100000) {
          final itemTime = header.timestamp.add(Duration(minutes: i * header.intervalMinutes));
          final day = _dayKey(itemTime);
          result[day] = (result[day] ?? 0) + steps;
        }
      }
    }
    return result;
  }

  /// Parses Sleep Data stream (Key 0x03 / DataType 2) into daily sleep summaries
  /// Each item is 1 byte: 1=Deep, 2=Light, 3=Awake
  static Map<DateTime, HistorySleepSummary> parseSleepStream(List<int> bytes) {
    final deepMap = <DateTime, int>{};
    final lightMap = <DateTime, int>{};
    final awakeMap = <DateTime, int>{};

    int offset = 0;
    while (offset + 8 <= bytes.length) {
      final header = parseHeader(bytes, offset);
      offset += 8;
      if (header == null || header.itemCount == 0) continue;

      final stepMins = header.intervalMinutes > 0 ? header.intervalMinutes : 5;
      // Sleep sessions starting after 12:00 PM belong to the next morning's sleep date
      var sessionDate = header.timestamp;
      if (sessionDate.hour >= 12) {
        sessionDate = sessionDate.add(const Duration(days: 1));
      }
      final day = _dayKey(sessionDate);

      for (int i = 0; i < header.itemCount && offset < bytes.length; i++) {
        final state = bytes[offset] & 0xFF;
        offset += 1;
        if (state == 1) {
          deepMap[day] = (deepMap[day] ?? 0) + stepMins;
        } else if (state == 2) {
          lightMap[day] = (lightMap[day] ?? 0) + stepMins;
        } else if (state == 3) {
          awakeMap[day] = (awakeMap[day] ?? 0) + stepMins;
        }
      }
    }

    final allDays = <DateTime>{...deepMap.keys, ...lightMap.keys, ...awakeMap.keys};
    return {
      for (final d in allDays)
        d: HistorySleepSummary(
          deepMinutes: deepMap[d] ?? 0,
          lightMinutes: lightMap[d] ?? 0,
          awakeMinutes: awakeMap[d] ?? 0,
        ),
    };
  }

  /// Parses Heart Rate Data stream (Key 0x04 / DataType 3) into daily HR summaries
  static Map<DateTime, HistoryHeartRateSummary> parseHeartRateStream(List<int> bytes) {
    final samplesByDay = <DateTime, List<int>>{};
    int offset = 0;
    while (offset + 8 <= bytes.length) {
      final header = parseHeader(bytes, offset);
      offset += 8;
      if (header == null || header.itemCount == 0) continue;

      for (int i = 0; i < header.itemCount && offset < bytes.length; i++) {
        final bpm = bytes[offset] & 0xFF;
        offset += 1;
        if (bpm >= 35 && bpm <= 220) {
          final itemTime = header.timestamp.add(Duration(minutes: i * header.intervalMinutes));
          final day = _dayKey(itemTime);
          samplesByDay.putIfAbsent(day, () => []).add(bpm);
        }
      }
    }

    return samplesByDay.map((day, list) {
      final minVal = list.reduce(math.min);
      final maxVal = list.reduce(math.max);
      final avgVal = (list.reduce((a, b) => a + b) / list.length).round();
      return MapEntry(
        day,
        HistoryHeartRateSummary(minBpm: minVal, maxBpm: maxVal, avgBpm: avgVal),
      );
    });
  }

  /// Parses SpO2 Data stream (Key 0x05 / DataType 4) into daily average SpO2
  static Map<DateTime, int> parseSpo2Stream(List<int> bytes) {
    final samplesByDay = <DateTime, List<int>>{};
    int offset = 0;
    while (offset + 8 <= bytes.length) {
      final header = parseHeader(bytes, offset);
      offset += 8;
      if (header == null || header.itemCount == 0) continue;

      for (int i = 0; i < header.itemCount && offset < bytes.length; i++) {
        final spo2 = bytes[offset] & 0xFF;
        offset += 1;
        if (spo2 >= 70 && spo2 <= 100) {
          final itemTime = header.timestamp.add(Duration(minutes: i * header.intervalMinutes));
          final day = _dayKey(itemTime);
          samplesByDay.putIfAbsent(day, () => []).add(spo2);
        }
      }
    }

    return samplesByDay.map((day, list) {
      final avgVal = (list.reduce((a, b) => a + b) / list.length).round();
      return MapEntry(day, avgVal);
    });
  }
}
