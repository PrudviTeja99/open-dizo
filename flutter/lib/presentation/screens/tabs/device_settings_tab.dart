import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_theme.dart';
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
        _buildSectionHeader('Notifications & Calls', 'Alerts forwarded directly to watch screen'),
        const SizedBox(height: 12),
        _buildNotificationsCard(notifs, isConnected),
        const SizedBox(height: 20),

        // 3. Display & Wrist Gestures
        _buildSectionHeader('Display & Gestures', 'Screen brightness, timeouts, and gestures'),
        const SizedBox(height: 12),
        _buildDisplayGesturesCard(settings),
        const SizedBox(height: 20),

        // 4. Time & System Preferences
        _buildSectionHeader('Preferences & Units', 'Format and measurement system'),
        const SizedBox(height: 12),
        _buildPreferencesCard(settings),
        const SizedBox(height: 20),

        // 5. System Tools & Maintenance
        _buildSectionHeader('System & Diagnostics', 'Firmware, updates, and device management'),
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
}
