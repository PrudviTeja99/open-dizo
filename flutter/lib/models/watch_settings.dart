import 'dart:convert';

/// Complete configuration and settings model for the DIZO Watch D
/// Conforms to official companion app specification
class WatchSettings {
  // Display & Vibration
  final int brightness; // 1..5
  final int screenTimeoutSeconds; // 5, 10, 15
  final int vibrationIntensity; // 0..2

  // Raise to Wake (Turn Wrist Lighting)
  final bool raiseToWakeEnabled;
  final int raiseToWakeStartHour;
  final int raiseToWakeStartMinute;
  final int raiseToWakeEndHour;
  final int raiseToWakeEndMinute;

  // Do Not Disturb (DND)
  final bool dndEnabled;
  final bool dndAllDay;
  final int dndStartHour;
  final int dndStartMinute;
  final int dndEndHour;
  final int dndEndMinute;

  // Health & Reminders
  final bool continuousHealthEnabled;
  final int healthIntervalMinutes; // 10, 30, 60
  final bool sedentaryEnabled;
  final int sedentaryIntervalMinutes; // 30, 60, 90, 120
  final int sedentaryStartHour;
  final int sedentaryEndHour;
  final bool sedentaryDndEnabled; // Skip reminder during lunch
  final bool drinkWaterEnabled;
  final int drinkWaterIntervalMinutes; // 30, 60, 90, 120
  final int drinkWaterStartHour;
  final int drinkWaterEndHour;

  // Preferences & Units
  final bool is24HourFormat;
  final bool isMetricUnit;
  final bool isRightHand;
  final bool weatherEnabled;
  final bool disconnectReminder;

  // Fitness Target
  final int targetSteps;
  final int targetDistanceMeters;
  final int targetCalories;

  // User Body Profile & Weather City
  final bool isMale;
  final int age;
  final double heightCm;
  final double weightKg;
  final String weatherCity;
  final bool keepAliveInBackground;
  final bool musicSyncEnabled;

  // Heart Rate & Blood Pressure Warning Thresholds
  final bool warnHrStaticEnabled;
  final int warnHrStaticBpm;
  final bool warnHrDynamicEnabled;
  final int warnHrDynamicBpm;
  final bool warnBpEnabled;
  final int warnBpSbpUpper;
  final int warnBpSbpLower;
  final int warnBpDbpUpper;
  final int warnBpDbpLower;

  // Language & Apply Target
  final String languageCode;
  final String languageTarget; // 'both', 'appOnly', 'watchOnly'

  // Weather Location Source
  final bool weatherUseGps; // true = auto-detect via GPS, false = use weatherCity

  const WatchSettings({
    this.brightness = 3,
    this.screenTimeoutSeconds = 5,
    this.vibrationIntensity = 1,
    this.raiseToWakeEnabled = true,
    this.raiseToWakeStartHour = 8,
    this.raiseToWakeStartMinute = 0,
    this.raiseToWakeEndHour = 22,
    this.raiseToWakeEndMinute = 0,
    this.dndEnabled = false,
    this.dndAllDay = false,
    this.dndStartHour = 22,
    this.dndStartMinute = 0,
    this.dndEndHour = 7,
    this.dndEndMinute = 0,
    this.continuousHealthEnabled = true,
    this.healthIntervalMinutes = 30,
    this.sedentaryEnabled = true,
    this.sedentaryIntervalMinutes = 60,
    this.sedentaryStartHour = 9,
    this.sedentaryEndHour = 18,
    this.sedentaryDndEnabled = true,
    this.drinkWaterEnabled = false,
    this.drinkWaterIntervalMinutes = 60,
    this.drinkWaterStartHour = 9,
    this.drinkWaterEndHour = 20,
    this.is24HourFormat = true,
    this.isMetricUnit = true,
    this.isRightHand = false,
    this.weatherEnabled = true,
    this.disconnectReminder = false,
    this.targetSteps = 10000,
    this.targetDistanceMeters = 5000,
    this.targetCalories = 300,
    this.isMale = true,
    this.age = 25,
    this.heightCm = 175.0,
    this.weightKg = 70.0,
    this.weatherCity = 'Bengaluru',
    this.keepAliveInBackground = true,
    this.musicSyncEnabled = true,
    this.warnHrStaticEnabled = false,
    this.warnHrStaticBpm = 120,
    this.warnHrDynamicEnabled = false,
    this.warnHrDynamicBpm = 170,
    this.warnBpEnabled = false,
    this.warnBpSbpUpper = 140,
    this.warnBpSbpLower = 90,
    this.warnBpDbpUpper = 90,
    this.warnBpDbpLower = 60,
    this.languageCode = 'en',
    this.languageTarget = 'both',
    this.weatherUseGps = false,
  });

