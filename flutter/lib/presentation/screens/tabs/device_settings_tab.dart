import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../models/watch_settings.dart';
import '../../../models/notification_settings.dart';
import '../../../services/ble_service.dart';
import '../../dialogs/connect_device_modal.dart';
import '../../dialogs/app_update_dialog.dart';

/// Device & Settings Tab: Watch Controls, Notification & Call Hub, Display, Preferences & Maintenance
class DeviceSettingsTab extends StatefulWidget {
  final BleService bleService;

  const DeviceSettingsTab({super.key, required this.bleService});

  @override
  State<DeviceSettingsTab> createState() => _DeviceSettingsTabState();
}

class _DeviceSettingsTabState extends State<DeviceSettingsTab> with WidgetsBindingObserver {
  Timer? _brightnessDebounceTimer;
  bool _notifAccessGranted = false;
  bool _phonePermsGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshNativePermissions();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshNativePermissions();
    }
  }

  Future<void> _refreshNativePermissions() async {
    if (kIsWeb || !Platform.isAndroid) return;
    final notif = await widget.bleService.isNotificationAccessEnabled();
    final phone = await widget.bleService.isPhonePermissionGranted();
    if (mounted) {
      setState(() {
        _notifAccessGranted = notif;
        _phonePermsGranted = phone;
      });
    }
  }

  Future<void> _requestPhonePermissions() async {
    if (kIsWeb || !Platform.isAndroid) return;
    await [
      Permission.phone,
      Permission.contacts,
    ].request();
    await _refreshNativePermissions();
  }

  void _onBrightnessChanged(double value) {
    final intLevel = value.round().clamp(1, 5);
    _brightnessDebounceTimer?.cancel();
    _brightnessDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      widget.bleService.updateBrightnessAndTimeout(
        brightness: intLevel,
        timeoutSeconds: widget.bleService.settings.screenTimeoutSeconds,
        vibration: widget.bleService.settings.vibrationIntensity,
      );
    });
    setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _brightnessDebounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.bleService.settings;
    final notifs = widget.bleService.notificationSettings;
    final isConnected = widget.bleService.isConnected;
    final deviceMac = widget.bleService.lastDeviceMac ?? 'Not paired';
    final battery = widget.bleService.telemetry.battery;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // 1. Hardware Status & Find Watch Card
        _buildHardwareCard(isConnected, deviceMac, battery),
        const SizedBox(height: 20),

        // 2. Notifications & Incoming Call Hub
        _buildSectionHeader(AppStrings.t('notifications_calls'), 'Alerts forwarded directly to watch screen'),
        const SizedBox(height: 12),
        _buildNotificationsCard(notifs, isConnected),
        const SizedBox(height: 20),

        // 3. Display & Wrist Gestures
        _buildSectionHeader(AppStrings.t('display_gestures'), 'Screen brightness, timeouts, and gestures'),
        const SizedBox(height: 12),
        _buildDisplayGesturesCard(settings),
        const SizedBox(height: 20),

        // 4. Live Weather Sync
        _buildSectionHeader(AppStrings.t('weather_sync'), 'Push live forecast to watch Weather app'),
        const SizedBox(height: 12),
        _buildWeatherCard(settings, isConnected),
        const SizedBox(height: 20),

        // 5. Fitness Goals & Body Profile
        _buildSectionHeader(AppStrings.t('fitness_goals'), 'Calibrates stride length & calorie burn'),
        const SizedBox(height: 12),
        _buildGoalsProfileCard(settings),
        const SizedBox(height: 20),

        // 6. Now-Playing Music Sync
        _buildSectionHeader(AppStrings.t('music_control'), 'Sync track info & control playback from wrist'),
        const SizedBox(height: 12),
        _buildMusicSyncCard(settings),
        const SizedBox(height: 20),

        // 7. Health Warning Thresholds
        _buildSectionHeader(AppStrings.t('health_warnings'), 'Vibrate watch on abnormal HR or BP'),
        const SizedBox(height: 12),
        _buildHealthWarningsCard(settings),
        const SizedBox(height: 20),

        // 8. Language & Apply Target
        _buildSectionHeader(AppStrings.t('language'), 'Apply to App, Watch, or Both independently'),
        const SizedBox(height: 12),
        _buildLanguageCard(settings),
        const SizedBox(height: 20),

        // 9. Time & System Preferences
        _buildSectionHeader(AppStrings.t('preferences_units'), 'Format and measurement system'),
        const SizedBox(height: 12),
        _buildPreferencesCard(settings),
        const SizedBox(height: 20),

        // 10. System Tools & Maintenance
        _buildSectionHeader(AppStrings.t('system_diagnostics'), 'Firmware, updates, and device management'),
        const SizedBox(height: 12),
        _buildMaintenanceCard(isConnected),
        const SizedBox(height: 36),
      ],
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
      ],
    );
  }

  Widget _buildHardwareCard(bool isConnected, String mac, int? battery) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: const Icon(Icons.watch_rounded, color: AppTheme.accent, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DIZO Watch D',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'MAC: $mac',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
              if (battery != null && battery > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        battery > 20 ? Icons.battery_charging_full_rounded : Icons.battery_alert_rounded,
                        color: battery > 20 ? AppTheme.success : AppTheme.heartRate,
                        size: 15,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$battery%',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const Divider(height: 24, color: AppTheme.borderSubtle),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.vibration_rounded, size: 18, color: AppTheme.accent),
                  label: const Text('Find Watch', style: TextStyle(fontSize: 12)),
                  onPressed: isConnected
                      ? () {
                          widget.bleService.findWatch();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Watch vibrating...'), duration: Duration(seconds: 2)),
                          );
                        }
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.devices_rounded, size: 18, color: AppTheme.textSecondary),
                  label: const Text('Switch Device', style: TextStyle(fontSize: 12)),
                  onPressed: () => ConnectDeviceModal.show(context, widget.bleService),
                ),
              ),
            ],
          ),
          if (!kIsWeb && Platform.isAndroid) ...[
            const Divider(height: 22, color: AppTheme.borderSubtle),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '24/7 Background Connection',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    ),
                    Text(
                      'Keep BLE active for calls & alerts when closed',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
                Switch(
                  value: widget.bleService.settings.keepAliveInBackground,
                  onChanged: (val) => widget.bleService.setKeepAliveInBackground(val),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationsCard(NotificationSettings notifs, bool isConnected) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          // Master Forwarding Switch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Push Notifications',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary),
                  ),
                  Text(
                    'Forward phone alerts to watch',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
              Switch(
                value: notifs.masterEnabled,
                onChanged: (val) {
                  widget.bleService.updateNotificationSettings(
                    notifs.copyWith(masterEnabled: val),
                  );
                },
              ),
            ],
          ),

          if (notifs.masterEnabled) ...[
            if (!kIsWeb && Platform.isAndroid) ...[
              const SizedBox(height: 12),
              _buildPermissionPill(
                title: 'Notification Access',
                subtitle: _notifAccessGranted
                    ? 'Listening for WhatsApp, SMS & app alerts'
                    : 'Required to forward phone notifications',
                isGranted: _notifAccessGranted,
                onTap: () => widget.bleService.openNotificationAccessSettings(),
              ),
              const SizedBox(height: 8),
              _buildPermissionPill(
                title: 'Phone & Call Access',
                subtitle: _phonePermsGranted
                    ? 'Listening for incoming calls & caller ID'
                    : 'Required to show caller name on watch',
                isGranted: _phonePermsGranted,
                onTap: _requestPhonePermissions,
              ),
            ],
            const Divider(height: 24, color: AppTheme.borderSubtle),
            // Incoming Calls with Test Action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.phone_in_talk_rounded, color: AppTheme.success, size: 20),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Incoming Call Alerts',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        ),
                        Text(
                          'Displays caller name on wrist',
                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
                Switch(
                  value: notifs.incomingCalls,
                  onChanged: (val) {
                    widget.bleService.updateNotificationSettings(
                      notifs.copyWith(incomingCalls: val),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),
            // Test Call and Test Alert Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.surfaceLight,
                      foregroundColor: AppTheme.accent,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.ring_volume_rounded, size: 16),
                    label: const Text('Test Call Push', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    onPressed: isConnected
                        ? () async {
                            await widget.bleService.pushIncomingCallAlert(
                              callerName: 'Demo Caller',
                              phoneNumber: '+1 555-0199',
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Test call pushed to watch!'), duration: Duration(seconds: 2)),
                              );
                            }
                          }
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.surfaceLight,
                      foregroundColor: AppTheme.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: const Text('Test App Alert', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    onPressed: isConnected
                        ? () async {
                            await widget.bleService.sendNotification(
                              type: 12, // WhatsApp
                              title: 'Open Dizo',
                              body: 'Test notification delivered successfully!',
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Test alert pushed to watch!'), duration: Duration(seconds: 2)),
                              );
                            }
                          }
                        : null,
                  ),
                ),
              ],
            ),

            const Divider(height: 24, color: AppTheme.borderSubtle),
            // Per-App Filters
            _buildAppToggle(
              icon: Icons.chat_bubble_rounded,
              iconColor: const Color(0xFF25D366),
              name: 'WhatsApp',
              value: notifs.whatsapp,
              onChanged: (val) => widget.bleService.updateNotificationSettings(notifs.copyWith(whatsapp: val)),
            ),
            _buildAppToggle(
              icon: Icons.send_rounded,
              iconColor: const Color(0xFF0088CC),
              name: 'Telegram',
              value: notifs.telegram,
              onChanged: (val) => widget.bleService.updateNotificationSettings(notifs.copyWith(telegram: val)),
            ),
            _buildAppToggle(
              icon: Icons.sms_rounded,
              iconColor: AppTheme.accent,
              name: 'SMS Messages',
              value: notifs.sms,
              onChanged: (val) => widget.bleService.updateNotificationSettings(notifs.copyWith(sms: val)),
            ),
            _buildAppToggle(
              icon: Icons.mail_rounded,
              iconColor: AppTheme.calories,
              name: 'Email / Gmail',
              value: notifs.email,
              onChanged: (val) => widget.bleService.updateNotificationSettings(notifs.copyWith(email: val)),
            ),
            _buildAppToggle(
              icon: Icons.camera_alt_rounded,
              iconColor: const Color(0xFFE1306C),
              name: 'Instagram',
              value: notifs.instagram,
              onChanged: (val) => widget.bleService.updateNotificationSettings(notifs.copyWith(instagram: val)),
            ),
            _buildAppToggle(
              icon: Icons.notifications_active_rounded,
              iconColor: AppTheme.sleep,
              name: 'Other Applications',
              value: notifs.others,
              onChanged: (val) => widget.bleService.updateNotificationSettings(notifs.copyWith(others: val)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPermissionPill({
    required String title,
    required String subtitle,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isGranted ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isGranted
              ? AppTheme.success.withValues(alpha: 0.08)
              : AppTheme.warning.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isGranted
                ? AppTheme.success.withValues(alpha: 0.3)
                : AppTheme.warning.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isGranted ? Icons.check_circle_rounded : Icons.security_rounded,
              color: isGranted ? AppTheme.success : AppTheme.warning,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isGranted
                    ? AppTheme.success.withValues(alpha: 0.18)
                    : AppTheme.warning,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isGranted ? 'Active' : 'Enable',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isGranted ? AppTheme.success : const Color(0xFF0A0C10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppToggle({
    required IconData icon,
    required Color iconColor,
    required String name,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 10),
              Text(name, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
            ],
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildDisplayGesturesCard(WatchSettings settings) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brightness Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.brightness_6_rounded, color: AppTheme.accent, size: 18),
                  SizedBox(width: 8),
                  Text('Display Brightness', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                ],
              ),
              Text('Level ${settings.brightness} of 5', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.accent)),
            ],
          ),
          Slider(
            value: settings.brightness.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            activeColor: AppTheme.accent,
            inactiveColor: AppTheme.surfaceLight,
            onChanged: _onBrightnessChanged,
          ),
          const Divider(height: 16, color: AppTheme.borderSubtle),

          // Screen Timeout
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Screen Timeout', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              Row(
                children: [5, 10, 15].map((s) {
                  final isSel = settings.screenTimeoutSeconds == s;
                  return GestureDetector(
                    onTap: () {
                      widget.bleService.updateBrightnessAndTimeout(
                        brightness: settings.brightness,
                        timeoutSeconds: s,
                        vibration: settings.vibrationIntensity,
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSel ? AppTheme.accent : AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${s}s',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSel ? const Color(0xFF0A0C10) : AppTheme.textMuted,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const Divider(height: 24, color: AppTheme.borderSubtle),

          // Raise to Wake
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Raise to Wake', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  Text('Turn wrist to light up screen', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
              Switch(
                value: settings.raiseToWakeEnabled,
                onChanged: (val) {
                  widget.bleService.updateRaiseToWake(
                    enabled: val,
                    startHour: settings.raiseToWakeStartHour,
                    startMin: settings.raiseToWakeStartMinute,
                    endHour: settings.raiseToWakeEndHour,
                    endMin: settings.raiseToWakeEndMinute,
                  );
                },
              ),
            ],
          ),
          const Divider(height: 24, color: AppTheme.borderSubtle),

          // Do Not Disturb
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Do Not Disturb (DND)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  Text('Mute all watch vibration alerts', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
              Switch(
                value: settings.dndEnabled,
                onChanged: (val) {
                  widget.bleService.updateDoNotDisturb(
                    enabled: val,
                    allDay: settings.dndAllDay,
                    startHour: settings.dndStartHour,
                    startMin: settings.dndStartMinute,
                    endHour: settings.dndEndHour,
                    endMin: settings.dndEndMinute,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesCard(WatchSettings settings) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('24-Hour Clock Format', style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
              Switch(
                value: settings.is24HourFormat,
                onChanged: (val) {
                  widget.bleService.updatePreferences(
                    is24Hour: val,
                    isMetric: settings.isMetricUnit,
                    isRightHand: settings.isRightHand,
                  );
                },
              ),
            ],
          ),
          const Divider(height: 20, color: AppTheme.borderSubtle),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Metric Units (km / kg)', style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
              Switch(
                value: settings.isMetricUnit,
                onChanged: (val) {
                  widget.bleService.updatePreferences(
                    is24Hour: settings.is24HourFormat,
                    isMetric: val,
                    isRightHand: settings.isRightHand,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceCard(bool isConnected) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.system_update_alt_rounded, color: AppTheme.accent),
            title: const Text('Check for App Updates', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: const Text('GitHub Releases distribution channel', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
            onTap: () => AppUpdateDialog.show(context),
          ),
          const Divider(height: 16, color: AppTheme.borderSubtle),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.restart_alt_rounded, color: AppTheme.textSecondary),
            title: const Text('Reboot Watch', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: const Text('Restarts the watch firmware', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
            onTap: isConnected ? () => _confirmReboot() : null,
          ),
          const Divider(height: 16, color: AppTheme.borderSubtle),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.restore_rounded, color: AppTheme.heartRate),
            title: const Text('Factory Reset Watch', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.heartRate)),
            subtitle: const Text('Clears all user dials and stored records', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
            onTap: isConnected ? () => _confirmReset() : null,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReboot() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reboot Watch?'),
        content: const Text('The watch will restart and temporarily disconnect.'),
        actions: [
          TextButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(ctx, false)),
          ElevatedButton(child: const Text('Reboot'), onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    if (confirm == true) {
      widget.bleService.restartWatch();
    }
  }

  Future<void> _confirmReset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Factory Reset Watch?'),
        content: const Text('This will reset all settings on your DIZO Watch D to defaults.'),
        actions: [
          TextButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(ctx, false)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.heartRate),
            child: const Text('Reset'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirm == true) {
      widget.bleService.resetWatch();
    }
  }

  Widget _buildWeatherCard(WatchSettings settings, bool isConnected) {
    final weather = widget.bleService.weather;
    final isSyncing = widget.bleService.isSyncingWeather;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppTheme.spo2.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.wb_sunny_rounded, color: AppTheme.spo2, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        weather != null
                            ? '${weather.city} · ${weather.currentTempC}°C'
                            : settings.weatherCity,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      ),
                      Text(
                        weather != null
                            ? '${weather.conditionLabel} · H:${weather.highTempC}° L:${weather.lowTempC}°'
                            : 'Tap Sync to fetch live forecast',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                tooltip: 'Change City',
                icon: const Icon(Icons.edit_location_alt_rounded, color: AppTheme.textSecondary, size: 20),
                onPressed: () => _showCityDialog(settings.weatherCity),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.surfaceLight,
                foregroundColor: AppTheme.accent,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: isSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                    )
                  : const Icon(Icons.cloud_sync_rounded, size: 18),
              label: Text(
                isSyncing ? 'Fetching Forecast...' : (isConnected ? 'Sync Weather to Watch' : 'Preview Weather'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              onPressed: isSyncing
                  ? null
                  : () async {
                      try {
                        final snap = await widget.bleService.syncWeather();
                        if (mounted && snap != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Weather synced: ${snap.city} ${snap.currentTempC}°C (${snap.conditionLabel})'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Weather error: $e'), backgroundColor: AppTheme.heartRate),
                          );
                        }
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsProfileCard(WatchSettings settings) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.steps.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.flag_rounded, color: AppTheme.steps, size: 20),
            ),
            title: const Text('Daily Fitness Targets', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${settings.targetSteps} steps · ${settings.targetCalories} kcal · ${(settings.targetDistanceMeters / 1000).toStringAsFixed(1)} km',
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
            onTap: () => _showGoalsDialog(settings),
          ),
          const Divider(height: 16, color: AppTheme.borderSubtle),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.calories.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person_rounded, color: AppTheme.calories, size: 20),
            ),
            title: const Text('Body Profile', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${settings.isMale ? "Male" : "Female"} · ${settings.age} yrs · ${settings.heightCm.round()} cm · ${settings.weightKg.round()} kg',
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
            onTap: () => _showProfileDialog(settings),
          ),
        ],
      ),
    );
  }

  Future<void> _showCityDialog(String currentCity) async {
    final ctrl = TextEditingController(text: currentCity);
    final newCity = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Weather City'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter city name (e.g. Bengaluru, London)',
          ),
        ),
        actions: [
          TextButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(ctx)),
          ElevatedButton(
            child: const Text('Save & Sync'),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          ),
        ],
      ),
    );
    if (newCity != null && newCity.isNotEmpty) {
      try {
        await widget.bleService.syncWeather(city: newCity);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not fetch weather for "$newCity": $e')),
          );
        }
      }
    }
  }

  Future<void> _showGoalsDialog(WatchSettings settings) async {
    int steps = settings.targetSteps;
    int calories = settings.targetCalories;
    double distKm = settings.targetDistanceMeters / 1000.0;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Daily Fitness Targets', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              Text('Steps Goal: $steps', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Slider(
                value: steps.toDouble().clamp(2000, 30000),
                min: 2000,
                max: 30000,
                divisions: 28,
                activeColor: AppTheme.steps,
                onChanged: (v) => setModalState(() => steps = v.round()),
              ),
              Text('Calorie Burn Goal: $calories kcal', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Slider(
                value: calories.toDouble().clamp(100, 1500),
                min: 100,
                max: 1500,
                divisions: 28,
                activeColor: AppTheme.calories,
                onChanged: (v) => setModalState(() => calories = v.round()),
              ),
              Text('Distance Goal: ${distKm.toStringAsFixed(1)} km', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Slider(
                value: distKm.clamp(1.0, 20.0),
                min: 1.0,
                max: 20.0,
                divisions: 38,
                activeColor: AppTheme.accent,
                onChanged: (v) => setModalState(() => distKm = v),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    widget.bleService.updateExerciseTargets(
                      steps: steps,
                      distanceMeters: (distKm * 1000).round(),
                      calories: calories,
                    );
                    Navigator.pop(ctx);
                  },
                  child: const Text('Save & Sync to Watch'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showProfileDialog(WatchSettings settings) async {
    bool isMale = settings.isMale;
    int age = settings.age;
    double heightCm = settings.heightCm;
    double weightKg = settings.weightKg;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Body Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Male'),
                    selected: isMale,
                    selectedColor: AppTheme.accent,
                    labelStyle: TextStyle(color: isMale ? const Color(0xFF0A0C10) : AppTheme.textSecondary),
                    onSelected: (_) => setModalState(() => isMale = true),
                  ),
                  const SizedBox(width: 10),
                  ChoiceChip(
                    label: const Text('Female'),
                    selected: !isMale,
                    selectedColor: AppTheme.accent,
                    labelStyle: TextStyle(color: !isMale ? const Color(0xFF0A0C10) : AppTheme.textSecondary),
                    onSelected: (_) => setModalState(() => isMale = false),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Age: $age yrs', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Slider(
                value: age.toDouble().clamp(10, 90),
                min: 10,
                max: 90,
                divisions: 80,
                activeColor: AppTheme.accent,
                onChanged: (v) => setModalState(() => age = v.round()),
              ),
              Text('Height: ${heightCm.round()} cm', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Slider(
                value: heightCm.clamp(120, 220),
                min: 120,
                max: 220,
                divisions: 100,
                activeColor: AppTheme.accent,
                onChanged: (v) => setModalState(() => heightCm = v),
              ),
              Text('Weight: ${weightKg.round()} kg', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Slider(
                value: weightKg.clamp(30, 160),
                min: 30,
                max: 160,
                divisions: 130,
                activeColor: AppTheme.accent,
                onChanged: (v) => setModalState(() => weightKg = v),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    widget.bleService.updateUserProfile(
                      isMale: isMale,
                      age: age,
                      heightCm: heightCm,
                      weightKg: weightKg,
                    );
                    Navigator.pop(ctx);
                  },
                  child: const Text('Save & Sync to Watch'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMusicSyncCard(WatchSettings settings) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.sleep.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.music_note_rounded, color: AppTheme.sleep, size: 20),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Now-Playing Track Sync',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                  ),
                  Text(
                    'Display song title & control from watch',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ],
          ),
          Switch(
            value: settings.musicSyncEnabled,
            onChanged: (val) => widget.bleService.setMusicSyncEnabled(val),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthWarningsCard(WatchSettings settings) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.heartRate.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.monitor_heart_rounded, color: AppTheme.heartRate, size: 20),
            ),
            title: const Text('Heart Rate Thresholds', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text(
              (settings.warnHrStaticEnabled || settings.warnHrDynamicEnabled)
                  ? 'Resting > ${settings.warnHrStaticBpm} · Active > ${settings.warnHrDynamicBpm} BPM'
                  : 'Alerts disabled',
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
            onTap: () => _showHrWarnDialog(settings),
          ),
          const Divider(height: 16, color: AppTheme.borderSubtle),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.bloodPressure.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.bloodtype_rounded, color: AppTheme.bloodPressure, size: 20),
            ),
            title: const Text('Blood Pressure Thresholds', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text(
              settings.warnBpEnabled
                  ? 'SBP ${settings.warnBpSbpLower}-${settings.warnBpSbpUpper} · DBP ${settings.warnBpDbpLower}-${settings.warnBpDbpUpper}'
                  : 'Alerts disabled',
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
            onTap: () => _showBpWarnDialog(settings),
          ),
        ],
      ),
    );
  }

  Future<void> _showHrWarnDialog(WatchSettings settings) async {
    bool staticEnable = settings.warnHrStaticEnabled;
    int staticBpm = settings.warnHrStaticBpm;
    bool dynamicEnable = settings.warnHrDynamicEnabled;
    int dynamicBpm = settings.warnHrDynamicBpm;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Heart Rate Warning Alerts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Resting High HR Alert ($staticBpm BPM)', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text('Warn when resting HR exceeds limit', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                value: staticEnable,
                onChanged: (v) => setModalState(() => staticEnable = v),
              ),
              if (staticEnable)
                Slider(
                  value: staticBpm.toDouble().clamp(80, 160),
                  min: 80,
                  max: 160,
                  divisions: 16,
                  activeColor: AppTheme.heartRate,
                  onChanged: (v) => setModalState(() => staticBpm = v.round()),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Active High HR Alert ($dynamicBpm BPM)', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text('Warn during exercise if HR exceeds limit', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                value: dynamicEnable,
                onChanged: (v) => setModalState(() => dynamicEnable = v),
              ),
              if (dynamicEnable)
                Slider(
                  value: dynamicBpm.toDouble().clamp(120, 210),
                  min: 120,
                  max: 210,
                  divisions: 18,
                  activeColor: AppTheme.heartRate,
                  onChanged: (v) => setModalState(() => dynamicBpm = v.round()),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    widget.bleService.updateWarnHeartRate(
                      staticEnable: staticEnable,
                      staticBpm: staticBpm,
                      dynamicEnable: dynamicEnable,
                      dynamicBpm: dynamicBpm,
                    );
                    Navigator.pop(ctx);
                  },
                  child: const Text('Save & Sync to Watch'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showBpWarnDialog(WatchSettings settings) async {
    bool enable = settings.warnBpEnabled;
    int sbpUpper = settings.warnBpSbpUpper;
    int sbpLower = settings.warnBpSbpLower;
    int dbpUpper = settings.warnBpDbpUpper;
    int dbpLower = settings.warnBpDbpLower;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Blood Pressure Warnings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable BP Alert Thresholds', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                value: enable,
                onChanged: (v) => setModalState(() => enable = v),
              ),
              if (enable) ...[
                Text('Systolic (SBP) Range: $sbpLower – $sbpUpper mmHg', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                RangeSlider(
                  values: RangeValues(sbpLower.toDouble(), sbpUpper.toDouble()),
                  min: 70,
                  max: 200,
                  divisions: 26,
                  activeColor: AppTheme.bloodPressure,
                  onChanged: (r) => setModalState(() {
                    sbpLower = r.start.round();
                    sbpUpper = r.end.round();
                  }),
                ),
                Text('Diastolic (DBP) Range: $dbpLower – $dbpUpper mmHg', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                RangeSlider(
                  values: RangeValues(dbpLower.toDouble(), dbpUpper.toDouble()),
                  min: 40,
                  max: 130,
                  divisions: 18,
                  activeColor: AppTheme.bloodPressure,
                  onChanged: (r) => setModalState(() {
                    dbpLower = r.start.round();
                    dbpUpper = r.end.round();
                  }),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    widget.bleService.updateWarnBloodPressure(
                      enable: enable,
                      sbpUpper: sbpUpper,
                      sbpLower: sbpLower,
                      dbpUpper: dbpUpper,
                      dbpLower: dbpLower,
                    );
                    Navigator.pop(ctx);
                  },
                  child: const Text('Save & Sync to Watch'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageCard(WatchSettings settings) {
    final currentLang = AppLanguage.fromCode(settings.languageCode);
    final currentTarget = LanguageApplyTarget.fromId(settings.languageTarget);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.translate_rounded, color: AppTheme.accent, size: 20),
            ),
            title: Text(
              currentLang.nativeName == currentLang.englishName
                  ? currentLang.englishName
                  : '${currentLang.nativeName} (${currentLang.englishName})',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
            subtitle: Text(
              'Watch Protocol ID: ${currentLang.watchCode}',
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
            onTap: () => _showLanguagePicker(currentLang),
          ),
          const Divider(height: 18, color: AppTheme.borderSubtle),
          Text(
            AppStrings.t('apply_language_to'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 10),
          Row(
            children: LanguageApplyTarget.values.map((t) {
              final isSelected = currentTarget == t;
              return Expanded(
                child: GestureDetector(
                  onTap: () => widget.bleService.setLanguagePreference(target: t),
                  child: Container(
                    margin: EdgeInsets.only(right: t == LanguageApplyTarget.watchOnly ? 0 : 8),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.accent : AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppTheme.accent : AppTheme.borderSubtle,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        t.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? const Color(0xFF0A0C10) : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _showLanguagePicker(AppLanguage currentLang) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.t('language'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 380),
                child: ListView(
                  shrinkWrap: true,
                  children: AppLanguage.values.map((lang) {
                    final isSel = lang == currentLang;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      title: Text(
                        lang.nativeName,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isSel ? AppTheme.accent : AppTheme.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        lang.englishName,
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                      trailing: isSel
                          ? const Icon(Icons.check_circle_rounded, color: AppTheme.accent)
                          : null,
                      onTap: () {
                        widget.bleService.setLanguagePreference(language: lang);
                        Navigator.pop(ctx);
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
