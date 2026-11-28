import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/l10n/app_strings.dart';
import '../../services/ble_service.dart';
import '../dialogs/connect_device_modal.dart';
import '../dialogs/app_update_dialog.dart';
import 'camera_shutter_screen.dart';
import 'dial_studio_screen.dart';
import 'tabs/health_tab.dart';
import 'tabs/reminders_tab.dart';
import 'tabs/device_settings_tab.dart';

/// Main Multi-Tab Navigation Shell of Open Dizo
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final BleService _bleService;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _bleService = BleService();
    _bleService.addListener(_onServiceUpdate);
    _bleService.watchCameraOpenRequested.addListener(_onWatchCameraRequested);
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  void _onWatchCameraRequested() {
    if (!mounted || !_bleService.watchCameraOpenRequested.value) return;
    _bleService.watchCameraOpenRequested.value = false;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CameraShutterScreen(bleService: _bleService),
      ),
    );
  }

  @override
  void dispose() {
    _bleService.watchCameraOpenRequested.removeListener(_onWatchCameraRequested);
    _bleService.removeListener(_onServiceUpdate);
    _bleService.dispose();
    super.dispose();
  }

  static const _tabTitleKeys = [
    'title_health',
    'title_studio',
    'title_reminders',
    'title_device',
  ];

  @override
  Widget build(BuildContext context) {
    final isConnected = _bleService.isConnected;
    final isBusy = _bleService.isScanning || _bleService.isConnecting;

    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppStrings.currentLanguage,
      builder: (context, _, __) => Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: const Icon(Icons.watch_rounded, color: AppTheme.accent, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Open Dizo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  AppStrings.t(_tabTitleKeys[_currentIndex]),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Connection pill indicator
          GestureDetector(
            onTap: isBusy ? null : () => ConnectDeviceModal.show(context, _bleService),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isConnected ? AppTheme.success.withOpacity(0.4) : AppTheme.border,
                ),
              ),
                child: Row(
                  children: [
                    if (_bleService.isConnecting)
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: AppTheme.accent,
                        ),
                      )
                    else
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isConnected ? AppTheme.success : AppTheme.heartRate,
                          shape: BoxShape.circle,
                        ),
                      ),
                    const SizedBox(width: 6),
                    Text(
                      _bleService.isConnecting
                          ? AppStrings.t('connecting')
                          : (isConnected ? AppStrings.t('connected') : AppStrings.t('offline')),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: (_bleService.isConnecting || isConnected)
                            ? AppTheme.textPrimary
                            : AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
            ),
          ),
          IconButton(
            tooltip: 'Check for Updates',
            icon: const Icon(Icons.system_update_alt_rounded, size: 20, color: AppTheme.textSecondary),
            onPressed: () => AppUpdateDialog.show(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_bleService.isFindingPhone)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.heartRate.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.heartRate, width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.ring_volume_rounded, color: AppTheme.heartRate, size: 22),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Watch is Finding Your Phone',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                          Text(
                            'Tap Stop to silence ringtone & vibration',
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.heartRate,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _bleService.stopFindPhoneAlert(),
                      child: const Text('Stop', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  HealthTab(bleService: _bleService),
                  DialStudioScreen(bleService: _bleService, isEmbedded: true),
                  RemindersTab(bleService: _bleService),
                  DeviceSettingsTab(bleService: _bleService),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
          backgroundColor: Colors.transparent,
          indicatorColor: AppTheme.accent.withOpacity(0.18),
          elevation: 0,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.insights_rounded, color: AppTheme.textMuted, size: 22),
              selectedIcon: const Icon(Icons.insights_rounded, color: AppTheme.accent, size: 22),
              label: AppStrings.t('tab_health'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.palette_rounded, color: AppTheme.textMuted, size: 22),
              selectedIcon: const Icon(Icons.palette_rounded, color: AppTheme.accent, size: 22),
              label: AppStrings.t('tab_studio'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.alarm_rounded, color: AppTheme.textMuted, size: 22),
              selectedIcon: const Icon(Icons.alarm_rounded, color: AppTheme.accent, size: 22),
              label: AppStrings.t('tab_reminders'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.tune_rounded, color: AppTheme.textMuted, size: 22),
              selectedIcon: const Icon(Icons.tune_rounded, color: AppTheme.accent, size: 22),
              label: AppStrings.t('tab_device'),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
