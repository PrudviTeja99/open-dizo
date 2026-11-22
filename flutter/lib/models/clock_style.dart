import 'package:flutter/material.dart';

enum ClockSize {
  small('Small', 26, 0.8),
  medium('Medium', 34, 1.0),
  large('Large', 44, 1.25);

  final String label;
  final double fontSize;
  final double scale;
  const ClockSize(this.label, this.fontSize, this.scale);
}

class ClockPosition {
  final String label;
  final int x;
  final int y;
  final bool isCustom;

  const ClockPosition(this.label, this.x, this.y, {this.isCustom = false});

  static const center = ClockPosition('Center', 60, 103);
  static const top = ClockPosition('Top', 60, 8);
  static const bottom = ClockPosition('Bottom', 60, 198);
  static const left = ClockPosition('Left', 20, 103);
  static const right = ClockPosition('Right', 102, 103);

  static List<ClockPosition> get presets => [
        center,
        top,
        bottom,
        left,
        right,
      ];

  int getXForSize(ClockSize size) {
    if (isCustom) return x;
    switch (label) {
      case 'Center':
      case 'Top':
      case 'Bottom':
        switch (size) {
          case ClockSize.small:
            return 75;
          case ClockSize.medium:
            return 60;
          case ClockSize.large:
            return 45;
        }
      case 'Left':
        switch (size) {
          case ClockSize.small:
            return 16;
          case ClockSize.medium:
            return 16;
          case ClockSize.large:
            return 12;
        }
      case 'Right':
        switch (size) {
          case ClockSize.small:
            return 134;
          case ClockSize.medium:
            return 102;
          case ClockSize.large:
            return 78;
        }
      default:
        return x;
    }
  }

  int getYForSize(ClockSize size) {
    if (isCustom) return y;
    switch (label) {
      case 'Center':
      case 'Left':
      case 'Right':
        switch (size) {
          case ClockSize.small:
            return 113;
          case ClockSize.medium:
            return 103;
          case ClockSize.large:
            return 95;
        }
      case 'Top':
        switch (size) {
          case ClockSize.small:
            return 14;
          case ClockSize.medium:
            return 8;
          case ClockSize.large:
            return 6;
        }
      case 'Bottom':
        switch (size) {
          case ClockSize.small:
            return 210;
          case ClockSize.medium:
            return 198;
          case ClockSize.large:
            return 184;
        }
      default:
        return y;
    }
  }

  ClockPosition forSize(ClockSize size) {
    if (isCustom) return this;
    return ClockPosition(label, getXForSize(size), getYForSize(size), isCustom: false);
  }

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
  final bool isVisible;
  final Color textColor;
  final bool showDate;
  final bool showBattery;
  final bool showSteps;
  final bool showHeartRate;

  const ClockStyle({
    this.position = ClockPosition.center,
    this.size = ClockSize.medium,
    this.isVisible = true,
    this.textColor = Colors.white,
    this.showDate = true,
    this.showBattery = true,
    this.showSteps = true,
    this.showHeartRate = true,
  });

  ClockStyle copyWith({
    ClockPosition? position,
    ClockSize? size,
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
      isVisible: isVisible ?? this.isVisible,
      textColor: textColor ?? this.textColor,
      showDate: showDate ?? this.showDate,
      showBattery: showBattery ?? this.showBattery,
      showSteps: showSteps ?? this.showSteps,
      showHeartRate: showHeartRate ?? this.showHeartRate,
    );
  }
}
