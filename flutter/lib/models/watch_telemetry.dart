import 'dart:convert';

/// Data model holding live watch sensors and fitness telemetry
class WatchTelemetry {
  final int? steps;
  final int? heartRate;
  final int? battery;
  final int? calories;
  final int? spo2;
  final double? distanceMeters;
  final DateTime? lastSyncTime;

  const WatchTelemetry({
    this.steps,
    this.heartRate,
    this.battery,
    this.calories,
    this.spo2,
    this.distanceMeters,
    this.lastSyncTime,
  });

  WatchTelemetry copyWith({
    int? steps,
    int? heartRate,
    int? battery,
    int? calories,
    int? spo2,
    double? distanceMeters,
    DateTime? lastSyncTime,
  }) {
    return WatchTelemetry(
      steps: steps ?? this.steps,
      heartRate: heartRate ?? this.heartRate,
      battery: battery ?? this.battery,
      calories: calories ?? this.calories,
      spo2: spo2 ?? this.spo2,
      distanceMeters: distanceMeters ?? this.distanceMeters,
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
      lastSyncTime: map['lastSyncTime'] != null
          ? DateTime.tryParse(map['lastSyncTime'] as String)
          : null,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory WatchTelemetry.fromJson(String source) =>
      WatchTelemetry.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
