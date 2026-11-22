import 'dart:io';
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../models/clock_style.dart';

/// Renders a pixel-accurate DIZO Watch D frame (240x286 display with bezel)
/// Displays the digital clock overlay with exact 120x73 (horizontal) or 78x126 (vertical) dimensions.
/// Supports long-press hold to select with vibration, followed by free dragging across the canvas.
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
  double _currentY = 106.0;

  @override
  void initState() {
    super.initState();
    _currentX = widget.clockStyle.position.x.toDouble();
    _currentY = widget.clockStyle.position.y.toDouble();
  }

  @override
  void didUpdateWidget(WatchCanvasPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clockStyle.position != widget.clockStyle.position ||
        oldWidget.clockStyle.isVertical != widget.clockStyle.isVertical) {
      final maxDragX = (240.0 - widget.clockStyle.boxWidth);
      final maxDragY = (286.0 - widget.clockStyle.boxHeight);
      _currentX = widget.clockStyle.position.x.toDouble().clamp(0.0, maxDragX);
      _currentY = widget.clockStyle.position.y.toDouble().clamp(0.0, maxDragY);
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
    final maxDragX = (240.0 - widget.clockStyle.boxWidth);
    final maxDragY = (286.0 - widget.clockStyle.boxHeight);
    _currentX = (_currentX + dx).clamp(0.0, maxDragX);
    _currentY = (_currentY + dy).clamp(0.0, maxDragY);
    widget.onClockDragged!(_currentX.round(), _currentY.round());
  }

  void _deselect() {
    if (_isSelected) {
      HapticFeedback.lightImpact();
      setState(() => _isSelected = false);
      widget.onDragStateChanged?.call(false);
    }
  }

  TextStyle _getClockTextStyle({
    required double fontSize,
    required Color color,
    bool isOutline = false,
    bool is3d = false,
    Color? shadowColor,
  }) {
    final fontFamily = widget.clockStyle.templateStyle.fontFamily;
    TextStyle base;

    switch (fontFamily) {
      case ClockFontFamily.athletic:
        base = GoogleFonts.teko(
          fontSize: fontSize * 1.15,
          fontWeight: FontWeight.w700,
          height: 0.88,
        );
        break;
      case ClockFontFamily.block3d:
        base = GoogleFonts.bungee(
          fontSize: fontSize * 0.82,
          fontWeight: FontWeight.w900,
          height: 0.95,
        );
        break;
      case ClockFontFamily.casual:
        base = GoogleFonts.fredoka(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          height: 0.95,
        );
        break;
      case ClockFontFamily.pixel:
        base = GoogleFonts.pressStart2p(
          fontSize: fontSize * 0.52,
          fontWeight: FontWeight.w400,
          height: 1.0,
        );
        break;
      case ClockFontFamily.techno:
        base = GoogleFonts.orbitron(
          fontSize: fontSize * 0.88,
          fontWeight: FontWeight.w900,
          height: 0.95,
        );
        break;
      case ClockFontFamily.minimal:
        base = GoogleFonts.outfit(
          fontSize: fontSize,
          fontWeight: FontWeight.w400,
          height: 0.95,
          letterSpacing: 1.0,
        );
        break;
      case ClockFontFamily.neon:
        base = GoogleFonts.shareTechMono(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          height: 0.95,
        );
        break;
      case ClockFontFamily.modern:
      default:
        base = GoogleFonts.montserrat(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          height: 0.95,
        );
        break;
    }

    List<Shadow> shadows = [];
    if (is3d) {
      final sc = shadowColor ?? const Color(0xFF311B92);
      shadows = [
        Shadow(offset: const Offset(2.0, 2.0), color: sc),
        const Shadow(offset: Offset(3.5, 3.5), color: Colors.black),
      ];
    } else {
      shadows = [
        const Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1.5)),
      ];
    }

    if (isOutline) {
      return base.copyWith(
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = color,
        shadows: shadows,
      );
    }

    return base.copyWith(
      color: color,
      shadows: shadows,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
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
    final style = widget.clockStyle.templateStyle;
    final primaryColor = widget.clockStyle.textColor;
    final secondaryColor = style.secondaryColor ?? primaryColor;
    final isVertical = widget.clockStyle.isVertical;
    final fontSize = widget.clockStyle.size.fontSize(isVertical);

    final bool minuteOutline = style.hasOutlineMinutes;
    final bool use3d = style.has3dShadow;
    final Color minuteColor = (minuteOutline || style.secondaryColor != null)
        ? secondaryColor
        : primaryColor;

    final now = DateTime.now();
    final hourStr = now.hour.toString().padLeft(2, '0');
    final minStr = now.minute.toString().padLeft(2, '0');
    final dayStr = _getDayName(now.weekday);
    final dateStr = '$dayStr ${now.day}';

    final boxW = widget.clockStyle.boxWidth;
    final boxH = widget.clockStyle.boxHeight;

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
        width: boxW,
        height: boxH,
        decoration: BoxDecoration(
          color: _isSelected
              ? AppTheme.accent.withValues(alpha: 0.16)
              : Colors.transparent,
          border: Border.all(
            color: _isSelected
                ? AppTheme.accent
                : Colors.white.withValues(alpha: 0.22),
            width: _isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
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
        child: ClipRect(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (isVertical) ...[
                // Vertical Stacked Clock: Hours over Minutes in vertical box (78x126)
                Text(
                  hourStr,
                  style: _getClockTextStyle(
                    fontSize: fontSize,
                    color: primaryColor,
                    is3d: use3d,
                    shadowColor: secondaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                if (minuteOutline)
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        minStr,
                        style: _getClockTextStyle(
                          fontSize: fontSize,
                          color: Colors.black.withValues(alpha: 0.55),
                        ),
                      ),
                      Text(
                        minStr,
                        style: _getClockTextStyle(
                          fontSize: fontSize,
                          color: minuteColor,
                          isOutline: true,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    minStr,
                    style: _getClockTextStyle(
                      fontSize: fontSize,
                      color: minuteColor,
                      is3d: use3d,
                      shadowColor: secondaryColor,
                    ),
                  ),
                if (widget.clockStyle.showDate) ...[
                  const SizedBox(height: 4),
                  Text(
                    dateStr.toUpperCase(),
                    style: TextStyle(
                      fontSize: (10.5 * widget.clockStyle.size.scale).clamp(9.0, 13.0),
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                      letterSpacing: 0.8,
                      color: primaryColor.withValues(alpha: 0.95),
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 3, offset: Offset(0, 1)),
                      ],
                    ),
                  ),
                ],
              ] else ...[
                // Horizontal Clock in standard box (120x73)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      hourStr,
                      style: _getClockTextStyle(
                        fontSize: fontSize,
                        color: primaryColor,
                        is3d: use3d,
                        shadowColor: secondaryColor,
                      ),
                    ),
                    Text(
                      ':',
                      style: _getClockTextStyle(
                        fontSize: fontSize,
                        color: primaryColor,
                        is3d: use3d,
                        shadowColor: secondaryColor,
                      ),
                    ),
                    if (minuteOutline)
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            minStr,
                            style: _getClockTextStyle(
                              fontSize: fontSize,
                              color: Colors.black.withValues(alpha: 0.55),
                            ),
                          ),
                          Text(
                            minStr,
                            style: _getClockTextStyle(
                              fontSize: fontSize,
                              color: minuteColor,
                              isOutline: true,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        minStr,
                        style: _getClockTextStyle(
                          fontSize: fontSize,
                          color: minuteColor,
                          is3d: use3d,
                          shadowColor: secondaryColor,
                        ),
                      ),
                  ],
                ),
                if (widget.clockStyle.showDate) ...[
                  const SizedBox(height: 3),
                  Text(
                    dateStr.toUpperCase(),
                    style: TextStyle(
                      fontSize: (12.5 * widget.clockStyle.size.scale).clamp(10.0, 15.0),
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                      letterSpacing: 1.0,
                      color: primaryColor.withValues(alpha: 0.95),
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 3, offset: Offset(0, 1)),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );

    final double maxDragX = (240.0 - boxW);
    final double maxDragY = (286.0 - boxH);

    // Exact 1:1 pixel coordinate placement matching watch LCD display
    final double leftPos = (_isSelected
        ? _currentX
        : widget.clockStyle.position.x.toDouble()).clamp(0.0, maxDragX);
    final double topPos = (_isSelected
        ? _currentY
        : widget.clockStyle.position.y.toDouble()).clamp(0.0, maxDragY);

    return Positioned(
      key: const ValueKey('watch_clock_widget'),
      left: leftPos,
      top: topPos,
      width: boxW,
      height: boxH,
      child: clockContent,
    );
  }

  String _getDayName(int weekday) {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return days[(weekday - 1) % 7];
  }
}
