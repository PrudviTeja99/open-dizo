import 'dart:convert';

/// Represents a single alarm clock set on the DIZO Watch D
/// Conforms to official companion app specification (Cmd 0x02, Key 0x02)
class WatchAlarm {
  final int id; // 0..7 (up to 8 alarms)
  final int hour; // 0..23
  final int minute; // 0..59
  final Set<int> repeatDays; // 0=Sunday, 1=Monday, ..., 6=Saturday
  final bool isEnabled;
  final String label;

  const WatchAlarm({
    required this.id,
    required this.hour,
    required this.minute,
    this.repeatDays = const {},
    this.isEnabled = true,
    this.label = '',
  });

  /// Repeat bitmask for HTSmart protocol:
  /// Bit 0: Sunday, Bit 1: Monday, ..., Bit 6: Saturday
  int get repeatBitmask {
    int mask = 0;
    for (final day in repeatDays) {
      if (day >= 0 && day <= 6) {
        mask |= (1 << day);
      }
    }
    return mask;
  }

  /// True if alarm fires only once (no repeat days selected)
  bool get isOnce => repeatDays.isEmpty;

  /// Human-readable repeat description
  String get repeatSummary {
    if (repeatDays.isEmpty) return 'Once';
    if (repeatDays.length == 7) return 'Every day';
    if (repeatDays.length == 5 &&
        !repeatDays.contains(0) &&
        !repeatDays.contains(6)) {
      return 'Weekdays';
    }
    if (repeatDays.length == 2 &&
        repeatDays.contains(0) &&
        repeatDays.contains(6)) {
      return 'Weekends';
    }

    const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final sorted = repeatDays.toList()..sort();
    return sorted.map((d) => dayNames[d]).join(', ');
  }

  /// Formatted 12-hour or 24-hour time string
  String formatTime({bool is24Hour = false}) {
    if (is24Hour) {
      final h = hour.toString().padLeft(2, '0');
      final m = minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }

  /// Serializes alarm into HTSmart 6-byte item format + optional label bytes
  List<int> toHtsmartBytes({DateTime? targetDate}) {
    final now = targetDate ?? DateTime.now();
    final year = (now.year - 2000).clamp(0, 127);
    final month = now.month;
    final day = now.day;

    final labelBytes = utf8.encode(label);
    final labelLen = labelBytes.length.clamp(0, 32);

    final result = List<int>.filled(6 + labelLen, 0);
    result[0] = (labelLen + 5) & 0xFF; // Length of remaining payload
    result[1] = ((year << 2) | (month >> 2)) & 0xFF;
    result[2] = ((month << 6) | (day << 1) | (hour >> 4)) & 0xFF;
    result[3] = ((hour << 4) | (minute >> 2)) & 0xFF;
    result[4] = ((minute << 6) | ((id & 0x07) << 3)) & 0xFF;
    result[5] = (repeatBitmask & 0x7F) | (isEnabled ? 0x80 : 0x00);

    for (int i = 0; i < labelLen; i++) {
      result[6 + i] = labelBytes[i];
    }
    return result;
  }

  /// Deserializes a single alarm item from HTSmart bytes
  static WatchAlarm? fromHtsmartBytes(List<int> bytes, int offset) {
    if (bytes.length < offset + 6) return null;
    final length = bytes[offset] & 0xFF;
    if (length < 5 || bytes.length < offset + 1 + length) return null;

    final b2 = bytes[offset + 2] & 0xFF;
    final b3 = bytes[offset + 3] & 0xFF;
    final b4 = bytes[offset + 4] & 0xFF;
    final b5 = bytes[offset + 5] & 0xFF;

    final hour = ((b2 & 0x01) << 4) | ((b3 >> 4) & 0x0F);
    final minute = ((b3 & 0x0F) << 2) | ((b4 >> 6) & 0x03);
    final alarmId = (b4 >> 3) & 0x07;
    final isEnabled = (b5 & 0x80) != 0;
    final repeatMask = b5 & 0x7F;

    final repeatDays = <int>{};
    for (int i = 0; i < 7; i++) {
      if ((repeatMask & (1 << i)) != 0) {
        repeatDays.add(i);
      }
    }

    String label = '';
    final labelLen = length - 5;
    if (labelLen > 0 && bytes.length >= offset + 6 + labelLen) {
      try {
        final labelBytes = bytes.sublist(offset + 6, offset + 6 + labelLen);
        label = utf8.decode(labelBytes, allowMalformed: true).trim();
      } catch (_) {}
    }

    return WatchAlarm(
      id: alarmId,
      hour: hour.clamp(0, 23),
      minute: minute.clamp(0, 59),
      repeatDays: repeatDays,
      isEnabled: isEnabled,
      label: label,
    );
  }

  WatchAlarm copyWith({
    int? id,
    int? hour,
    int? minute,
    Set<int>? repeatDays,
    bool? isEnabled,
    String? label,
  }) {
    return WatchAlarm(
      id: id ?? this.id,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      repeatDays: repeatDays ?? this.repeatDays,
      isEnabled: isEnabled ?? this.isEnabled,
      label: label ?? this.label,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'hour': hour,
        'minute': minute,
        'repeatDays': repeatDays.toList(),
        'isEnabled': isEnabled,
        'label': label,
      };

  factory WatchAlarm.fromJson(Map<String, dynamic> json) => WatchAlarm(
        id: json['id'] as int? ?? 0,
        hour: json['hour'] as int? ?? 8,
        minute: json['minute'] as int? ?? 0,
        repeatDays: (json['repeatDays'] as List<dynamic>?)
                ?.map((e) => e as int)
                .toSet() ??
            const {},
        isEnabled: json['isEnabled'] as bool? ?? true,
        label: json['label'] as String? ?? '',
      );
}
