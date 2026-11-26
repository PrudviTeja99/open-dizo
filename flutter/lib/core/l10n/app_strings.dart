import 'package:flutter/foundation.dart';

enum AppLanguage {
  english('en', 'English', 'English', 3),
  telugu('te', 'Telugu', 'తెలుగు', 67),
  hindi('hi', 'Hindi', 'हिन्दी', 19),
  tamil('ta', 'Tamil', 'தமிழ்', 65),
  kannada('kn', 'Kannada', 'ಕನ್ನಡ', 61),
  malayalam('ml', 'Malayalam', 'മലയാളം', 63),
  marathi('mr', 'Marathi', 'मराठी', 64),
  spanish('es', 'Spanish', 'Español', 6),
  french('fr', 'French', 'Français', 8),
  german('de', 'German', 'Deutsch', 4);

  final String code;
  final String englishName;
  final String nativeName;
  final int watchCode;

  const AppLanguage(this.code, this.englishName, this.nativeName, this.watchCode);

  static AppLanguage fromCode(String code) {
    return AppLanguage.values.firstWhere(
      (l) => l.code == code,
      orElse: () => AppLanguage.english,
    );
  }
}

enum LanguageApplyTarget {
  both('both', 'Both'),
  appOnly('appOnly', 'App Only'),
  watchOnly('watchOnly', 'Watch Only');

  final String id;
  final String label;

  const LanguageApplyTarget(this.id, this.label);

  static LanguageApplyTarget fromId(String id) {
    return LanguageApplyTarget.values.firstWhere(
      (t) => t.id == id,
      orElse: () => LanguageApplyTarget.both,
    );
  }
}

/// Reactive localization helper for Open Dizo
class AppStrings {
  static final ValueNotifier<AppLanguage> currentLanguage =
      ValueNotifier<AppLanguage>(AppLanguage.english);

  static void setLanguage(AppLanguage lang) {
    if (currentLanguage.value != lang) {
      currentLanguage.value = lang;
    }
  }

  static String t(String key) {
    final code = currentLanguage.value.code;
    final table = _localized[code] ?? _localized['en']!;
    return table[key] ?? _localized['en']![key] ?? key;
  }

