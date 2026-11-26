import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/historical_health.dart';

/// Bespoke smooth cubic spline chart for Heart Rate trends
class HeartRateSplineChart extends StatelessWidget {
  final List<DailyHealthRecord> records;
  final int currentBpm;

  const HeartRateSplineChart({
    super.key,
    required this.records,
    this.currentBpm = 72,
  });

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const SizedBox(
        height: 140,
        child: Center(
          child: Text('No heart rate history recorded',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
        ),
      );
    }

    final minBpm = records.fold<int>(200, (m, r) => math.min(m, r.minHeartRate));
    final maxBpm = records.fold<int>(0, (m, r) => math.max(m, r.maxHeartRate));
    final avgBpm = (records.fold<int>(0, (s, r) => s + r.avgHeartRate) / records.length).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.favorite_rounded, color: AppTheme.heartRate, size: 20),
                const SizedBox(width: 8),
                Text(
                  '$currentBpm',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'BPM',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.heartRate,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                _buildStatPill('Min', '$minBpm'),
                const SizedBox(width: 8),
                _buildStatPill('Avg', '$avgBpm'),
                const SizedBox(width: 8),
                _buildStatPill('Max', '$maxBpm'),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 130,
          width: double.infinity,
          child: CustomPaint(
            painter: _HeartRateSplinePainter(
              records: records,
              minBpm: math.max(40, minBpm - 5),
              maxBpm: math.min(180, maxBpm + 10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}

class _HeartRateSplinePainter extends CustomPainter {
  final List<DailyHealthRecord> records;
  final int minBpm;
  final int maxBpm;

  _HeartRateSplinePainter({
    required this.records,
    required this.minBpm,
    required this.maxBpm,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (records.length < 2) return;

    final bottomPadding = 20.0;
    final chartHeight = size.height - bottomPadding;
    final range = (maxBpm - minBpm).clamp(10, 200);

    final points = <Offset>[];
    final stepX = size.width / (records.length - 1);

    for (int i = 0; i < records.length; i++) {
      final x = i * stepX;
      final ratio = ((records[i].avgHeartRate - minBpm) / range).clamp(0.05, 0.95);
      final y = chartHeight - (ratio * chartHeight);
      points.add(Offset(x, y));
    }

    // Build smooth cubic bezier path
    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final ctrl1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final ctrl2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);
      path.cubicTo(ctrl1.dx, ctrl1.dy, ctrl2.dx, ctrl2.dy, p1.dx, p1.dy);
    }

    // Draw gradient fill area
    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, chartHeight)
      ..lineTo(points.first.dx, chartHeight)
      ..close();

    final fillGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        AppTheme.heartRate.withOpacity(0.30),
        AppTheme.heartRate.withOpacity(0.02),
      ],
    );

    final fillPaint = Paint()
      ..shader = fillGradient.createShader(Rect.fromLTWH(0, 0, size.width, chartHeight))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Draw smooth line
    final linePaint = Paint()
      ..color = AppTheme.heartRate
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);

    // Draw pulse dot on the last point
    final lastPoint = points.last;
    final glowPaint = Paint()
      ..color = AppTheme.heartRate.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(lastPoint, 8, glowPaint);

    final dotPaint = Paint()
      ..color = AppTheme.heartRate
      ..style = PaintingStyle.fill;
    canvas.drawCircle(lastPoint, 4, dotPaint);

    // Draw bottom date labels
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (int i = 0; i < records.length; i++) {
      final isLast = i == records.length - 1;
      textPainter.text = TextSpan(
        text: records[i].dayAbbreviation,
        style: TextStyle(
          fontSize: 10,
          fontWeight: isLast ? FontWeight.w700 : FontWeight.w500,
          color: isLast ? AppTheme.heartRate : AppTheme.textMuted,
        ),
      );
      textPainter.layout();
      canvas.drawCircle(points[i], 2.5, Paint()..color = AppTheme.heartRate.withOpacity(0.6));
      textPainter.paint(
        canvas,
        Offset(points[i].dx - textPainter.width / 2, chartHeight + 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HeartRateSplinePainter oldDelegate) {
    return oldDelegate.records != records;
  }
}
