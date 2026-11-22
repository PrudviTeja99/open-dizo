import 'package:flutter/material.dart';

import '../../services/ble_service.dart';
import '../screens/device_discovery_screen.dart';
import '../screens/qr_scanner_screen.dart';

class ConnectDeviceModal extends StatelessWidget {
  final BleService bleService;

  const ConnectDeviceModal({super.key, required this.bleService});

  static Future<void> show(BuildContext context, BleService bleService) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => ConnectDeviceModal(bleService: bleService),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.cyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.watch, color: Colors.cyanAccent, size: 24),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connect Watch',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Select a method to pair with your watch',
                      style: TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Option 1: Scan QR Code
            _buildOptionCard(
              context: context,
              icon: Icons.qr_code_scanner,
              iconColor: Colors.cyanAccent,
              title: 'Scan QR Code',
              subtitle: 'Scan the pairing QR code displayed on the watch screen',
              badge: 'RECOMMENDED',
              badgeColor: Colors.cyanAccent,
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => QrScannerScreen(bleService: bleService),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Option 2: Search Nearby Devices
            _buildOptionCard(
              context: context,
              icon: Icons.bluetooth_searching,
              iconColor: Colors.blueAccent,
              title: 'Search Nearby Devices',
              subtitle: 'Scan BLE advertisements and pick your watch from a list',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        DeviceDiscoveryScreen(bleService: bleService),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Option 3: Quick Auto-Connect
            _buildOptionCard(
              context: context,
              icon: Icons.bolt,
              iconColor: Colors.amberAccent,
              title: 'Quick Auto-Connect',
              subtitle: 'Automatically connect to the nearest active DIZO Watch D',
              onTap: () {
                Navigator.of(context).pop();
                bleService.scanAndConnect();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    String? badge,
    Color? badgeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: (badgeColor ?? Colors.cyanAccent)
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: (badgeColor ?? Colors.cyanAccent)
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: badgeColor ?? Colors.cyanAccent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}
