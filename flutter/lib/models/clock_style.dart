import 'package:flutter/material.dart';

enum ClockPosition {
  top('Top', 60, 8),
  bottom('Bottom', 60, 198),
  left('Left', 20, 103),
  right('Right', 102, 103);

  final String label;
  final int x;
  final int y;
  const ClockPosition(this.label, this.x, this.y);
}

class ClockStyle {
  final ClockPosition position;
  final Color textColor;
  final bool showDate;
  final bool showBattery;
  final bool showSteps;
  final bool showHeartRate;

  const ClockStyle({
    this.position = ClockPosition.bottom,
    this.textColor = Colors.white,
    this.showDate = true,
    this.showBattery = true,
    this.showSteps = true,
    this.showHeartRate = true,
  });

  ClockStyle copyWith({
    ClockPosition? position,
    Color? textColor,
    bool? showDate,
    bool? showBattery,
    bool? showSteps,
    bool? showHeartRate,
  }) {
    return ClockStyle(
      position: position ?? this.position,
      textColor: textColor ?? this.textColor,
      showDate: showDate ?? this.showDate,
      showBattery: showBattery ?? this.showBattery,
      showSteps: showSteps ?? this.showSteps,
      showHeartRate: showHeartRate ?? this.showHeartRate,
    );
  }
}