  WatchSettings copyWith({
    int? brightness,
    int? screenTimeoutSeconds,
    int? vibrationIntensity,
    bool? raiseToWakeEnabled,
    int? raiseToWakeStartHour,
    int? raiseToWakeStartMinute,
    int? raiseToWakeEndHour,
    int? raiseToWakeEndMinute,
    bool? dndEnabled,
    bool? dndAllDay,
    int? dndStartHour,
    int? dndStartMinute,
    int? dndEndHour,
    int? dndEndMinute,
    bool? continuousHealthEnabled,
    int? healthIntervalMinutes,
    bool? sedentaryEnabled,
    int? sedentaryIntervalMinutes,
    int? sedentaryStartHour,
    int? sedentaryEndHour,
    bool? sedentaryDndEnabled,
    bool? drinkWaterEnabled,
    int? drinkWaterIntervalMinutes,
    int? drinkWaterStartHour,
    int? drinkWaterEndHour,
    bool? is24HourFormat,
    bool? isMetricUnit,
    bool? isRightHand,
    bool? weatherEnabled,
    bool? disconnectReminder,
    int? targetSteps,
    int? targetDistanceMeters,
    int? targetCalories,
    bool? isMale,
    int? age,
    double? heightCm,
    double? weightKg,
    String? weatherCity,
    bool? keepAliveInBackground,
    bool? musicSyncEnabled,
    bool? warnHrStaticEnabled,
    int? warnHrStaticBpm,
    bool? warnHrDynamicEnabled,
    int? warnHrDynamicBpm,
    bool? warnBpEnabled,
    int? warnBpSbpUpper,
    int? warnBpSbpLower,
    int? warnBpDbpUpper,
    int? warnBpDbpLower,
    String? languageCode,
    String? languageTarget,
    bool? weatherUseGps,
  }) {
    return WatchSettings(
      brightness: brightness ?? this.brightness,
      screenTimeoutSeconds: screenTimeoutSeconds ?? this.screenTimeoutSeconds,
      vibrationIntensity: vibrationIntensity ?? this.vibrationIntensity,
      raiseToWakeEnabled: raiseToWakeEnabled ?? this.raiseToWakeEnabled,
      raiseToWakeStartHour: raiseToWakeStartHour ?? this.raiseToWakeStartHour,
      raiseToWakeStartMinute: raiseToWakeStartMinute ?? this.raiseToWakeStartMinute,
      raiseToWakeEndHour: raiseToWakeEndHour ?? this.raiseToWakeEndHour,
      raiseToWakeEndMinute: raiseToWakeEndMinute ?? this.raiseToWakeEndMinute,
      dndEnabled: dndEnabled ?? this.dndEnabled,
      dndAllDay: dndAllDay ?? this.dndAllDay,
      dndStartHour: dndStartHour ?? this.dndStartHour,
      dndStartMinute: dndStartMinute ?? this.dndStartMinute,
      dndEndHour: dndEndHour ?? this.dndEndHour,
      dndEndMinute: dndEndMinute ?? this.dndEndMinute,
      continuousHealthEnabled: continuousHealthEnabled ?? this.continuousHealthEnabled,
      healthIntervalMinutes: healthIntervalMinutes ?? this.healthIntervalMinutes,
      sedentaryEnabled: sedentaryEnabled ?? this.sedentaryEnabled,
      sedentaryIntervalMinutes: sedentaryIntervalMinutes ?? this.sedentaryIntervalMinutes,
      sedentaryStartHour: sedentaryStartHour ?? this.sedentaryStartHour,
      sedentaryEndHour: sedentaryEndHour ?? this.sedentaryEndHour,
      sedentaryDndEnabled: sedentaryDndEnabled ?? this.sedentaryDndEnabled,
      drinkWaterEnabled: drinkWaterEnabled ?? this.drinkWaterEnabled,
      drinkWaterIntervalMinutes: drinkWaterIntervalMinutes ?? this.drinkWaterIntervalMinutes,
      drinkWaterStartHour: drinkWaterStartHour ?? this.drinkWaterStartHour,
      drinkWaterEndHour: drinkWaterEndHour ?? this.drinkWaterEndHour,
      is24HourFormat: is24HourFormat ?? this.is24HourFormat,
      isMetricUnit: isMetricUnit ?? this.isMetricUnit,
      isRightHand: isRightHand ?? this.isRightHand,
      weatherEnabled: weatherEnabled ?? this.weatherEnabled,
      disconnectReminder: disconnectReminder ?? this.disconnectReminder,
      targetSteps: targetSteps ?? this.targetSteps,
      targetDistanceMeters: targetDistanceMeters ?? this.targetDistanceMeters,
      targetCalories: targetCalories ?? this.targetCalories,
      isMale: isMale ?? this.isMale,
      age: age ?? this.age,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      weatherCity: weatherCity ?? this.weatherCity,
      keepAliveInBackground: keepAliveInBackground ?? this.keepAliveInBackground,
      musicSyncEnabled: musicSyncEnabled ?? this.musicSyncEnabled,
      warnHrStaticEnabled: warnHrStaticEnabled ?? this.warnHrStaticEnabled,
      warnHrStaticBpm: warnHrStaticBpm ?? this.warnHrStaticBpm,
      warnHrDynamicEnabled: warnHrDynamicEnabled ?? this.warnHrDynamicEnabled,
      warnHrDynamicBpm: warnHrDynamicBpm ?? this.warnHrDynamicBpm,
      warnBpEnabled: warnBpEnabled ?? this.warnBpEnabled,
      warnBpSbpUpper: warnBpSbpUpper ?? this.warnBpSbpUpper,
      warnBpSbpLower: warnBpSbpLower ?? this.warnBpSbpLower,
      warnBpDbpUpper: warnBpDbpUpper ?? this.warnBpDbpUpper,
      warnBpDbpLower: warnBpDbpLower ?? this.warnBpDbpLower,
      languageCode: languageCode ?? this.languageCode,
      languageTarget: languageTarget ?? this.languageTarget,
      weatherUseGps: weatherUseGps ?? this.weatherUseGps,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'brightness': brightness,
      'screenTimeoutSeconds': screenTimeoutSeconds,
      'vibrationIntensity': vibrationIntensity,
      'raiseToWakeEnabled': raiseToWakeEnabled,
      'raiseToWakeStartHour': raiseToWakeStartHour,
      'raiseToWakeStartMinute': raiseToWakeStartMinute,
      'raiseToWakeEndHour': raiseToWakeEndHour,
      'raiseToWakeEndMinute': raiseToWakeEndMinute,
      'dndEnabled': dndEnabled,
      'dndAllDay': dndAllDay,
      'dndStartHour': dndStartHour,
      'dndStartMinute': dndStartMinute,
      'dndEndHour': dndEndHour,
      'dndEndMinute': dndEndMinute,
      'continuousHealthEnabled': continuousHealthEnabled,
      'healthIntervalMinutes': healthIntervalMinutes,
      'sedentaryEnabled': sedentaryEnabled,
      'sedentaryIntervalMinutes': sedentaryIntervalMinutes,
      'sedentaryStartHour': sedentaryStartHour,
      'sedentaryEndHour': sedentaryEndHour,
      'sedentaryDndEnabled': sedentaryDndEnabled,
      'drinkWaterEnabled': drinkWaterEnabled,
      'drinkWaterIntervalMinutes': drinkWaterIntervalMinutes,
      'drinkWaterStartHour': drinkWaterStartHour,
      'drinkWaterEndHour': drinkWaterEndHour,
      'is24HourFormat': is24HourFormat,
      'isMetricUnit': isMetricUnit,
      'isRightHand': isRightHand,
      'weatherEnabled': weatherEnabled,
      'disconnectReminder': disconnectReminder,
      'targetSteps': targetSteps,
      'targetDistanceMeters': targetDistanceMeters,
      'targetCalories': targetCalories,
      'isMale': isMale,
      'age': age,
      'heightCm': heightCm,
      'weightKg': weightKg,
      'weatherCity': weatherCity,
      'keepAliveInBackground': keepAliveInBackground,
      'musicSyncEnabled': musicSyncEnabled,
      'warnHrStaticEnabled': warnHrStaticEnabled,
      'warnHrStaticBpm': warnHrStaticBpm,
      'warnHrDynamicEnabled': warnHrDynamicEnabled,
      'warnHrDynamicBpm': warnHrDynamicBpm,
      'warnBpEnabled': warnBpEnabled,
      'warnBpSbpUpper': warnBpSbpUpper,
      'warnBpSbpLower': warnBpSbpLower,
      'warnBpDbpUpper': warnBpDbpUpper,
      'warnBpDbpLower': warnBpDbpLower,
      'languageCode': languageCode,
      'languageTarget': languageTarget,
      'weatherUseGps': weatherUseGps,
    };
  }

