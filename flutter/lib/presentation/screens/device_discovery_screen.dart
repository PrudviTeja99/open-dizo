import 'package:flutter/material.dart';

import '../../models/discovered_device.dart';
import '../../services/ble_service.dart';

class DeviceDiscoveryScreen extends StatefulWidget {
  final BleService bleService;

  const DeviceDiscoveryScreen({super.key, required this.bleService});

  @override
  State<DeviceDiscoveryScreen> createState() => _DeviceDiscoveryScreenState();
}

class _DeviceDiscoveryScreenState extends State<DeviceDiscoveryScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  String? _connectingMac;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Start discovery scan immediately on entering screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.bleService.isScanning) {
        widget.bleService.startDiscoveryScan();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    widget.bleService.stopDiscoveryScan();
    super.dispose();
  }

  Future<void> _connectToDevice(DiscoveredDevice item) async {
    setState(() {
      _connectingMac = item.mac;
    });

    widget.bleService.stopDiscoveryScan();

    final success = await widget.bleService.connectByMacAddress(
      item.mac,
      displayName: item.name,
    );

    if (!mounted) return;

    setState(() {
      _connectingMac = null;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected to ${item.name}!'),
          backgroundColor: Colors.green.shade800,
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to connect to ${item.name} (${item.mac})'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  Widget _buildRssiBadge(DiscoveredDevice item) {
    Color color;
    String label;
    IconData icon;

    switch (item.signalTier) {
      case SignalTier.strong:
        color = Colors.greenAccent;
        label = '${item.rssi} dBm (Strong)';
        icon = Icons.signal_cellular_alt;
        break;
      case SignalTier.medium:
        color = Colors.amberAccent;
        label = '${item.rssi} dBm (Good)';
        icon = Icons.signal_cellular_alt_2_bar;
        break;
      case SignalTier.weak:
        color = Colors.orangeAccent;
        label = '${item.rssi} dBm (Weak)';
        icon = Icons.signal_cellular_alt_1_bar;
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.bleService,
      builder: (context, _) {
        final isScanning = widget.bleService.isScanning;
        final devices = widget.bleService.discoveredDevices;
        final dizoDevices = devices.where((d) => d.isDizo).toList();
        final otherDevices = devices.where((d) => !d.isDizo).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Search Nearby Watches'),
            actions: [
              if (isScanning)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Rescan',
                  onPressed: () => widget.bleService.startDiscoveryScan(),
                ),
            ],
          ),
          body: Column(
            children: [
              // Radar banner when actively scanning
              if (isScanning)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.cyan.withValues(alpha: 0.08),
                  child: Row(
                    children: [
                      RotationTransition(
                        turns: _pulseController,
                        child: const Icon(Icons.radar, color: Colors.cyanAccent, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Searching for Bluetooth advertisements...\nKeep your watch awake and close by.',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ),
                      TextButton(
                        onPressed: () => widget.bleService.stopDiscoveryScan(),
                        child: const Text('Stop', style: TextStyle(color: Colors.cyanAccent)),
                      ),
                    ],
                  ),
                ),

              // Empty State
              if (devices.isEmpty)
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.watch_later_outlined,
                            size: 64,
                            color: Colors.white24,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isScanning
                                ? 'Scanning for nearby smartwatches...'
                                : 'No smartwatches detected yet',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Make sure your DIZO Watch D is turned on, has Bluetooth enabled, and is within 1–2 meters.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Colors.white60),
                          ),
                          const SizedBox(height: 24),
                          if (!isScanning)
                            FilledButton.icon(
                              icon: const Icon(Icons.refresh),
                              label: const Text('Scan Again'),
                              onPressed: () => widget.bleService.startDiscoveryScan(),
                            ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                // Device List
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (dizoDevices.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(left: 4, bottom: 8),
                          child: Text(
                            'COMPATIBLE WATCHES',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: Colors.cyanAccent,
                            ),
                          ),
                        ),
                        ...dizoDevices.map((d) => _buildDeviceCard(d, isProminent: true)),
                        const SizedBox(height: 16),
                      ],
                      if (otherDevices.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(left: 4, bottom: 8),
                          child: Text(
                            'OTHER NEARBY DEVICES',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: Colors.white38,
                            ),
                          ),
                        ),
                        ...otherDevices.map((d) => _buildDeviceCard(d, isProminent: false)),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeviceCard(DiscoveredDevice item, {required bool isProminent}) {
    final isTargetConnecting = _connectingMac == item.mac;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: isProminent ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isProminent ? Colors.cyanAccent.withValues(alpha: 0.4) : Colors.white12,
          width: isProminent ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isProminent ? Colors.cyan.withValues(alpha: 0.15) : Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isProminent ? Icons.watch : Icons.bluetooth,
                color: isProminent ? Colors.cyanAccent : Colors.white70,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),

            // Name and Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isProminent ? Colors.white : Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.mac,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildRssiBadge(item),
                ],
              ),
            ),

            // Connect Action
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: isProminent ? Colors.cyanAccent : Colors.white24,
                foregroundColor: isProminent ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: isTargetConnecting ? null : () => _connectToDevice(item),
              child: isTargetConnecting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Text('Connect', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
