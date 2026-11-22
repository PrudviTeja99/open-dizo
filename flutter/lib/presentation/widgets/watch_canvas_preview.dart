import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/clock_style.dart';

/// Renders a realistic DIZO Watch D frame (240x286 display with bezel) and live clock overlays
class WatchCanvasPreview extends StatelessWidget {
  final File? wallpaperFile;
  final ClockStyle clockStyle;
  final double scale;

  const WatchCanvasPreview({
    super.key,
    this.wallpaperFile,
    required this.clockStyle,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    const double displayW = 240.0;
    const double displayH = 286.0;

    return Center(
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: displayW + 36,
          height: displayH + 36,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF16161E),
            borderRadius: BorderRadius.circular(42),
            border: Border.all(color: const Color(0xFF323246), width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: displayW,
              height: displayH,
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Wallpaper Image Layer
                  if (wallpaperFile != null && wallpaperFile!.existsSync())
                    Image.file(
                      wallpaperFile!,
                      fit: BoxFit.cover,
                      width: displayW,
                      height: displayH,
                    )
                  else
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.image_outlined,
                          size: 48,
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                    ),

                  // Clock & Widget Complications Overlay
                  _buildClockOverlay(displayW, displayH),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClockOverlay(double width, double height) {
    Alignment alignment;
    CrossAxisAlignment crossAlign;

    switch (clockStyle.position) {
      case ClockPosition.top:
        alignment = Alignment.topCenter;
        crossAlign = CrossAxisAlignment.center;
        break;
      case ClockPosition.bottom:
        alignment = Alignment.bottomCenter;
        crossAlign = CrossAxisAlignment.center;
        break;
      case ClockPosition.left:
        alignment = Alignment.centerLeft;
        crossAlign = CrossAxisAlignment.start;
        break;
      case ClockPosition.right:
        alignment = Alignment.centerRight;
        crossAlign = CrossAxisAlignment.end;
        break;
    }

    final textColor = clockStyle.textColor;
    final now = DateTime.now();
    final hourStr = now.hour.toString().padLeft(2, '0');
    final minStr = now.minute.toString().padLeft(2, '0');
    final dayStr = _getDayName(now.weekday);
    final dateStr = '$dayStr ${now.day}';

    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: crossAlign,
          children: [
            // Time Display
            Text(
              '$hourStr:$minStr',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: textColor,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.8),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),

            // Date Complication
            if (clockStyle.showDate)
              Text(
                dateStr,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: textColor.withOpacity(0.9),
                  shadows: [
                    Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 4),
                  ],
                ),
              ),

            const SizedBox(height: 4),

            // Metrics Complications Row (Steps, Battery, HR)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (clockStyle.showSteps) ...[
                  _badge('🚶 7.2k', textColor),
                  const SizedBox(width: 6),
                ],
                if (clockStyle.showBattery) ...[
                  _badge('🔋 85%', textColor),
                  const SizedBox(width: 6),
                ],
                if (clockStyle.showHeartRate) ...[
                  _badge('❤️ 74', textColor),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  String _getDayName(int weekday) {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return days[(weekday - 1) % 7];
  }
}