  factory WatchSettings.fromMap(Map<String, dynamic> map) {
    return WatchSettings(
      brightness: map['brightness'] as int? ?? 3,
      screenTimeoutSeconds: map['screenTimeoutSeconds'] as int? ?? 5,
      vibrationIntensity: map['vibrationIntensity'] as int? ?? 1,
      raiseToWakeEnabled: map['raiseToWakeEnabled'] as bool? ?? true,
      raiseToWakeStartHour: map['raiseToWakeStartHour'] as int? ?? 8,
      raiseToWakeStartMinute: map['raiseToWakeStartMinute'] as int? ?? 0,
      raiseToWakeEndHour: map['raiseToWakeEndHour'] as int? ?? 22,
      raiseToWakeEndMinute: map['raiseToWakeEndMinute'] as int? ?? 0,
      dndEnabled: map['dndEnabled'] as bool? ?? false,
      dndAllDay: map['dndAllDay'] as bool? ?? false,
      dndStartHour: map['dndStartHour'] as int? ?? 22,
      dndStartMinute: map['dndStartMinute'] as int? ?? 0,
      dndEndHour: map['dndEndHour'] as int? ?? 7,
      dndEndMinute: map['dndEndMinute'] as int? ?? 0,
      continuousHealthEnabled: map['continuousHealthEnabled'] as bool? ?? true,
      healthIntervalMinutes: map['healthIntervalMinutes'] as int? ?? 30,
      sedentaryEnabled: map['sedentaryEnabled'] as bool? ?? true,
      sedentaryIntervalMinutes: map['sedentaryIntervalMinutes'] as int? ?? 60,
      sedentaryStartHour: map['sedentaryStartHour'] as int? ?? 9,
      sedentaryEndHour: map['sedentaryEndHour'] as int? ?? 18,
      sedentaryDndEnabled: map['sedentaryDndEnabled'] as bool? ?? true,
      drinkWaterEnabled: map['drinkWaterEnabled'] as bool? ?? false,
      drinkWaterIntervalMinutes: map['drinkWaterIntervalMinutes'] as int? ?? 60,
      drinkWaterStartHour: map['drinkWaterStartHour'] as int? ?? 9,
      drinkWaterEndHour: map['drinkWaterEndHour'] as int? ?? 20,
      is24HourFormat: map['is24HourFormat'] as bool? ?? true,
      isMetricUnit: map['isMetricUnit'] as bool? ?? true,
      isRightHand: map['isRightHand'] as bool? ?? false,
      weatherEnabled: map['weatherEnabled'] as bool? ?? true,
      disconnectReminder: map['disconnectReminder'] as bool? ?? false,
      targetSteps: map['targetSteps'] as int? ?? 10000,
      targetDistanceMeters: map['targetDistanceMeters'] as int? ?? 5000,
      targetCalories: map['targetCalories'] as int? ?? 300,
      isMale: map['isMale'] as bool? ?? true,
      age: map['age'] as int? ?? 25,
      heightCm: (map['heightCm'] as num?)?.toDouble() ?? 175.0,
      weightKg: (map['weightKg'] as num?)?.toDouble() ?? 70.0,
      weatherCity: map['weatherCity'] as String? ?? 'Bengaluru',
      keepAliveInBackground: map['keepAliveInBackground'] as bool? ?? true,
      musicSyncEnabled: map['musicSyncEnabled'] as bool? ?? true,
      warnHrStaticEnabled: map['warnHrStaticEnabled'] as bool? ?? false,
      warnHrStaticBpm: map['warnHrStaticBpm'] as int? ?? 120,
      warnHrDynamicEnabled: map['warnHrDynamicEnabled'] as bool? ?? false,
      warnHrDynamicBpm: map['warnHrDynamicBpm'] as int? ?? 170,
      warnBpEnabled: map['warnBpEnabled'] as bool? ?? false,
      warnBpSbpUpper: map['warnBpSbpUpper'] as int? ?? 140,
      warnBpSbpLower: map['warnBpSbpLower'] as int? ?? 90,
      warnBpDbpUpper: map['warnBpDbpUpper'] as int? ?? 90,
      warnBpDbpLower: map['warnBpDbpLower'] as int? ?? 60,
      languageCode: map['languageCode'] as String? ?? 'en',
      languageTarget: map['languageTarget'] as String? ?? 'both',
      weatherUseGps: map['weatherUseGps'] as bool? ?? false,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory WatchSettings.fromJson(String source) =>
      WatchSettings.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
