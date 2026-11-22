import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../models/clock_style.dart';

/// Renders a realistic DIZO Watch D frame (240x286 display with bezel) and live clock overlays
/// Supports long-press hold to select with vibration, followed by smooth dragging across the canvas
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
  bool _isSelected = false;
  Offset _lastTouchPos = Offset.zero;
  double _currentX = 60.0;
  double _currentY = 103.0;

  @override
  void initState() {
    super.initState();
    _currentX = widget.clockStyle.position.x.toDouble();
    _currentY = widget.clockStyle.position.y.toDouble();
  }

  @override
  void didUpdateWidget(WatchCanvasPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clockStyle.position != widget.clockStyle.position) {
      _currentX = widget.clockStyle.position.x.toDouble();
      _currentY = widget.clockStyle.position.y.toDouble();
      // If a preset was selected externally, deselect
      if (!widget.clockStyle.position.isCustom) {
        _isSelected = false;
      }
    }
  }

  void _onDragStart(Offset globalPos) {
    _lastTouchPos = globalPos;
  }

  void _onDragUpdate(Offset globalPos) {
    if (widget.onClockDragged == null) return;
    final delta = globalPos - _lastTouchPos;
    _lastTouchPos = globalPos;
    final dx = delta.dx / widget.scale;
    final dy = delta.dy / widget.scale;
    _currentX = (_currentX + dx).clamp(0.0, 160.0);
    _currentY = (_currentY + dy).clamp(0.0, 220.0);
    widget.onClockDragged!(_currentX.round(), _currentY.round());
  }

  void _deselect() {
    if (_isSelected) {
      HapticFeedback.lightImpact();
      setState(() => _isSelected = false);
      widget.onDragStateChanged?.call(false);
    }
  }

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
              color: _isSelected ? AppTheme.accent : const Color(0xFF323246),
              width: _isSelected ? 3.5 : 3,
            ),
            boxShadow: [
              BoxShadow(
                color: _isSelected
                    ? AppTheme.accent.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.6),
                blurRadius: _isSelected ? 30 : 24,
                spreadRadius: _isSelected ? 2 : 0,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: _isSelected ? (details) => _onDragStart(details.globalPosition) : null,
              onPanUpdate: _isSelected ? (details) => _onDragUpdate(details.globalPosition) : null,
              onPanEnd: _isSelected ? (_) => HapticFeedback.selectionClick() : null,
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

                    // Clock & Complications Overlay
                    if (widget.clockStyle.isVisible)
                      _buildClockOverlay(displayW, displayH),

                    // Floating Selection Header (Coordinates & Done Button)
                    if (_isSelected) ...[
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.open_with, size: 12, color: AppTheme.accent),
                              const SizedBox(width: 4),
                              Text(
                                '(${widget.clockStyle.position.x}, ${widget.clockStyle.position.y})',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: _deselect,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.accent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.accent.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check, size: 14, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'Done',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
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
      onLongPressStart: widget.onClockDragged != null
          ? (details) {
              HapticFeedback.heavyImpact();
              HapticFeedback.vibrate();
              setState(() {
                _isSelected = true;
                _currentX = widget.clockStyle.position.x.toDouble();
                _currentY = widget.clockStyle.position.y.toDouble();
                _onDragStart(details.globalPosition);
              });
              widget.onDragStateChanged?.call(true);
            }
          : null,
      onLongPressMoveUpdate: widget.onClockDragged != null
          ? (details) {
              if (!_isSelected) return;
              _onDragUpdate(details.globalPosition);
            }
          : null,
      onPanStart: _isSelected
          ? (details) {
              _onDragStart(details.globalPosition);
            }
          : null,
      onPanUpdate: _isSelected
          ? (details) {
              _onDragUpdate(details.globalPosition);
            }
          : null,
      onPanEnd: _isSelected
          ? (_) {
              HapticFeedback.selectionClick();
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _isSelected
              ? AppTheme.accent.withValues(alpha: 0.16)
              : Colors.transparent,
          border: Border.all(
            color: _isSelected
                ? AppTheme.accent
                : Colors.white.withValues(alpha: 0.15),
            width: _isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: _isSelected
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

    // Always use exact Positioned coordinates to ensure seamless gesture tracking
    return Positioned(
      left: widget.clockStyle.position.x.toDouble().clamp(0.0, 160.0),
      top: widget.clockStyle.position.y.toDouble().clamp(0.0, 220.0),
      child: clockContent,
    );
  }

  String _getDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[(weekday - 1) % 7];
  }
}
