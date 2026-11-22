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
import 'device_discovery_screen.dart';
import 'qr_scanner_screen.dart';
import '../dialogs/connect_device_modal.dart';

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

            // Connect / Disconnect Action Section
            if (isConnected)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: isBusy ? null : () => _bleService.disconnect(),
                  icon: const Icon(Icons.link_off),
                  label: const Text(
                    'Disconnect Watch',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[850],
                    foregroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              )
            else ...[
              // Primary Connect Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: isBusy
                      ? null
                      : () => ConnectDeviceModal.show(context, _bleService),
                  icon: const Icon(Icons.add_link),
                  label: const Text(
                    'Connect New Watch',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Quick Actions Row: Scan QR | Search Nearby
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: const BorderSide(color: Colors.cyanAccent),
                      ),
                      onPressed: isBusy
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      QrScannerScreen(bleService: _bleService),
                                ),
                              );
                            },
                      icon: const Icon(Icons.qr_code_scanner, size: 18, color: Colors.cyanAccent),
                      label: const Text(
                        'Scan QR',
                        style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: const BorderSide(color: Colors.blueAccent),
                      ),
                      onPressed: isBusy
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      DeviceDiscoveryScreen(bleService: _bleService),
                                ),
                              );
                            },
                      icon: const Icon(Icons.bluetooth_searching, size: 18, color: Colors.blueAccent),
                      label: const Text(
                        'Search Devices',
                        style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
