import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Segmented sleep stage distribution chart
class SleepStageBarChart extends StatelessWidget {
  final int deepMinutes;
  final int lightMinutes;
  final int awakeMinutes;

  const SleepStageBarChart({
    super.key,
    required this.deepMinutes,
    required this.lightMinutes,
    this.awakeMinutes = 20,
  });

  @override
  Widget build(BuildContext context) {
    final total = deepMinutes + lightMinutes + awakeMinutes;
    final displayTotal = total > 0 ? total : 420;
    final hours = displayTotal ~/ 60;
    final mins = displayTotal % 60;

    final deepRatio = displayTotal > 0 ? (deepMinutes / displayTotal).clamp(0.05, 0.9) : 0.25;
    final lightRatio = displayTotal > 0 ? (lightMinutes / displayTotal).clamp(0.05, 0.9) : 0.70;
    final awakeRatio = (1.0 - deepRatio - lightRatio).clamp(0.02, 0.2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.bedtime_rounded, color: AppTheme.sleep, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${hours}h ${mins}m',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: const Text(
                'Optimal Rest',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.sleep,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Stacked rounded progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 14,
            child: Row(
              children: [
                Expanded(
                  flex: (deepRatio * 100).round(),
                  child: Container(color: AppTheme.sleep),
                ),
                const SizedBox(width: 2),
                Expanded(
                  flex: (lightRatio * 100).round(),
                  child: Container(color: AppTheme.spo2),
                ),
                const SizedBox(width: 2),
                Expanded(
                  flex: (awakeRatio * 100).round(),
                  child: Container(color: AppTheme.warning),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        // Legend row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStageChip(
              'Deep',
              '${deepMinutes ~/ 60}h ${deepMinutes % 60}m',
              AppTheme.sleep,
            ),
            _buildStageChip(
              'Light',
              '${lightMinutes ~/ 60}h ${lightMinutes % 60}m',
              AppTheme.spo2,
            ),
            _buildStageChip(
              'Awake',
              '${awakeMinutes}m',
              AppTheme.warning,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStageChip(String label, String duration, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
        Text(
          duration,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
