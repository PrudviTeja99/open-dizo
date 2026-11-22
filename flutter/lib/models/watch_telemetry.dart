import 'dart:convert';

/// Data model holding live watch sensors and fitness telemetry
class WatchTelemetry {
  final int? steps;
  final int? heartRate;
  final int? battery;
  final int? calories;
  final int? spo2;
  final double? distanceMeters;
  final int? deepSleepMinutes;
  final int? lightSleepMinutes;
  final int? systolicBp;
  final int? diastolicBp;
  final int? respiratoryRate;
  final int? pressure;
  final DateTime? lastSyncTime;

  const WatchTelemetry({
    this.steps,
    this.heartRate,
    this.battery,
    this.calories,
    this.spo2,
    this.distanceMeters,
    this.deepSleepMinutes,
    this.lightSleepMinutes,
    this.systolicBp,
    this.diastolicBp,
    this.respiratoryRate,
    this.pressure,
    this.lastSyncTime,
  });

  int get totalSleepMinutes => (deepSleepMinutes ?? 0) + (lightSleepMinutes ?? 0);

  String get totalSleepFormatted {
    final total = totalSleepMinutes;
    if (total <= 0) return '--';
    final hrs = total ~/ 60;
    final mins = total % 60;
    if (hrs > 0 && mins > 0) return '${hrs}h ${mins}m';
    if (hrs > 0) return '${hrs}h';
    return '${mins}m';
  }

  String get distanceKmFormatted {
    if (distanceMeters != null) {
      return (distanceMeters! / 1000.0).toStringAsFixed(2);
    }
    if (steps != null && steps! > 0) {
      return (steps! * 0.00075).toStringAsFixed(2);
    }
    return '0.00';
  }

  int get caloriesKcal {
    if (calories != null) {
      return calories! > 1000 ? (calories! / 1000.0).round() : calories!;
    }
    if (steps != null && steps! > 0) {
      return (steps! * 0.04).round();
    }
    return 0;
  }

  String get bpFormatted {
    if (systolicBp != null && diastolicBp != null && systolicBp! > 0 && diastolicBp! > 0) {
      return '$systolicBp/$diastolicBp';
    }
    return '--';
  }

  WatchTelemetry copyWith({
    int? steps,
    int? heartRate,
    int? battery,
    int? calories,
    int? spo2,
    double? distanceMeters,
    int? deepSleepMinutes,
    int? lightSleepMinutes,
    int? systolicBp,
    int? diastolicBp,
    int? respiratoryRate,
    int? pressure,
    DateTime? lastSyncTime,
  }) {
    return WatchTelemetry(
      steps: steps ?? this.steps,
      heartRate: heartRate ?? this.heartRate,
      battery: battery ?? this.battery,
      calories: calories ?? this.calories,
      spo2: spo2 ?? this.spo2,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      deepSleepMinutes: deepSleepMinutes ?? this.deepSleepMinutes,
      lightSleepMinutes: lightSleepMinutes ?? this.lightSleepMinutes,
      systolicBp: systolicBp ?? this.systolicBp,
      diastolicBp: diastolicBp ?? this.diastolicBp,
      respiratoryRate: respiratoryRate ?? this.respiratoryRate,
      pressure: pressure ?? this.pressure,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'steps': steps,
      'heartRate': heartRate,
      'battery': battery,
      'calories': calories,
      'spo2': spo2,
      'distanceMeters': distanceMeters,
      'deepSleepMinutes': deepSleepMinutes,
      'lightSleepMinutes': lightSleepMinutes,
      'systolicBp': systolicBp,
      'diastolicBp': diastolicBp,
      'respiratoryRate': respiratoryRate,
      'pressure': pressure,
      'lastSyncTime': lastSyncTime?.toIso8601String(),
    };
  }

  factory WatchTelemetry.fromMap(Map<String, dynamic> map) {
    return WatchTelemetry(
      steps: map['steps'] as int?,
      heartRate: map['heartRate'] as int?,
      battery: map['battery'] as int?,
      calories: map['calories'] as int?,
      spo2: map['spo2'] as int?,
      distanceMeters: (map['distanceMeters'] as num?)?.toDouble(),
      deepSleepMinutes: map['deepSleepMinutes'] as int?,
      lightSleepMinutes: map['lightSleepMinutes'] as int?,
      systolicBp: map['systolicBp'] as int?,
      diastolicBp: map['diastolicBp'] as int?,
      respiratoryRate: map['respiratoryRate'] as int?,
      pressure: map['pressure'] as int?,
      lastSyncTime: map['lastSyncTime'] != null
          ? DateTime.tryParse(map['lastSyncTime'] as String)
          : null,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory WatchTelemetry.fromJson(String source) =>
      WatchTelemetry.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
