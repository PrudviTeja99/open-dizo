import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/ble_service.dart';
import '../dialogs/connect_device_modal.dart';
import '../dialogs/app_update_dialog.dart';
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
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _bleService.removeListener(_onServiceUpdate);
    _bleService.dispose();
    super.dispose();
  }

  static const _tabTitles = [
    'Health & Activity',
    'Watch Face Studio',
    'Alarms & Alerts',
    'Device Settings',
  ];

  @override
  Widget build(BuildContext context) {
    final isConnected = _bleService.isConnected;
    final isBusy = _bleService.isScanning || _bleService.isConnecting;

    return Scaffold(
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
                  _tabTitles[_currentIndex],
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
                    isConnected ? 'Connected' : 'Offline',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isConnected ? AppTheme.textPrimary : AppTheme.textMuted,
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
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.insights_rounded, color: AppTheme.textMuted, size: 22),
              selectedIcon: Icon(Icons.insights_rounded, color: AppTheme.accent, size: 22),
              label: 'Health',
            ),
            NavigationDestination(
              icon: Icon(Icons.palette_rounded, color: AppTheme.textMuted, size: 22),
              selectedIcon: Icon(Icons.palette_rounded, color: AppTheme.accent, size: 22),
              label: 'Studio',
            ),
            NavigationDestination(
              icon: Icon(Icons.alarm_rounded, color: AppTheme.textMuted, size: 22),
              selectedIcon: Icon(Icons.alarm_rounded, color: AppTheme.accent, size: 22),
              label: 'Reminders',
            ),
            NavigationDestination(
              icon: Icon(Icons.tune_rounded, color: AppTheme.textMuted, size: 22),
              selectedIcon: Icon(Icons.tune_rounded, color: AppTheme.accent, size: 22),
              label: 'Device',
            ),
          ],
        ),
      ),
    );
  }
}
