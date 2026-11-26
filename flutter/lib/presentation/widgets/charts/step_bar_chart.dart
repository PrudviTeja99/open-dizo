import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/historical_health.dart';

/// Bespoke 7-day interactive step bar chart with goal indicator line
class StepBarChart extends StatefulWidget {
  final List<DailyHealthRecord> records;
  final int goalSteps;

  const StepBarChart({
    super.key,
    required this.records,
    this.goalSteps = 10000,
  });

  @override
  State<StepBarChart> createState() => _StepBarChartState();
}

class _StepBarChartState extends State<StepBarChart> {
  int? _selectedIdx;

  @override
  Widget build(BuildContext context) {
    if (widget.records.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(
          child: Text('No historical step records',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
        ),
      );
    }

    final maxVal = widget.records.fold<int>(
      widget.goalSteps,
      (prev, el) => math.max(prev, el.steps),
    );
    final chartCeiling = (maxVal * 1.15).ceil();

    final selectedRecord = _selectedIdx != null &&
            _selectedIdx! >= 0 &&
            _selectedIdx! < widget.records.length
        ? widget.records[_selectedIdx!]
        : widget.records.last;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${selectedRecord.steps} steps',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  '${selectedRecord.formattedDate} · ${(selectedRecord.distanceKm).toStringAsFixed(1)} km · ${selectedRecord.caloriesKcal} kcal',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppTheme.steps,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Goal: ${(widget.goalSteps / 1000).toStringAsFixed(0)}k',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 140,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / widget.records.length;
              return GestureDetector(
                onTapDown: (details) {
                  final idx = (details.localPosition.dx / itemWidth).floor();
                  if (idx >= 0 && idx < widget.records.length) {
                    setState(() => _selectedIdx = idx);
                  }
                },
                child: CustomPaint(
                  size: Size(constraints.maxWidth, 140),
                  painter: _StepBarPainter(
                    records: widget.records,
                    goalSteps: widget.goalSteps,
                    chartCeiling: chartCeiling,
                    selectedIndex: _selectedIdx ?? (widget.records.length - 1),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StepBarPainter extends CustomPainter {
  final List<DailyHealthRecord> records;
  final int goalSteps;
  final int chartCeiling;
  final int selectedIndex;

  _StepBarPainter({
    required this.records,
    required this.goalSteps,
    required this.chartCeiling,
    required this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final count = records.length;
    if (count == 0) return;

    final bottomPadding = 24.0;
    final chartHeight = size.height - bottomPadding;
    final itemSlotWidth = size.width / count;
    final barWidth = math.min(itemSlotWidth * 0.45, 18.0);

    // 1. Draw subtle goal horizontal dashed line
    final goalY = chartHeight - (goalSteps / chartCeiling * chartHeight);
    final goalPaint = Paint()
      ..color = AppTheme.textMuted.withOpacity(0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    double startX = 0;
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, goalY),
        Offset(math.min(startX + dashWidth, size.width), goalY),
        goalPaint,
      );
      startX += dashWidth + dashSpace;
    }

    // 2. Draw bars
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (int i = 0; i < count; i++) {
      final record = records[i];
      final isSelected = (i == selectedIndex);
      final centerX = (i * itemSlotWidth) + (itemSlotWidth / 2);

      final barRatio = (record.steps / chartCeiling).clamp(0.02, 1.0);
      final barHeight = barRatio * chartHeight;
      final topY = chartHeight - barHeight;

      final rect = Rect.fromCenter(
        center: Offset(centerX, topY + barHeight / 2),
        width: barWidth,
        height: barHeight,
      );

      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));

      // Bar fill gradient
      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isSelected
            ? [AppTheme.steps, AppTheme.steps.withOpacity(0.6)]
            : [
                AppTheme.surfaceElevated,
                AppTheme.surfaceLight,
              ],
      );

      final barPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(rrect, barPaint);

      // Highlight stroke if selected
      if (isSelected) {
        final strokePaint = Paint()
          ..color = AppTheme.steps
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawRRect(rrect, strokePaint);
      }

      // Day label below bar
      textPainter.text = TextSpan(
        text: record.dayAbbreviation,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? AppTheme.steps : AppTheme.textMuted,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(centerX - textPainter.width / 2, chartHeight + 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StepBarPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.records != records;
  }
}
