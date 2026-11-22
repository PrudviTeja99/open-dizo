import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../models/clock_style.dart';

/// Renders a realistic DIZO Watch D frame (240x286 display with bezel) and live clock overlays
/// Supports long-press hold to activate drag mode with vibration feedback and scroll isolation
class WatchCanvasPreview extends StatefulWidget {
  final File? wallpaperFile;
  final ClockStyle clockStyle;
  final double scale;
  final void Function(int newX, int newY)? onClockDragged;
  final void Function(bool isDragging)? onDragStateChanged;

  const WatchCanvasPreview({
    super.key,
    this.wallpaperFile,
    required this.clockStyle,
    this.scale = 1.0,
    this.onClockDragged,
    this.onDragStateChanged,
  });

  @override
  State<WatchCanvasPreview> createState() => _WatchCanvasPreviewState();
}

class _WatchCanvasPreviewState extends State<WatchCanvasPreview> {
  bool _isDragging = false;
  int _dragStartX = 0;
  int _dragStartY = 0;

  @override
  Widget build(BuildContext context) {
    const double displayW = 240.0;
    const double displayH = 286.0;

    return Center(
      child: Transform.scale(
        scale: widget.scale,
        child: Container(
          width: displayW + 36,
          height: displayH + 36,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF16161E),
            borderRadius: BorderRadius.circular(42),
            border: Border.all(
              color: _isDragging ? AppTheme.accent : const Color(0xFF323246),
              width: _isDragging ? 3.5 : 3,
            ),
            boxShadow: [
              BoxShadow(
                color: _isDragging
                    ? AppTheme.accent.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.6),
                blurRadius: _isDragging ? 30 : 24,
                spreadRadius: _isDragging ? 2 : 0,
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
                  if (widget.wallpaperFile != null && widget.wallpaperFile!.existsSync())
                    Image.file(
                      widget.wallpaperFile!,
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

                  // Floating Moving Badge indicator when dragging
                  if (_isDragging)
                    Positioned(
                      top: 10,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.accent, width: 1.2),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.open_with, size: 12, color: AppTheme.accent),
                              SizedBox(width: 4),
                              Text(
                                'Moving Clock',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Clock & Complications Overlay
                  if (widget.clockStyle.isVisible)
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
    final textColor = widget.clockStyle.textColor;
    final now = DateTime.now();
    final hourStr = now.hour.toString().padLeft(2, '0');
    final minStr = now.minute.toString().padLeft(2, '0');
    final dayStr = _getDayName(now.weekday);
    final dateStr = '$dayStr ${now.day}';

    final clockContent = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (widget.onClockDragged != null) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('💡 Hold clock for a moment to vibrate, then drag anywhere.'),
              duration: Duration(milliseconds: 1800),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      onLongPressStart: widget.onClockDragged != null
          ? (details) {
              HapticFeedback.heavyImpact();
              HapticFeedback.vibrate();
              setState(() {
                _isDragging = true;
                _dragStartX = widget.clockStyle.position.x;
                _dragStartY = widget.clockStyle.position.y;
              });
              widget.onDragStateChanged?.call(true);
            }
          : null,
      onLongPressMoveUpdate: widget.onClockDragged != null
          ? (details) {
              if (!_isDragging) return;
              final double dx = details.offsetFromOrigin.dx / widget.scale;
              final double dy = details.offsetFromOrigin.dy / widget.scale;
              final int newX = (_dragStartX + dx.round()).clamp(10, 150);
              final int newY = (_dragStartY + dy.round()).clamp(8, 210);
              widget.onClockDragged!(newX, newY);
            }
          : null,
      onLongPressEnd: widget.onClockDragged != null
          ? (details) {
              if (_isDragging) {
                HapticFeedback.mediumImpact();
                setState(() {
                  _isDragging = false;
                });
                widget.onDragStateChanged?.call(false);
              }
            }
          : null,
      onLongPressCancel: widget.onClockDragged != null
          ? () {
              if (_isDragging) {
                setState(() {
                  _isDragging = false;
                });
                widget.onDragStateChanged?.call(false);
              }
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _isDragging
              ? AppTheme.accent.withValues(alpha: 0.18)
              : Colors.transparent,
          border: Border.all(
            color: _isDragging
                ? AppTheme.accent
                : Colors.white.withValues(alpha: 0.15),
            width: _isDragging ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: _isDragging
              ? [
                  BoxShadow(
                    color: AppTheme.accent.withValues(alpha: 0.5),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: widget.clockStyle.position.label == 'Left'
              ? CrossAxisAlignment.start
              : (widget.clockStyle.position.label == 'Right'
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.center),
          children: [
            // Time Display with custom size
            Text(
              '$hourStr:$minStr',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: widget.clockStyle.size.fontSize,
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
            if (widget.clockStyle.showDate)
              Text(
                dateStr,
                style: TextStyle(
                  fontSize: (widget.clockStyle.size.fontSize * 0.35).clamp(10.0, 16.0),
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
                if (widget.clockStyle.showBattery) ...[
                  Icon(Icons.battery_std, size: 12, color: textColor.withValues(alpha: 0.8)),
                  const SizedBox(width: 4),
                ],
                if (widget.clockStyle.showSteps) ...[
                  Icon(Icons.directions_walk, size: 12, color: textColor.withValues(alpha: 0.8)),
                  const SizedBox(width: 4),
                ],
                if (widget.clockStyle.showHeartRate) ...[
                  Icon(Icons.favorite, size: 12, color: Colors.redAccent.withValues(alpha: 0.8)),
                ],
              ],
            ),
          ],
        ),
      ),
    );

    // If Custom Position or Dragging, use exact Positioned coordinates
    if (widget.clockStyle.position.isCustom || _isDragging) {
      return Positioned(
        left: widget.clockStyle.position.x.toDouble().clamp(0.0, 160.0),
        top: widget.clockStyle.position.y.toDouble().clamp(0.0, 220.0),
        child: clockContent,
      );
    }

    // Otherwise align by Preset
    Alignment alignment;
    switch (widget.clockStyle.position.label) {
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
