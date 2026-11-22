import 'package:flutter/material.dart';

enum ClockSize {
  small('Small', 28, 0.85),
  standard('Standard', 34, 1.0),
  large('Large', 40, 1.15);

  final String label;
  final double fontSize;
  final double scale;
  const ClockSize(this.label, this.fontSize, this.scale);
}

class ClockTemplateStyle {
  final String id;
  final String name;
  final String subtitle;
  final Color primaryColor;
  final int hardwareStyleIndex;
  final bool isStacked;

  const ClockTemplateStyle({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.primaryColor,
    required this.hardwareStyleIndex,
    this.isStacked = false,
  });

  static const modern = ClockTemplateStyle(
    id: 'modern',
    name: 'Modern Digital',
    subtitle: 'Crisp White',
    primaryColor: Colors.white,
    hardwareStyleIndex: 1,
  );

  static const cyber = ClockTemplateStyle(
    id: 'cyber',
    name: 'Cyber Neon',
    subtitle: 'Emerald Mint',
    primaryColor: Color(0xFF00E676),
    hardwareStyleIndex: 2,
  );

  static const solar = ClockTemplateStyle(
    id: 'solar',
    name: 'Solar Gold',
    subtitle: 'Vibrant Yellow',
    primaryColor: Color(0xFFFFEA00),
    hardwareStyleIndex: 4,
  );

  static const stealth = ClockTemplateStyle(
    id: 'stealth',
    name: 'Stealth Slate',
    subtitle: 'Charcoal Grey',
    primaryColor: Color(0xFFB0BEC5),
    hardwareStyleIndex: 3,
  );

  static const cyan = ClockTemplateStyle(
    id: 'cyan',
    name: 'Electric Cyan',
    subtitle: 'Cyber Blue',
    primaryColor: Color(0xFF00E5FF),
    hardwareStyleIndex: 2,
  );

  static const stacked = ClockTemplateStyle(
    id: 'stacked',
    name: 'Stacked Digital',
    subtitle: 'Hour on Minute',
    primaryColor: Colors.white,
    hardwareStyleIndex: 1,
    isStacked: true,
  );

  static List<ClockTemplateStyle> get gallery => [
        modern,
        cyber,
        solar,
        stealth,
        cyan,
        stacked,
      ];
}

class ClockPosition {
  final String label;
  final int x;
  final int y;
  final bool isCustom;

  const ClockPosition(this.label, this.x, this.y, {this.isCustom = false});

  // DIZO Watch D Hardware presets (120x73 digital widget on 240x286 LCD):
  // Center: x = (240 - 120) / 2 = 60, y = (286 - 73) / 2 = 106.5 -> 106
  static const center = ClockPosition('Center', 60, 106);
  // Top: hardware preset (x: 60, y: 8)
  static const top = ClockPosition('Top', 60, 8);
  // Bottom: hardware preset (x: 60, y: 198)
  static const bottom = ClockPosition('Bottom', 60, 198);
  // Left: hardware preset (x: 20, y: 106)
  static const left = ClockPosition('Left', 20, 106);
  // Right: hardware preset (x: 102, y: 106)
  static const right = ClockPosition('Right', 102, 106);

  static List<ClockPosition> get presets => [
        center,
        top,
        bottom,
        left,
        right,
      ];

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
  final bool showDate;
  final bool showBattery;
  final bool showSteps;
  final bool showHeartRate;

  const ClockStyle({
    this.position = ClockPosition.center,
    this.size = ClockSize.standard,
    this.templateStyle = ClockTemplateStyle.modern,
    this.isVisible = true,
    this.textColor = Colors.white,
    this.showDate = true,
    this.showBattery = false,
    this.showSteps = false,
    this.showHeartRate = false,
  });

  ClockStyle copyWith({
    ClockPosition? position,
    ClockSize? size,
    ClockTemplateStyle? templateStyle,
    bool? isVisible,
    Color? textColor,
    bool? showDate,
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
      showDate: showDate ?? this.showDate,
      showBattery: showBattery ?? this.showBattery,
      showSteps: showSteps ?? this.showSteps,
      showHeartRate: showHeartRate ?? this.showHeartRate,
    );
  }
}
