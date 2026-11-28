import 'package:intl/intl.dart';

/// Single day snapshot for historical charts
class DailyHealthRecord {
  final DateTime date;
  final int steps;
  final int goalSteps;
  final int caloriesKcal;
  final double distanceKm;
  final int avgHeartRate;
  final int maxHeartRate;
  final int minHeartRate;
  final int sleepMinutes;
  final int deepSleepMinutes;
  final int lightSleepMinutes;
  final int avgSpo2;
  final int sbp; // Systolic Blood Pressure
  final int dbp; // Diastolic Blood Pressure

  const DailyHealthRecord({
    required this.date,
    required this.steps,
    this.goalSteps = 10000,
    required this.caloriesKcal,
    required this.distanceKm,
    this.avgHeartRate = 72,
    this.maxHeartRate = 120,
    this.minHeartRate = 58,
    this.sleepMinutes = 440,
    this.deepSleepMinutes = 110,
    this.lightSleepMinutes = 330,
    this.avgSpo2 = 98,
    this.sbp = 118,
    this.dbp = 78,
  });

  String get dayAbbreviation => DateFormat('E').format(date); // Mon, Tue...
  String get formattedDate => DateFormat('MMM d').format(date); // Nov 26

  double get stepCompletionRatio => (steps / goalSteps).clamp(0.0, 1.0);

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'steps': steps,
        'goalSteps': goalSteps,
        'caloriesKcal': caloriesKcal,
        'distanceKm': distanceKm,
        'avgHeartRate': avgHeartRate,
        'maxHeartRate': maxHeartRate,
        'minHeartRate': minHeartRate,
        'sleepMinutes': sleepMinutes,
        'deepSleepMinutes': deepSleepMinutes,
        'lightSleepMinutes': lightSleepMinutes,
        'avgSpo2': avgSpo2,
        'sbp': sbp,
        'dbp': dbp,
      };

  factory DailyHealthRecord.fromJson(Map<String, dynamic> json) =>
      DailyHealthRecord(
        date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
        steps: json['steps'] as int? ?? 0,
        goalSteps: json['goalSteps'] as int? ?? 10000,
        caloriesKcal: json['caloriesKcal'] as int? ?? 0,
        distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
        avgHeartRate: json['avgHeartRate'] as int? ?? 72,
        maxHeartRate: json['maxHeartRate'] as int? ?? 120,
        minHeartRate: json['minHeartRate'] as int? ?? 58,
        sleepMinutes: json['sleepMinutes'] as int? ?? 420,
        deepSleepMinutes: json['deepSleepMinutes'] as int? ?? 100,
        lightSleepMinutes: json['lightSleepMinutes'] as int? ?? 320,
        avgSpo2: json['avgSpo2'] as int? ?? 98,
        sbp: json['sbp'] as int? ?? 118,
        dbp: json['dbp'] as int? ?? 78,
      );

  /// Generates a realistic 7-day trailing history leading up to today
  static List<DailyHealthRecord> generateTrailingWeek({
    required int todaySteps,
    required int todayCalories,
    required double todayDistance,
    required int todayHeartRate,
  }) {
    final now = DateTime.now();
    final list = <DailyHealthRecord>[];

    final stepProfiles = [7820, 9410, 6540, 10250, 8900, 11300];
    final calProfiles = [260, 315, 220, 350, 295, 380];
    final distProfiles = [5.2, 6.4, 4.3, 7.1, 6.0, 7.8];
    final hrProfiles = [71, 74, 69, 75, 72, 76];
    final sleepProfiles = [450, 420, 480, 390, 460, 500];

    for (int i = 6; i >= 1; i--) {
      final date = now.subtract(Duration(days: i));
      final idx = 6 - i;
      list.add(DailyHealthRecord(
        date: date,
        steps: stepProfiles[idx % stepProfiles.length],
        caloriesKcal: calProfiles[idx % calProfiles.length],
        distanceKm: distProfiles[idx % distProfiles.length],
        avgHeartRate: hrProfiles[idx % hrProfiles.length],
        maxHeartRate: hrProfiles[idx % hrProfiles.length] + 45,
        minHeartRate: hrProfiles[idx % hrProfiles.length] - 14,
        sleepMinutes: sleepProfiles[idx % sleepProfiles.length],
        deepSleepMinutes: (sleepProfiles[idx % sleepProfiles.length] * 0.25).round(),
        lightSleepMinutes: (sleepProfiles[idx % sleepProfiles.length] * 0.75).round(),
      ));
    }

    // Add today as the 7th entry
    list.add(DailyHealthRecord(
      date: now,
      steps: todaySteps > 0 ? todaySteps : 4520,
      caloriesKcal: todayCalories > 0 ? todayCalories : 185,
      distanceKm: todayDistance > 0 ? todayDistance : 3.1,
      avgHeartRate: todayHeartRate > 0 ? todayHeartRate : 72,
      maxHeartRate: (todayHeartRate > 0 ? todayHeartRate + 38 : 115),
      minHeartRate: (todayHeartRate > 0 ? todayHeartRate - 12 : 58),
      sleepMinutes: 445,
      deepSleepMinutes: 115,
      lightSleepMinutes: 330,
    ));

    return list;
  }
}
