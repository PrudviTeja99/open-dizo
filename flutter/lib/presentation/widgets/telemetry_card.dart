import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/watch_telemetry.dart';

class TelemetryCard extends StatelessWidget {
  final WatchTelemetry telemetry;

  const TelemetryCard({super.key, required this.telemetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📊  WATCH DATA',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.5,
                color: Colors.grey[500],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _dataCell('${telemetry.steps ?? "--"}', 'Steps')),
                const SizedBox(width: 8),
                Expanded(child: _dataCell('${telemetry.heartRate ?? "--"}', 'Heart Rate')),
                const SizedBox(width: 8),
                Expanded(child: _dataCell('${telemetry.battery ?? "--"}', 'Battery %')),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _dataCell('${telemetry.calories ?? "--"}', 'Calories')),
                const SizedBox(width: 8),
                Expanded(child: _dataCell('${telemetry.spo2 ?? "--"}', 'SpO2 %')),
                const SizedBox(width: 8),
                Expanded(
                  child: _dataCell(
                    telemetry.distanceMeters != null
                        ? telemetry.distanceMeters!.toStringAsFixed(1)
                        : '--',
                    'Distance (m)',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dataCell(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
