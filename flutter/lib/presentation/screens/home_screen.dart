import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/ble_service.dart';
import '../widgets/status_header.dart';
import '../widgets/actions_card.dart';
import '../widgets/telemetry_card.dart';
import 'dial_studio_screen.dart';
import '../dialogs/connect_device_modal.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final BleService _bleService;

  @override
  void initState() {
    super.initState();
    _bleService = BleService();
    _bleService.addListener(_onServiceUpdate);
  }

  void _onServiceUpdate() {
    setState(() {});
  }

  @override
  void dispose() {
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
        title: const Row(
          children: [
            Icon(Icons.watch_rounded, color: AppTheme.accent, size: 22),
            SizedBox(width: 8),
            Text(
              'DIZO Companion',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Pair / Switch Device',
            icon: const Icon(Icons.devices_rounded, size: 22, color: AppTheme.accent),
            onPressed: isBusy ? null : () => ConnectDeviceModal.show(context, _bleService),
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
              // 1. Device Status Card with Clear Labeled Actions (Sync / Disconnect / Reconnect / Pair)
              StatusHeader(bleService: _bleService),
              const SizedBox(height: 14),

              // 2. Central Health & Activity Metrics Display (Hero Activity + Vitals Grid)
              TelemetryCard(
                telemetry: _bleService.telemetry,
                isConnected: isConnected,
                isSyncing: _bleService.isSyncing,
                onRefresh: () => _bleService.syncAll(),
              ),
              const SizedBox(height: 14),

              // 3. Watch Face Studio Banner Card
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

              // 4. Quick Tools Bar (Vibrate / Find Watch & Full Sync)
              ActionsCard(bleService: _bleService),
              const SizedBox(height: 24),

              // 5. Clean Footer
              Center(
                child: Text(
                  'Open DIZO BLE Companion\n100% Local · No cloud telemetry · Direct BLE GATT',
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
