import 'package:flutter/material.dart';

enum ClockSize {
  small('Small', 26, 36, 0.85),
  standard('Standard', 32, 44, 1.0),
  large('Large', 38, 50, 1.18);

  final String label;
  final double horizontalFontSize;
  final double verticalFontSize;
  final double scale;
  const ClockSize(this.label, this.horizontalFontSize, this.verticalFontSize, this.scale);

  double fontSize(bool isVertical) => isVertical ? verticalFontSize : horizontalFontSize;
}

enum ClockFontFamily {
  modern('Modern', 'Clean digital sans'),
  athletic('Athletic', 'Tall condensed'),
  block3d('Chunky 3D', 'Retro pop block'),
  casual('Casual', 'Playful rounded'),
  pixel('Arcade', '8-bit pixel matrix'),
  techno('Cyber', 'Futuristic techno'),
  minimal('Minimal', 'Sleek geometric lines'),
  neon('Neon', 'Digital glow mono');

  final String label;
  final String description;
  const ClockFontFamily(this.label, this.description);
}

enum DateStyle {
  dayNumber('THU 26', 'Day & Date'),
  slashNumeric('11/26', 'Numeric'),
  daySlash('THU, 11/26', 'Full'),
  monthDay('NOV 26', 'Month'),
  pillBadge('THU · 26', 'Pill');

  final String sample;
  final String label;
  const DateStyle(this.sample, this.label);

  String format(DateTime dt) {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    final dayName = days[(dt.weekday - 1) % 7];
    final monthName = months[(dt.month - 1) % 12];
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');

    switch (this) {
      case DateStyle.dayNumber:
        return '$dayName ${dt.day}';
      case DateStyle.slashNumeric:
        return '$mm/$dd';
      case DateStyle.daySlash:
        return '$dayName, $mm/$dd';
      case DateStyle.monthDay:
        return '$monthName ${dt.day}';
      case DateStyle.pillBadge:
        return '$dayName · ${dt.day}';
    }
  }
}

class ClockTemplateStyle {
  final String id;
  final String name;
  final String subtitle;
  final Color primaryColor;
  final Color? secondaryColor;
  final int hardwareStyleIndex;
  final bool isStacked;
  final ClockFontFamily fontFamily;
  final bool hasOutlineMinutes;
  final bool has3dShadow;

  const ClockTemplateStyle({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.primaryColor,
    this.secondaryColor,
    required this.hardwareStyleIndex,
    this.isStacked = false,
    this.fontFamily = ClockFontFamily.modern,
    this.hasOutlineMinutes = false,
    this.has3dShadow = false,
  });

  static const modern = ClockTemplateStyle(
    id: 'modern',
    name: 'Modern Clean',
    subtitle: 'ID: 2822 • Crisp White',
    primaryColor: Colors.white,
    hardwareStyleIndex: 1,
    fontFamily: ClockFontFamily.modern,
    isStacked: false,
  );

  static const athletic = ClockTemplateStyle(
    id: 'athletic_stacked',
    name: 'Athletic Dual',
    subtitle: 'ID: 2832 • Outline Accent',
    primaryColor: Colors.white,
    secondaryColor: Color(0xFFFF9100),
    hardwareStyleIndex: 4,
    fontFamily: ClockFontFamily.athletic,
    isStacked: true,
    hasOutlineMinutes: true,
  );

  static const block3d = ClockTemplateStyle(
    id: 'block_retro',
    name: 'Chunky 3D',
    subtitle: 'ID: 2809 • Retro Pop',
    primaryColor: Color(0xFFFF6D00),
    secondaryColor: Color(0xFF311B92),
    hardwareStyleIndex: 4,
    fontFamily: ClockFontFamily.block3d,
    isStacked: true,
    has3dShadow: true,
  );

  static const casual = ClockTemplateStyle(
    id: 'casual_rounded',
    name: 'Casual Doodle',
    subtitle: 'ID: 11073 • Soft Rounded',
    primaryColor: Color(0xFFEEFF41),
    hardwareStyleIndex: 4,
    fontFamily: ClockFontFamily.casual,
    isStacked: true,
  );