  static const Map<String, Map<String, String>> _localized = {
    'en': {
      'tab_health': 'Health',
      'tab_studio': 'Studio',
      'tab_reminders': 'Reminders',
      'tab_device': 'Device',
      'title_health': 'Health & Activity',
      'title_studio': 'Watch Face Studio',
      'title_reminders': 'Alarms & Alerts',
      'title_device': 'Device Settings',
      'connected': 'Connected',
      'offline': 'Offline',
      'daily_activity': 'Daily Activity',
      'steps': 'Steps',
      'active_burn': 'Active Burn',
      'distance': 'Distance',
      'weekly_analytics': 'Weekly Analytics',
      'live_vitals': 'Live Health Vitals',
      'measure_vitals': 'Measure Vitals',
      'measuring': 'Measuring...',
      'heart_rate': 'Heart Rate',
      'blood_pressure': 'Blood Pressure',
      'blood_oxygen': 'Blood Oxygen',
      'sleep': 'Sleep',
      'watch_alarms': 'Watch Alarms',
      'add_alarm': 'Add Alarm',
      'sedentary_alert': 'Sedentary Inactivity Alert',
      'hydration_reminder': 'Hydration Reminder',
      'find_watch': 'Find Watch',
      'switch_device': 'Switch Device',
      'notifications_calls': 'Notifications & Calls',
      'weather_sync': 'Weather Sync',
      'fitness_goals': 'Fitness Goals & Profile',
      'music_control': 'Music & Media Control',
      'health_warnings': 'Health Warning Alerts',
      'display_gestures': 'Display & Gestures',
      'preferences_units': 'Preferences & Units',
      'language': 'Language',
      'apply_language_to': 'Apply Language To',
      'system_diagnostics': 'System & Diagnostics',
    },
    'te': {
      'tab_health': 'ఆరోగ్యం',
      'tab_studio': 'స్టూడియో',
      'tab_reminders': 'రిమైండర్లు',
      'tab_device': 'డివైస్',
      'title_health': 'ఆరోగ్యం & కార్యాచరణ',
      'title_studio': 'వాచ్ ఫేస్ స్టూడియో',
      'title_reminders': 'అలారాలు & హెచ్చరికలు',
      'title_device': 'డివైస్ సెట్టింగ్‌లు',
      'connected': 'కనెక్ట్ అయింది',
      'offline': 'ఆఫ్‌లైన్',
      'daily_activity': 'రోజువారీ కార్యాచరణ',
      'steps': 'అడుగులు',
      'active_burn': 'కేలరీలు',
      'distance': 'దూరం',
      'weekly_analytics': 'వారపు విశ్లేషణ',
      'live_vitals': 'లైవ్ ఆరోగ్య కొలతలు',
      'measure_vitals': 'కొలవండి',
      'measuring': 'కొలుస్తోంది...',
      'heart_rate': 'హృదయ స్పందన',
      'blood_pressure': 'రక్తపోటు',
      'blood_oxygen': 'ఆక్సిజన్',
      'sleep': 'నిద్ర',
      'watch_alarms': 'వాచ్ అలారాలు',
      'add_alarm': 'అలారం జోడించు',
      'sedentary_alert': 'నిశ్చల హెచ్చరిక',
      'hydration_reminder': 'నీరు త్రాగే రిమైండర్',
      'find_watch': 'వాచ్‌ను కనుగొను',
      'switch_device': 'డివైస్ మార్చు',
      'notifications_calls': 'నోటిఫికేషన్లు & కాల్స్',
      'weather_sync': 'వాతావరణ సింక్',
      'fitness_goals': 'ఫిట్‌నెస్ లక్ష్యాలు & ప్రొఫైల్',
      'music_control': 'మ్యూజిక్ & మీడియా కంట్రోల్',
      'health_warnings': 'ఆరోగ్య హెచ్చరికలు',
      'display_gestures': 'డిస్‌ప్లే & సంజ్ఞలు',
      'preferences_units': 'ప్రాధాన్యతలు & యూనిట్లు',
      'language': 'భాష',
      'apply_language_to': 'భాషను వర్తింపజేయండి',
      'system_diagnostics': 'సిస్టమ్ & డయాగ్నస్టిక్స్',
    },
    'hi': {
      'tab_health': 'स्वास्थ्य',
      'tab_studio': 'स्टूडियो',
      'tab_reminders': 'रिमाइंडर',
      'tab_device': 'डिवाइस',
      'title_health': 'स्वास्थ्य और गतिविधि',
      'title_studio': 'वॉच फेस स्टूडियो',
      'title_reminders': 'अलार्म और अलर्ट',
      'title_device': 'डिवाइस सेटिंग्स',
      'connected': 'कनेक्टेड',
      'offline': 'ऑफ़लाइन',
      'daily_activity': 'दैनिक गतिविधि',
      'steps': 'कदम',
      'active_burn': 'कैलोरी',
      'distance': 'दूरी',
      'weekly_analytics': 'साप्ताहिक विश्लेषण',
      'live_vitals': 'लाइव स्वास्थ्य डेटा',
      'measure_vitals': 'मापें',
      'measuring': 'माप रहा है...',
      'heart_rate': 'हृदय गति',
      'blood_pressure': 'रक्तचाप',
      'blood_oxygen': 'ऑक्सीजन',
      'sleep': 'नींद',
      'watch_alarms': 'वॉच अलार्म',
      'add_alarm': 'अलार्म जोड़ें',
      'sedentary_alert': 'निष्क्रियता अलर्ट',
      'hydration_reminder': 'पानी पीने का रिमाइंडर',
      'find_watch': 'वॉच खोजें',
      'switch_device': 'डिवाइस बदलें',
      'notifications_calls': 'सूचनाएं और कॉल',
      'weather_sync': 'मौसम सिंक',
      'fitness_goals': 'फिटनेस लक्ष्य और प्रोफ़ाइल',
      'music_control': 'म्यूजिक और मीडिया',
      'health_warnings': 'स्वास्थ्य चेतावनी अलर्ट',
      'display_gestures': 'डिस्प्ले और जेस्चर',
      'preferences_units': 'प्राथमिकताएं और इकाइयां',
      'language': 'भाषा',
      'apply_language_to': 'भाषा लागू करें',
      'system_diagnostics': 'सिस्टम और डायग्नोस्टिक्स',
    },
  };
}
