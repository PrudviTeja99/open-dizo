import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../services/ble_service.dart';
import '../widgets/status_header.dart';
import '../widgets/time_sync_card.dart';
import '../widgets/actions_card.dart';
import '../widgets/telemetry_card.dart';
import '../widgets/ble_log_card.dart';
import 'dial_studio_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final BleService _bleService;
  final ScrollController _logScrollController = ScrollController();

  Timer? _clockTimer;
  String _currentTime = '--:--:--';
  String _currentDate = '';

  @override
  void initState() {
    super.initState();
    _bleService = BleService();
    _bleService.addListener(_onServiceUpdate);

    _updateClock();
    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateClock(),
    );
  }

  void _onServiceUpdate() {
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _updateClock() {
    final now = DateTime.now();
    setState(() {
      _currentTime = DateFormat('HH:mm:ss').format(now);
      _currentDate = DateFormat('EEEE, MMMM d, y').format(now);
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _logScrollController.dispose();
    _bleService.removeListener(_onServiceUpdate);
    _bleService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _bleService.isConnected;
    final isBusy = _bleService.isScanning || _bleService.isConnecting;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            // Status & Header
            StatusHeader(bleService: _bleService),
            const SizedBox(height: 20),

            // Connect / Disconnect Action Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: isBusy ? null : () => _bleService.scanAndConnect(),
                icon: Icon(isConnected ? Icons.link_off : Icons.bluetooth_searching),
                label: Text(
                  isConnected ? 'Disconnect' : 'Connect to Watch',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isConnected ? Colors.grey[800] : AppTheme.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Time Synchronization Card
            TimeSyncCard(
              currentTime: _currentTime,
              currentDate: _currentDate,
              isConnected: isConnected,
              onSyncTime: () => _bleService.syncTime(),
            ),
            const SizedBox(height: 12),

            // Watch Face Studio Entry Card
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.palette_outlined, color: AppTheme.accent, size: 26),
                ),
                title: const Text('Watch Face Studio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: const Text('Customize clock styles, adjust wallpaper & flash dials', style: TextStyle(fontSize: 12, color: Colors.grey)),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DialStudioScreen(bleService: _bleService),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Command Actions Card
            ActionsCard(bleService: _bleService),
            const SizedBox(height: 12),

            // Live Telemetry (visible when connected)
            if (isConnected) ...[
              TelemetryCard(telemetry: _bleService.telemetry),
              const SizedBox(height: 12),
            ],

            // Real-time Hex BLE Packet Console
            BleLogCard(
              logs: _bleService.logs,
              scrollController: _logScrollController,
              onClear: () => _bleService.clearLogs(),
            ),
            const SizedBox(height: 20),

            // Footer Information
            Center(
              child: Text(
                'Open DIZO BLE Protocol Client\nNo cloud · No telemetry · 100% local',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
