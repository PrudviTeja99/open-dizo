import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/ble_service.dart';

/// Screen providing full control over all watch options and preferences
/// Implemented according to official companion app specifications.
class WatchSettingsScreen extends StatefulWidget {
  final BleService bleService;

  const WatchSettingsScreen({super.key, required this.bleService});

  @override
  State<WatchSettingsScreen> createState() => _WatchSettingsScreenState();
}

class _WatchSettingsScreenState extends State<WatchSettingsScreen> {
  BleService get _ble => widget.bleService;
  double? _sliderBrightness;

  @override
  void initState() {
    super.initState();
    _ble.addListener(_onServiceUpdate);
    // Request current configuration on opening settings
    if (_ble.isConnected) {
      _ble.queryWatchConfig();
    }
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ble.removeListener(_onServiceUpdate);
    super.dispose();
  }

  String _formatTime(int hour, int minute) {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final settings = _ble.settings;
    final isConnected = _ble.isConnected;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Watch Settings & Options', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            if (!isConnected)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Watch disconnected. Changes will be saved locally and pushed when connected.',
                        style: TextStyle(fontSize: 12, color: Colors.amber),
                      ),
                    ),
                  ],
                ),
              ),

            // 1. Display & Screen
            _sectionHeader(Icons.brightness_medium_rounded, 'DISPLAY & SCREEN'),
            _cardContainer(
              children: [
                // Brightness Slider
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Screen Brightness', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      Text('Level ${(_sliderBrightness ?? settings.brightness.toDouble()).round()} of 5', style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.brightness_low, size: 18, color: Colors.grey),
                    Expanded(
                      child: Slider(
                        value: (_sliderBrightness ?? settings.brightness.toDouble()).clamp(1.0, 5.0),
                        min: 1.0,
                        max: 5.0,
                        divisions: 4,
                        activeColor: AppTheme.accent,
                        onChanged: (val) {
                          setState(() {
                            _sliderBrightness = val;
                          });
                        },
                        onChangeEnd: (val) {
                          setState(() {
                            _sliderBrightness = null;
                          });
                          _ble.updateBrightnessAndTimeout(
                            brightness: val.round(),
                            timeoutSeconds: settings.screenTimeoutSeconds,
                          );
                        },
                      ),
                    ),
                    const Icon(Icons.brightness_high, size: 22, color: Colors.amber),
                  ],
                ),
                const Divider(height: 24),

                // Screen Timeout
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Screen Timeout', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    Row(
                      children: [5, 10, 15].map((sec) {
                        final isSel = settings.screenTimeoutSeconds == sec;
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: ChoiceChip(
                            label: Text('${sec}s', style: TextStyle(fontSize: 12, color: isSel ? Colors.black : Colors.white)),
                            selected: isSel,
                            selectedColor: AppTheme.accent,
                            backgroundColor: AppTheme.surfaceLight,
                            onSelected: (_) {
                              _ble.updateBrightnessAndTimeout(
                                brightness: settings.brightness,
                                timeoutSeconds: sec,
                              );
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Raise to Wake (Turn Wrist)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Raise to Wake', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                    settings.raiseToWakeEnabled
                        ? 'Active ${_formatTime(settings.raiseToWakeStartHour, settings.raiseToWakeStartMinute)} – ${_formatTime(settings.raiseToWakeEndHour, settings.raiseToWakeEndMinute)}'
                        : 'Disabled',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                  value: settings.raiseToWakeEnabled,
                  activeTrackColor: AppTheme.accent,
                  activeThumbColor: Colors.black,
                  onChanged: (val) {
                    _ble.updateRaiseToWake(enabled: val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 2. Health Monitoring & Reminders
            _sectionHeader(Icons.health_and_safety_rounded, 'HEALTH & REMINDERS'),
            _cardContainer(
              children: [
                // Continuous Heart Rate & Health
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Continuous Health Monitoring', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                    settings.continuousHealthEnabled
                        ? 'Auto-sampling every ${settings.healthIntervalMinutes} min'
                        : 'Manual check only',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                  value: settings.continuousHealthEnabled,
                  activeTrackColor: AppTheme.accent,
                  activeThumbColor: Colors.black,
                  onChanged: (val) {
                    _ble.updateContinuousHealth(enabled: val, intervalMinutes: settings.healthIntervalMinutes);
                  },
                ),
                if (settings.continuousHealthEnabled) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Sample Interval', style: TextStyle(fontSize: 13, color: Colors.grey[300])),
                      Row(
                        children: [10, 30, 60].map((interval) {
                          final isSel = settings.healthIntervalMinutes == interval;
                          return Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: ChoiceChip(
                              label: Text('${interval}m', style: TextStyle(fontSize: 11, color: isSel ? Colors.black : Colors.white)),
                              selected: isSel,
                              selectedColor: AppTheme.accent,
                              backgroundColor: AppTheme.surfaceLight,
                              onSelected: (_) {
                                _ble.updateContinuousHealth(enabled: true, intervalMinutes: interval);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ],
                const Divider(height: 24),

                // Sedentary Reminder
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Sedentary Inactivity Reminder', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                    settings.sedentaryEnabled
                        ? 'Alerts after ${settings.sedentaryIntervalMinutes} min of sitting (${_formatTime(settings.sedentaryStartHour, 0)} – ${_formatTime(settings.sedentaryEndHour, 0)})'
                        : 'Disabled',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                  value: settings.sedentaryEnabled,
                  activeTrackColor: AppTheme.accent,
                  activeThumbColor: Colors.black,
                  onChanged: (val) {
                    _ble.updateSedentaryReminder(
                      enabled: val,
                      intervalMinutes: settings.sedentaryIntervalMinutes,
                      startHour: settings.sedentaryStartHour,
                      endHour: settings.sedentaryEndHour,
                    );
                  },
                ),
                const Divider(height: 24),

                // Drink Water Reminder
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Drink Water Reminder', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                    settings.drinkWaterEnabled
                        ? 'Reminds every ${settings.drinkWaterIntervalMinutes} min to stay hydrated'
                        : 'Disabled',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                  value: settings.drinkWaterEnabled,
                  activeTrackColor: AppTheme.accent,
                  activeThumbColor: Colors.black,
                  onChanged: (val) {
                    _ble.updateDrinkWaterReminder(
                      enabled: val,
                      intervalMinutes: settings.drinkWaterIntervalMinutes,
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 3. Preferences & Units
            _sectionHeader(Icons.tune_rounded, 'PREFERENCES & FORMATS'),
            _cardContainer(
              children: [
                // Time Format (12h vs 24h)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('24-Hour Time Format', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(settings.is24HourFormat ? 'Display 13:00' : 'Display 1:00 PM', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                  value: settings.is24HourFormat,
                  activeTrackColor: AppTheme.accent,
                  activeThumbColor: Colors.black,
                  onChanged: (val) {
                    _ble.updatePreferences(is24Hour: val);
                  },
                ),
                const Divider(height: 24),

                // Unit System (Metric vs Imperial)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Metric System (km / kg)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(settings.isMetricUnit ? 'Kilometers & kilograms' : 'Miles & pounds (Imperial)', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                  value: settings.isMetricUnit,
                  activeTrackColor: AppTheme.accent,
                  activeThumbColor: Colors.black,
                  onChanged: (val) {
                    _ble.updatePreferences(isMetric: val);
                  },
                ),
                const Divider(height: 24),

                // Wearing Wrist (Left vs Right Hand)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Wearing on Right Wrist', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(settings.isRightHand ? 'Optimized for right arm' : 'Left arm (Standard)', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                  value: settings.isRightHand,
                  activeTrackColor: AppTheme.accent,
                  activeThumbColor: Colors.black,
                  onChanged: (val) {
                    _ble.updatePreferences(isRightHand: val);
                  },
                ),
                const Divider(height: 24),

                // Do Not Disturb (DND)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Do Not Disturb (DND)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                    settings.dndEnabled
                        ? (settings.dndAllDay
                            ? 'Silenced all day'
                            : 'Silenced ${_formatTime(settings.dndStartHour, settings.dndStartMinute)} – ${_formatTime(settings.dndEndHour, settings.dndEndMinute)}')
                        : 'Vibrations and alerts active',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                  value: settings.dndEnabled,
                  activeTrackColor: AppTheme.accent,
                  activeThumbColor: Colors.black,
                  onChanged: (val) {
                    _ble.updateDoNotDisturb(enabled: val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 4. Device Maintenance & System Actions
            _sectionHeader(Icons.settings_suggest_rounded, 'DEVICE MAINTENANCE'),
            _cardContainer(
              children: [
                // Find Watch
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.vibration, color: Colors.orangeAccent),
                  title: const Text('Find Watch', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Sends a vibration alert to locate your watch', style: TextStyle(fontSize: 12)),
                  trailing: OutlinedButton(
                    onPressed: isConnected ? () => _ble.findWatch() : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orangeAccent,
                      side: const BorderSide(color: Colors.orangeAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Vibrate'),
                  ),
                ),
                const Divider(height: 16),

                // Restart Watch
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.restart_alt_rounded, color: Colors.blueAccent),
                  title: const Text('Restart Watch', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Performs a soft reboot of the watch firmware', style: TextStyle(fontSize: 12)),
                  trailing: OutlinedButton(
                    onPressed: isConnected ? () => _confirmAction('Restart Watch', 'Reboot the watch firmware now?', () => _ble.restartWatch()) : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blueAccent,
                      side: const BorderSide(color: Colors.blueAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Reboot'),
                  ),
                ),
                const Divider(height: 16),

                // Power Off Watch
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.power_settings_new_rounded, color: Colors.redAccent),
                  title: const Text('Power Off Watch', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Shuts down watch hardware until physical button pressed', style: TextStyle(fontSize: 12)),
                  trailing: OutlinedButton(
                    onPressed: isConnected ? () => _confirmAction('Power Off Watch', 'Shut down the watch display and sensors?', () => _ble.turnOffWatch()) : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Shut Down'),
                  ),
                ),
                const Divider(height: 16),

                // Factory Reset
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.restore_rounded, color: Colors.red),
                  title: const Text('Factory Reset', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.red)),
                  subtitle: const Text('Clears all watch user data and restores defaults', style: TextStyle(fontSize: 12)),
                  trailing: OutlinedButton(
                    onPressed: isConnected ? () => _confirmAction('Factory Reset', 'Are you sure? This will wipe all stored metrics and reset the watch to factory defaults.', () => _ble.resetWatch()) : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Reset'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _confirmAction(String title, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(message, style: const TextStyle(fontSize: 13, color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.accent),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardContainer({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
