/// Data model holding live watch sensors and fitness telemetry
class WatchTelemetry {
  final int? steps;
  final int? heartRate;
  final int? battery;
  final int? calories;
  final int? spo2;
  final double? distanceMeters;

  const WatchTelemetry({
    this.steps,
    this.heartRate,
    this.battery,
    this.calories,
    this.spo2,
    this.distanceMeters,
  });

  WatchTelemetry copyWith({
    int? steps,
    int? heartRate,
    int? battery,
    int? calories,
    int? spo2,
    double? distanceMeters,
  }) {
    return WatchTelemetry(
      steps: steps ?? this.steps,
      heartRate: heartRate ?? this.heartRate,
      battery: battery ?? this.battery,
      calories: calories ?? this.calories,
      spo2: spo2 ?? this.spo2,
      distanceMeters: distanceMeters ?? this.distanceMeters,
    );
  }
}
