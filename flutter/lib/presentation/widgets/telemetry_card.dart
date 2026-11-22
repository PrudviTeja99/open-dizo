import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/watch_telemetry.dart';
import '../../services/ble_service.dart';

class TelemetryCard extends StatelessWidget {
  final WatchTelemetry telemetry;
  final bool isConnected;
  final VoidCallback? onRefresh;
  final bool isSyncing;
  final BleService? bleService;

  const TelemetryCard({
    super.key,
    required this.telemetry,
    this.isConnected = true,
    this.onRefresh,
    this.isSyncing = false,
    this.bleService,
  });

  @override
  Widget build(BuildContext context) {
    final steps = telemetry.steps ?? 0;
    const goalSteps = 10000;
    final progress = (steps / goalSteps).clamp(0.0, 1.0);
    final distanceKm = telemetry.distanceKmFormatted;
    final calories = telemetry.caloriesKcal;

    final lastSyncStr = telemetry.lastSyncTime != null
        ? DateFormat('hh:mm a').format(telemetry.lastSyncTime!)
        : 'Auto-syncing';

    final isMeasuring = bleService?.isMeasuringHealth ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header with Auto-sync indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.fitness_center, size: 16, color: AppTheme.accent),
                const SizedBox(width: 6),
                Text(
                  'HEALTH & ACTIVITY',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
            Row(
              children: [
                if (isSyncing)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.accent),
                  )
                else
                  const Icon(Icons.sync_alt, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  isSyncing ? 'Syncing...' : 'Updated $lastSyncStr',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 1. Hero Activity Card (Steps, Goal Progress, Distance, Calories)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E1B4B), Color(0xFF18182B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF3730A3).withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3730A3).withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.directions_walk, color: Color(0xFF818CF8), size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Daily Steps',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white70),
                      ),
                    ],
                  ),
                  Text(
                    'Goal: ${NumberFormat('#,###').format(goalSteps)}',
                    style: TextStyle(fontSize: 12, color: Colors.indigo[200]),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    NumberFormat('#,###').format(steps),
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'steps',
                    style: TextStyle(fontSize: 15, color: Colors.grey[400], fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF818CF8)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                ),
              ),
              const SizedBox(height: 18),
              // Secondary Activity Metrics (Calories & Distance)
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.local_fire_department, color: Colors.deepOrangeAccent, size: 20),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$calories',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              Text('Calories (kcal)', style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.place_outlined, color: Colors.cyanAccent, size: 20),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$distanceKm km',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              Text('Distance', style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Live Health Measure Action Bar
        if (bleService != null)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMeasuring ? Colors.redAccent.withValues(alpha: 0.15) : AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isMeasuring ? Colors.redAccent.withValues(alpha: 0.5) : AppTheme.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isMeasuring ? Icons.sensors_rounded : Icons.favorite_border_rounded,
                  color: isMeasuring ? Colors.redAccent : AppTheme.accent,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMeasuring ? 'Measuring Live Sensors...' : 'Live Health Measurement',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isMeasuring ? Colors.redAccent : Colors.white,
                        ),
                      ),
                      Text(
                        isMeasuring ? 'Sensors active on wrist. Reading HR & SpO2...' : 'Sample instant HR, SpO2 & Blood Pressure',
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: isConnected
                      ? () {
                          if (isMeasuring) {
                            bleService?.stopLiveHealthMeasurement();
                          } else {
                            bleService?.startLiveHealthMeasurement();
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isMeasuring ? Colors.redAccent : AppTheme.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    isMeasuring ? 'Stop' : 'Measure',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

        // 2. Health Vitals Grid (Heart Rate, SpO2, Sleep, Blood Pressure)
        Row(
          children: [
            // Heart Rate Card
            Expanded(
              child: _vitalCard(
                icon: Icons.favorite,
                iconColor: Colors.redAccent,
                label: 'Heart Rate',
                value: telemetry.heartRate != null ? '${telemetry.heartRate}' : '--',
                unit: 'BPM',
                subtitle: telemetry.heartRate != null
                    ? (telemetry.heartRate! < 100 ? 'Normal resting' : 'Active / Elevated')
                    : 'Auto-tracking',
              ),
            ),
            const SizedBox(width: 12),
            // SpO2 Card
            Expanded(
              child: _vitalCard(
                icon: Icons.water_drop,
                iconColor: Colors.tealAccent,
                label: 'Blood Oxygen',
                value: telemetry.spo2 != null ? '${telemetry.spo2}' : '--',
                unit: '%',
                subtitle: telemetry.spo2 != null ? 'Optimal range' : 'Optical pulse-ox',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Sleep Card (with deep & light sleep duration)
            Expanded(
              child: _vitalCard(
                icon: Icons.bedtime,
                iconColor: Colors.purpleAccent,
                label: 'Sleep Rest',
                value: telemetry.totalSleepFormatted,
                unit: '',
                subtitle: telemetry.deepSleepMinutes != null
                    ? 'Deep: ${telemetry.deepSleepMinutes}m · Light: ${telemetry.lightSleepMinutes ?? 0}m'
                    : 'Nightly analysis',
              ),
            ),
            const SizedBox(width: 12),
            // Blood Pressure Card
            Expanded(
              child: _vitalCard(
                icon: Icons.speed_rounded,
                iconColor: Colors.amberAccent,
                label: 'Blood Pressure',
                value: telemetry.bpFormatted,
                unit: telemetry.bpFormatted != '--' ? 'mmHg' : '',
                subtitle: telemetry.bpFormatted != '--' ? 'Estimated pulse wave' : 'Tap measure to sample',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Battery and Connection Status Tile
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.battery_charging_full, color: Colors.greenAccent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Battery: ${telemetry.battery != null ? "${telemetry.battery}%" : "--"}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                    ),
                    Text(
                      isConnected ? 'Hardware linked via BLE GATT' : 'Offline · Tap to connect',
                      style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
              if (isConnected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                  ),
                  child: const Text('ONLINE', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _vitalCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String unit,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[400]),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
