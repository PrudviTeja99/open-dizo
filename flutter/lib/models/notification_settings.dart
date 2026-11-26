import 'dart:convert';

/// Settings controlling which incoming notifications and phone calls
/// are pushed to the DIZO Watch D over BLE.
/// Conforms to official companion app specification (Cmd 0x02, Key 0x12)
class NotificationSettings {
  final bool masterEnabled;
  final bool incomingCalls;
  final bool sms;
  final bool whatsapp;
  final bool telegram;
  final bool email;
  final bool instagram;
  final bool twitter;
  final bool others;

  const NotificationSettings({
    this.masterEnabled = true,
    this.incomingCalls = true,
    this.sms = true,
    this.whatsapp = true,
    this.telegram = true,
    this.email = true,
    this.instagram = false,
    this.twitter = false,
    this.others = true,
  });

  /// Converts notification preferences to a 4-byte (32-bit) HTSmart config bitmask
  List<int> toConfigBytes() {
    if (!masterEnabled) {
      return [0x00, 0x00, 0x00, 0x00];
    }

    int mask = 0;
    if (incomingCalls) mask |= (1 << 0); // FLAG_TELEPHONE
    if (sms) mask |= (1 << 1); // FLAG_SMS
    if (twitter) mask |= (1 << 5); // FLAG_TWITTER
    if (instagram) mask |= (1 << 7); // FLAG_INSTAGRAM
    if (whatsapp) mask |= (1 << 9); // FLAG_WHATSAPP
    if (email) mask |= (1 << 14); // FLAG_EMAIL
    if (telegram) mask |= (1 << 15); // FLAG_TELEGRAM
    if (others) mask |= (1 << 31); // FLAG_OTHERS_APP

    return [
      mask & 0xFF,
      (mask >> 8) & 0xFF,
      (mask >> 16) & 0xFF,
      (mask >> 24) & 0xFF,
    ];
  }

  factory NotificationSettings.fromConfigBytes(List<int> bytes) {
    if (bytes.length < 4) return const NotificationSettings();
    final mask = (bytes[0] & 0xFF) |
        ((bytes[1] & 0xFF) << 8) |
        ((bytes[2] & 0xFF) << 16) |
        ((bytes[3] & 0xFF) << 24);

    return NotificationSettings(
      masterEnabled: mask != 0,
      incomingCalls: (mask & (1 << 0)) != 0,
      sms: (mask & (1 << 1)) != 0,
      twitter: (mask & (1 << 5)) != 0,
      instagram: (mask & (1 << 7)) != 0,
      whatsapp: (mask & (1 << 9)) != 0,
      email: (mask & (1 << 14)) != 0,
      telegram: (mask & (1 << 15)) != 0,
      others: (mask & (1 << 31)) != 0,
    );
  }

  NotificationSettings copyWith({
    bool? masterEnabled,
    bool? incomingCalls,
    bool? sms,
    bool? whatsapp,
    bool? telegram,
    bool? email,
    bool? instagram,
    bool? twitter,
    bool? others,
  }) {
    return NotificationSettings(
      masterEnabled: masterEnabled ?? this.masterEnabled,
      incomingCalls: incomingCalls ?? this.incomingCalls,
      sms: sms ?? this.sms,
      whatsapp: whatsapp ?? this.whatsapp,
      telegram: telegram ?? this.telegram,
      email: email ?? this.email,
      instagram: instagram ?? this.instagram,
      twitter: twitter ?? this.twitter,
      others: others ?? this.others,
    );
  }

  Map<String, dynamic> toJson() => {
        'masterEnabled': masterEnabled,
        'incomingCalls': incomingCalls,
        'sms': sms,
        'whatsapp': whatsapp,
        'telegram': telegram,
        'email': email,
        'instagram': instagram,
        'twitter': twitter,
        'others': others,
      };

  factory NotificationSettings.fromJson(Map<String, dynamic> json) =>
      NotificationSettings(
        masterEnabled: json['masterEnabled'] as bool? ?? true,
        incomingCalls: json['incomingCalls'] as bool? ?? true,
        sms: json['sms'] as bool? ?? true,
        whatsapp: json['whatsapp'] as bool? ?? true,
        telegram: json['telegram'] as bool? ?? true,
        email: json['email'] as bool? ?? true,
        instagram: json['instagram'] as bool? ?? false,
        twitter: json['twitter'] as bool? ?? false,
        others: json['others'] as bool? ?? true,
      );

  String encode() => jsonEncode(toJson());

  static NotificationSettings decode(String raw) {
    try {
      return NotificationSettings.fromJson(jsonDecode(raw));
    } catch (_) {
      return const NotificationSettings();
    }
  }
}