  static const pixel = ClockTemplateStyle(
    id: 'pixel_arcade',
    name: '8-Bit Arcade',
    subtitle: 'ID: 3872 • Pixel Matrix',
    primaryColor: Color(0xFF00E676),
    hardwareStyleIndex: 2,
    fontFamily: ClockFontFamily.pixel,
    isStacked: false,
  );

  static const techno = ClockTemplateStyle(
    id: 'cyber_techno',
    name: 'Cyber Techno',
    subtitle: 'ID: 2917 • Dual Neon',
    primaryColor: Colors.white,
    secondaryColor: Color(0xFF7C4DFF),
    hardwareStyleIndex: 2,
    fontFamily: ClockFontFamily.techno,
    isStacked: false,
  );

  static const minimal = ClockTemplateStyle(
    id: 'minimal_slim',
    name: 'Minimalist',
    subtitle: 'ID: 3175 • Sleek Elegant',
    primaryColor: Colors.white,
    hardwareStyleIndex: 1,
    fontFamily: ClockFontFamily.minimal,
    isStacked: true,
  );

  static const popShadow = ClockTemplateStyle(
    id: 'pop_shadow',
    name: 'Pop Shadow',
    subtitle: 'ID: 2810 • Purple Outline',
    primaryColor: Color(0xFFFF9800),
    secondaryColor: Color(0xFFE040FB),
    hardwareStyleIndex: 4,
    fontFamily: ClockFontFamily.block3d,
    isStacked: true,
    has3dShadow: true,
  );

  static const cyberMint = ClockTemplateStyle(
    id: 'cyber_mint',
    name: 'Emerald Mint',
    subtitle: 'Glowing Neon',
    primaryColor: Color(0xFF00E676),
    hardwareStyleIndex: 2,
    fontFamily: ClockFontFamily.neon,
    isStacked: false,
  );

  static const solarGold = ClockTemplateStyle(
    id: 'solar_gold',
    name: 'Solar Gold',
    subtitle: 'Vibrant Yellow',
    primaryColor: Color(0xFFFFEA00),
    hardwareStyleIndex: 4,
    fontFamily: ClockFontFamily.modern,
    isStacked: false,
  );

  static List<ClockTemplateStyle> get gallery => [
        modern,
        athletic,
        block3d,
        casual,
        pixel,
        techno,
        minimal,
        popShadow,
        cyberMint,
        solarGold,
      ];
}

class ClockPosition {
  final String label;
  final int x;
  final int y;
  final bool isCustom;

  const ClockPosition(this.label, this.x, this.y, {this.isCustom = false});

  // Default Horizontal Presets (120x73 on 240x286 LCD):
  static const center = ClockPosition('Center', 60, 106);
  static const top = ClockPosition('Top', 60, 8);
  static const bottom = ClockPosition('Bottom', 60, 198);
  static const left = ClockPosition('Left', 20, 106);
  static const right = ClockPosition('Right', 102, 106);

  // Vertical Presets (78x126 on 240x286 LCD):
  static const centerVertical = ClockPosition('Center', 81, 80);
  static const topVertical = ClockPosition('Top', 81, 12);
  static const bottomVertical = ClockPosition('Bottom', 81, 148);
  static const leftVertical = ClockPosition('Left', 16, 80);
  static const rightVertical = ClockPosition('Right', 146, 80);

  static List<ClockPosition> getPresets({bool isVertical = false}) {
    if (isVertical) {
      return const [
        centerVertical,
        topVertical,
        bottomVertical,
        leftVertical,
        rightVertical,
      ];
    }
    return const [
      center,
      top,
      bottom,
      left,
      right,
    ];
  }

  int getXForSize(dynamic size) => x;
  int getYForSize(dynamic size) => y;
  ClockPosition forSize(dynamic size) => this;

