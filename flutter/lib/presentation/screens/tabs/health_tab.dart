import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/ble_service.dart';
import '../../dialogs/connect_device_modal.dart';
import '../../widgets/charts/step_bar_chart.dart';
import '../../widgets/charts/heart_rate_spline_chart.dart';
import '../../widgets/charts/sleep_stage_bar_chart.dart';

/// Health & Fitness Dashboard tab featuring live vitals and interactive historical trends
class HealthTab extends StatefulWidget {
  final BleService bleService;

  const HealthTab({super.key, required this.bleService});

  @override
  State<HealthTab> createState() => _HealthTabState();
}

class _HealthTabState extends State<HealthTab> with SingleTickerProviderStateMixin {
  int _activeChartTab = 0; // 0=Steps, 1=Heart Rate, 2=Sleep
  late final AnimationController _syncAnimController;

  @override
  void initState() {
    super.initState();
    _syncAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    _syncAnimController.dispose();
    super.dispose();
  }

  Future<void> _handleSync() async {
    _syncAnimController.repeat();
    try {
      if (widget.bleService.isConnected) {
        await widget.bleService.syncAll();
      } else if (widget.bleService.lastDeviceMac != null) {
        await widget.bleService.connectByMacAddress(widget.bleService.lastDeviceMac!);
      } else {
        ConnectDeviceModal.show(context, widget.bleService);
      }
    } finally {
      _syncAnimController.stop();
      _syncAnimController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final telemetry = widget.bleService.telemetry;
    final isConnected = widget.bleService.isConnected;
    final isConnecting = widget.bleService.isConnecting;
    final isSyncing = widget.bleService.isSyncing;
    final isMeasuring = widget.bleService.isMeasuringHealth;

    if ((isSyncing || isConnecting) && !_syncAnimController.isAnimating) {
      _syncAnimController.repeat();
    } else if (!isSyncing && !isConnecting && _syncAnimController.isAnimating) {
      _syncAnimController.stop();
      _syncAnimController.reset();
    }

    final steps = telemetry.steps ?? 0;
    final calories = telemetry.calories ?? 0;
    final distKm = (telemetry.distanceMeters ?? 0.0) / 1000.0;
    final sleepMins = (telemetry.deepSleepMinutes ?? 0) + (telemetry.lightSleepMinutes ?? 0);
    final targetSteps = widget.bleService.settings.targetSteps;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // 1. Hero Watch Connection & Battery Capsule
        _buildConnectionHero(isConnected, isConnecting, telemetry.battery, telemetry.lastSyncTime),
        const SizedBox(height: 16),

        // 2. Primary Activity Progress Ring Card
        _buildActivityRingCard(steps, targetSteps, calories, distKm),
        const SizedBox(height: 16),

        // 3. Historical Trends Section with Chart Switcher
        _buildHistoricalChartsCard(),
        const SizedBox(height: 16),

        // 4. Vitals Grid (Heart Rate, Blood Pressure, SpO2)
        _buildVitalsCard(telemetry, isMeasuring),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildConnectionHero(bool isConnected, bool isConnecting, int? battery, DateTime? lastSync) {
    final statusColor = isConnected
        ? AppTheme.success
        : (isConnecting ? AppTheme.accent : AppTheme.textMuted);
    final statusTitle = isConnected
        ? AppStrings.t('watch_active')
        : (isConnecting ? AppStrings.t('connecting_watch') : AppStrings.t('disconnected'));
    final statusSubtitle = isConnecting
        ? AppStrings.t('connecting')
        : (lastSync != null
            ? 'Synced ${DateFormat('hh:mm a').format(lastSync)}'
            : (isConnected ? AppStrings.t('ready_to_sync') : AppStrings.t('tap_to_reconnect')));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isConnecting ? AppTheme.accent.withOpacity(0.5) : AppTheme.border,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  boxShadow: (isConnected || isConnecting)
                      ? [
                          BoxShadow(
                            color: statusColor.withOpacity(0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    statusSubtitle,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              if (battery != null && battery > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        battery > 20 ? Icons.battery_charging_full_rounded : Icons.battery_alert_rounded,
                        color: battery > 20 ? AppTheme.success : AppTheme.heartRate,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$battery%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: isConnecting ? null : _handleSync,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isConnecting ? AppTheme.accent : AppTheme.border,
                    ),
                  ),
                  child: Center(
                    child: isConnecting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.accent,
                            ),
                          )
                        : RotationTransition(
                      turns: _syncAnimController,
                      child: const Icon(
                        Icons.sync_rounded,
                        color: AppTheme.accent,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityRingCard(int steps, int goalSteps, int calories, double distKm) {
    final ratio = (steps / (goalSteps > 0 ? goalSteps : 10000)).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.t('daily_activity'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                'Goal: ${(goalSteps / 1000).toStringAsFixed(0)}k steps',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Circular Progress Indicator
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: CircularProgressIndicator(
                      value: ratio,
                      strokeWidth: 9,
                      strokeCap: StrokeCap.round,
                      backgroundColor: AppTheme.surfaceLight,
                      valueColor: const AlwaysStoppedAnimation(AppTheme.steps),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.directions_walk_rounded, color: AppTheme.steps, size: 22),
                      Text(
                        '${(ratio * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 24),
              // Step, Calorie, Distance stats breakdown
              Expanded(
                child: Column(
                  children: [
                    _buildStatRow(
                      icon: Icons.directions_walk_rounded,
                      iconColor: AppTheme.steps,
                      label: 'Steps',
                      value: NumberFormat('#,###').format(steps),
                      unit: '/ ${NumberFormat('#,###').format(goalSteps)}',
                    ),
                    const Divider(height: 16, color: AppTheme.borderSubtle),
                    _buildStatRow(
                      icon: Icons.local_fire_department_rounded,
                      iconColor: AppTheme.calories,
                      label: 'Active Burn',
                      value: '$calories',
                      unit: 'kcal',
                    ),
                    const Divider(height: 16, color: AppTheme.borderSubtle),
                    _buildStatRow(
                      icon: Icons.place_rounded,
                      iconColor: AppTheme.accent,
                      label: AppStrings.t('distance'),
                      value: distKm.toStringAsFixed(2),
                      unit: 'km',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String unit,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 16),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
        Row(
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
            const SizedBox(width: 4),
            Text(unit, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ],
        ),
      ],
    );
  }

  Widget _buildHistoricalChartsCard() {
    final history = widget.bleService.weeklyHistory;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Segmented chart selector tabs
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.t('weekly_analytics'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.bleService.isConnected
                        ? () => widget.bleService.syncWatchHistory()
                        : null,
                    child: Text(
                      widget.bleService.hasSyncedRealHistory
                          ? 'Watch Flash Data · Tap to refresh'
                          : (widget.bleService.isConnected ? 'Tap to sync Watch Flash' : 'Preview Trend'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: widget.bleService.hasSyncedRealHistory
                            ? AppTheme.success
                            : AppTheme.accent,
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Row(
                  children: [
                    _buildChartTabPill(0, AppStrings.t('steps')),
                    _buildChartTabPill(1, AppStrings.t('heart_rate')),
                    _buildChartTabPill(2, AppStrings.t('sleep')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Chart Body
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _activeChartTab == 0
                ? StepBarChart(
                    key: const ValueKey('StepChart'),
                    records: history,
                    goalSteps: widget.bleService.settings.targetSteps,
                  )
                : _activeChartTab == 1
                    ? HeartRateSplineChart(
                        key: const ValueKey('HrChart'),
                        records: history,
                        currentBpm: widget.bleService.telemetry.heartRate ?? 72,
                      )
                    : SleepStageBarChart(
                        key: const ValueKey('SleepChart'),
                        deepMinutes: widget.bleService.telemetry.deepSleepMinutes ?? 115,
                        lightMinutes: widget.bleService.telemetry.lightSleepMinutes ?? 330,
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartTabPill(int index, String label) {
    final isSelected = _activeChartTab == index;
    return GestureDetector(
      onTap: () => setState(() => _activeChartTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected ? const Color(0xFF0A0C10) : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildVitalsCard(dynamic telemetry, bool isMeasuring) {
    final hr = telemetry.heartRate ?? 0;
    final spo2 = telemetry.spo2 ?? 0;
    final sbp = telemetry.systolicBp ?? 0;
    final dbp = telemetry.diastolicBp ?? 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.t('live_vitals'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isMeasuring ? AppTheme.warning : AppTheme.accent,
                  foregroundColor: const Color(0xFF0A0C10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: Icon(
                  isMeasuring ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  size: 18,
                ),
                label: Text(
                  isMeasuring ? AppStrings.t('measuring') : AppStrings.t('measure_vitals'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                onPressed: () {
                  if (isMeasuring) {
                    widget.bleService.stopLiveHealthMeasurement();
                  } else {
                    widget.bleService.startLiveHealthMeasurement();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildVitalTile(
                  icon: Icons.favorite_rounded,
                  iconColor: AppTheme.heartRate,
                  label: AppStrings.t('heart_rate'),
                  value: hr > 0 ? '$hr' : '--',
                  unit: 'BPM',
                  badge: hr > 0 ? (hr < 100 ? 'Normal' : 'Elevated') : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildVitalTile(
                  icon: Icons.bloodtype_rounded,
                  iconColor: AppTheme.bloodPressure,
                  label: AppStrings.t('blood_pressure'),
                  value: (sbp > 0 && dbp > 0) ? '$sbp/$dbp' : '--/--',
                  unit: 'mmHg',
                  badge: (sbp > 0 && dbp > 0) ? 'Optimal' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildVitalTile(
                  icon: Icons.water_drop_rounded,
                  iconColor: AppTheme.spo2,
                  label: AppStrings.t('blood_oxygen'),
                  value: spo2 > 0 ? '$spo2%' : '--',
                  unit: 'SpO2',
                  badge: spo2 >= 95 ? 'Good' : (spo2 > 0 ? 'Low' : null),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVitalTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String unit,
    String? badge,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: iconColor, size: 18),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            '$label · $unit',
            style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}
