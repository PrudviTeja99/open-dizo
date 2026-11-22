import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/ble_service.dart';
import '../widgets/status_header.dart';
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

  @override
  void initState() {
    super.initState();
    _bleService = BleService();
    _bleService.addListener(_onServiceUpdate);
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

  @override
  void dispose() {
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
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.watch_rounded, color: AppTheme.accent, size: 22),
            const SizedBox(width: 8),
            const Text(
              'DIZO Companion',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          if (isConnected)
            IconButton(
              tooltip: 'Disconnect Watch',
              icon: const Icon(Icons.link_off, color: Colors.grey, size: 20),
              onPressed: isBusy ? null : () => _bleService.disconnect(),
            )
          else
            IconButton(
              tooltip: 'Connect Watch',
              icon: const Icon(Icons.add_link, color: AppTheme.accent),
              onPressed: isBusy ? null : () => ConnectDeviceModal.show(context, _bleService),
            ),
          IconButton(
            tooltip: 'Search Devices',
            icon: const Icon(Icons.bluetooth_searching, size: 20),
            onPressed: isBusy
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => DeviceDiscoveryScreen(bleService: _bleService)),
                    ),
          ),
        ],
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.accent,
          backgroundColor: AppTheme.surface,
          onRefresh: () async {
            if (isConnected) {
              await _bleService.syncAll();
            } else if (_bleService.lastDeviceMac != null) {
              await _bleService.connectByMacAddress(_bleService.lastDeviceMac!);
            }
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            children: [
              // 1. Connection Status & Device Pill Card
              StatusHeader(bleService: _bleService),
              const SizedBox(height: 12),

              // 2. Disconnected Quick Connect Prompt Card (if disconnected)
              if (!isConnected) ...[
                Container(
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
                        children: [
                          const Icon(Icons.bluetooth_disabled, color: Colors.orangeAccent, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Watch Not Connected',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _bleService.lastDeviceMac != null
                            ? 'Ready to reconnect to ${_bleService.lastDeviceName ?? "DIZO Watch D"} (${_bleService.lastDeviceMac})'
                            : 'Connect your DIZO Watch D via QR code scan or Bluetooth discovery to sync health data.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          if (_bleService.lastDeviceMac != null) ...[
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accent,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: isBusy
                                    ? null
                                    : () => _bleService.connectByMacAddress(_bleService.lastDeviceMac!),
                                icon: const Icon(Icons.bolt, size: 18),
                                label: const Text('Quick Connect', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.cyanAccent),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: isBusy
                                  ? null
                                  : () => Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => QrScannerScreen(bleService: _bleService)),
                                      ),
                              icon: const Icon(Icons.qr_code_scanner, size: 18, color: Colors.cyanAccent),
                              label: const Text('Scan QR', style: TextStyle(color: Colors.cyanAccent)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // 3. Central Health & Activity Metrics Display (Hero Activity + Vitals Grid)
              TelemetryCard(
                telemetry: _bleService.telemetry,
                isConnected: isConnected,
                isSyncing: _bleService.isSyncing,
                onRefresh: () => _bleService.syncAll(),
              ),
              const SizedBox(height: 14),

              // 4. Watch Face Studio Banner Card
              InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DialStudioScreen(bleService: _bleService),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF311042), Color(0xFF1F1D36)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.purpleAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.palette_outlined, color: Colors.purpleAccent, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Watch Face Studio',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Custom wallpapers, pinch-to-zoom crop & clock positioning',
                              style: TextStyle(fontSize: 12, color: Colors.purple[100]),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Colors.purpleAccent, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 5. Quick Tools Bar (Vibrate / Find Watch & Full Sync)
              ActionsCard(bleService: _bleService),
              const SizedBox(height: 14),

              // 6. Collapsible Developer Diagnostics & BLE Packet Logs
              Card(
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: const Icon(Icons.terminal_outlined, color: Colors.cyanAccent, size: 20),
                    title: const Text(
                      'Diagnostic Console & BLE Packets',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${_bleService.logs.length} packets logged (Tap to expand)',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: BleLogCard(
                          logs: _bleService.logs,
                          scrollController: _logScrollController,
                          onClear: () => _bleService.clearLogs(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Footer Note
              Center(
                child: Text(
                  'Open DIZO BLE Protocol Client\n100% Local · No cloud telemetry · Direct BLE GATT',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