  ClockPosition copyWith({int? x, int? y, String? label, bool? isCustom}) {
    return ClockPosition(
      label ?? this.label,
      x ?? this.x,
      y ?? this.y,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClockPosition &&
          runtimeType == other.runtimeType &&
          label == other.label &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => label.hashCode ^ x.hashCode ^ y.hashCode;
}

class ClockStyle {
  final ClockPosition position;
  final ClockSize size;
  final ClockTemplateStyle templateStyle;
  final bool isVisible;
  final Color textColor;
  final bool isStacked;
  final bool showDate;
  final DateStyle dateStyle;
  final bool showBattery;
  final bool showSteps;
  final bool showHeartRate;

  const ClockStyle({
    this.position = ClockPosition.center,
    this.size = ClockSize.standard,
    this.templateStyle = ClockTemplateStyle.modern,
    this.isVisible = true,
    this.textColor = Colors.white,
    this.isStacked = false,
    this.showDate = true,
    this.dateStyle = DateStyle.dayNumber,
    this.showBattery = false,
    this.showSteps = false,
    this.showHeartRate = false,
  });

  bool get isVertical => isStacked;

  // Horizontal is 120x73, Vertical is 78x126 (custom vertical block allowing big font sizes)
  double get boxWidth => isVertical ? 78.0 : 120.0;
  double get boxHeight => isVertical ? 126.0 : 73.0;

  int get maxTargetX => (240.0 - boxWidth).round();
  int get maxTargetY => (286.0 - boxHeight).round();

  ClockStyle copyWith({
    ClockPosition? position,
    ClockSize? size,
    ClockTemplateStyle? templateStyle,
    bool? isVisible,
    Color? textColor,
    bool? isStacked,
    bool? showDate,
    DateStyle? dateStyle,
    bool? showBattery,
    bool? showSteps,
    bool? showHeartRate,
  }) {
    return ClockStyle(
      position: position ?? this.position,
      size: size ?? this.size,
      templateStyle: templateStyle ?? this.templateStyle,
      isVisible: isVisible ?? this.isVisible,
      textColor: textColor ?? this.textColor,
      isStacked: isStacked ?? this.isStacked,
      showDate: showDate ?? this.showDate,
      dateStyle: dateStyle ?? this.dateStyle,
      showBattery: showBattery ?? this.showBattery,
      showSteps: showSteps ?? this.showSteps,
      showHeartRate: showHeartRate ?? this.showHeartRate,
    );
  }

  Map<String, dynamic> toJson() => {
        'posLabel': position.label,
        'posX': position.x,
        'posY': position.y,
        'posCustom': position.isCustom,
        'size': size.name,
        'templateId': templateStyle.id,
        'isVisible': isVisible,
        'textColor': textColor.toARGB32(),
        'isStacked': isStacked,
        'showDate': showDate,
        'dateStyle': dateStyle.name,
        'showBattery': showBattery,
        'showSteps': showSteps,
        'showHeartRate': showHeartRate,
      };

  factory ClockStyle.fromJson(Map<String, dynamic> json) {
    final templateId = json['templateId'] as String? ?? 'modern';
    final template = ClockTemplateStyle.gallery.firstWhere(
      (t) => t.id == templateId,
      orElse: () => ClockTemplateStyle.modern,
    );
    final sizeName = json['size'] as String? ?? 'standard';
    final size = ClockSize.values.firstWhere(
      (s) => s.name == sizeName,
      orElse: () => ClockSize.standard,
    );
    final dateName = json['dateStyle'] as String? ?? 'dayNumber';
    final dateStyle = DateStyle.values.firstWhere(
      (d) => d.name == dateName,
      orElse: () => DateStyle.dayNumber,
    );

    return ClockStyle(
      position: ClockPosition(
        json['posLabel'] as String? ?? 'Center',
        json['posX'] as int? ?? 55,
        json['posY'] as int? ?? 100,
        isCustom: json['posCustom'] as bool? ?? false,
      ),
      size: size,
      templateStyle: template,
      isVisible: json['isVisible'] as bool? ?? true,
      textColor: Color(json['textColor'] as int? ?? 0xFFFFFFFF),
      isStacked: json['isStacked'] as bool? ?? false,
      showDate: json['showDate'] as bool? ?? true,
      dateStyle: dateStyle,
      showBattery: json['showBattery'] as bool? ?? false,
      showSteps: json['showSteps'] as bool? ?? false,
      showHeartRate: json['showHeartRate'] as bool? ?? false,
    );
  }
}
