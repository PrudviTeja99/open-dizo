import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/ble_service.dart';

class StatusHeader extends StatelessWidget {
  final BleService bleService;

  const StatusHeader({super.key, required this.bleService});

  @override
  Widget build(BuildContext context) {
    final isConnected = bleService.isConnected;
    final isConnecting = bleService.isConnecting;
    final isScanning = bleService.isScanning;
    final deviceName = bleService.device?.platformName ?? 'Watch';

    Color statusColor;
    String statusText;

    if (isConnected) {
      statusColor = Colors.greenAccent;
      statusText = 'Connected — $deviceName';
    } else if (isConnecting) {
      statusColor = Colors.orangeAccent;
      statusText = 'Connecting...';
    } else if (isScanning) {
      statusColor = Colors.orangeAccent;
      statusText = 'Scanning...';
    } else {
      statusColor = Colors.redAccent;
      statusText = 'Disconnected';
    }

    return Column(
      children: [
        const Text('⌚', style: TextStyle(fontSize: 36)),
        const SizedBox(height: 4),
        const Text(
          'DIZO Watch D',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          'BLE Time Sync & Manager',
          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                  boxShadow: isConnected
                      ? [BoxShadow(color: Colors.greenAccent.withOpacity(0.5), blurRadius: 6)]
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                statusText,
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
