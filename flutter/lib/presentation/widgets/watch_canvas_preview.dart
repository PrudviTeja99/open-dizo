import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/clock_style.dart';

/// Renders a realistic DIZO Watch D frame (240x286 display with bezel) and live clock overlays
class WatchCanvasPreview extends StatelessWidget {
  final File? wallpaperFile;
  final ClockStyle clockStyle;
  final double scale;
  final void Function(int newX, int newY)? onClockDragged;

  const WatchCanvasPreview({
    super.key,
    this.wallpaperFile,
    required this.clockStyle,
    this.scale = 1.0,
    this.onClockDragged,
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
                color: Colors.black.withValues(alpha: 0.6),
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
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    ),

                  // Clock & Complications Overlay
                  if (clockStyle.isVisible)
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
    final textColor = clockStyle.textColor;
    final now = DateTime.now();
    final hourStr = now.hour.toString().padLeft(2, '0');
    final minStr = now.minute.toString().padLeft(2, '0');
    final dayStr = _getDayName(now.weekday);
    final dateStr = '$dayStr ${now.day}';

    final clockContent = GestureDetector(
      onPanUpdate: onClockDragged != null
          ? (details) {
              final newX = (clockStyle.position.x + details.delta.dx.round()).clamp(10, 150);
              final newY = (clockStyle.position.y + details.delta.dy.round()).clamp(8, 210);
              onClockDragged!(newX, newY);
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: onClockDragged != null
            ? BoxDecoration(
                border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
                borderRadius: BorderRadius.circular(10),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: clockStyle.position.label == 'Left'
              ? CrossAxisAlignment.start
              : (clockStyle.position.label == 'Right'
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.center),
          children: [
            // Time Display with custom size
            Text(
              '$hourStr:$minStr',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: clockStyle.size.fontSize,
                fontWeight: FontWeight.w900,
                color: textColor,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.8),
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
                  fontSize: (clockStyle.size.fontSize * 0.35).clamp(10.0, 16.0),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: textColor.withValues(alpha: 0.9),
                  shadows: [
                    Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 4),
                  ],
                ),
              ),

            const SizedBox(height: 3),

            // Health Icons Row
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (clockStyle.showBattery) ...[
                  Icon(Icons.battery_std, size: 12, color: textColor.withValues(alpha: 0.8)),
                  const SizedBox(width: 4),
                ],
                if (clockStyle.showSteps) ...[
                  Icon(Icons.directions_walk, size: 12, color: textColor.withValues(alpha: 0.8)),
                  const SizedBox(width: 4),
                ],
                if (clockStyle.showHeartRate) ...[
                  Icon(Icons.favorite, size: 12, color: Colors.redAccent.withValues(alpha: 0.8)),
                ],
              ],
            ),
          ],
        ),
      ),
    );

    // If Custom Position, use Positioned coordinates
    if (clockStyle.position.isCustom) {
      return Positioned(
        left: clockStyle.position.x.toDouble().clamp(0.0, 160.0),
        top: clockStyle.position.y.toDouble().clamp(0.0, 220.0),
        child: clockContent,
      );
    }

    // Otherwise align by Preset
    Alignment alignment;
    switch (clockStyle.position.label) {
      case 'Center':
        alignment = Alignment.center;
        break;
      case 'Top':
        alignment = Alignment.topCenter;
        break;
      case 'Bottom':
        alignment = Alignment.bottomCenter;
        break;
      case 'Left':
        alignment = Alignment.centerLeft;
        break;
      case 'Right':
        alignment = Alignment.centerRight;
        break;
      default:
        alignment = Alignment.center;
    }

    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: clockContent,
      ),
    );
  }

  String _getDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[(weekday - 1) % 7];
  }
}
