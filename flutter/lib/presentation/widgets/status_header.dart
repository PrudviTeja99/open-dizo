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
    final isSyncing = bleService.isSyncing;
    final deviceName = bleService.device?.platformName.isNotEmpty == true
        ? bleService.device!.platformName
        : (bleService.lastDeviceName ?? 'DIZO Watch D');

    Color statusColor;
    String statusText;

    if (isConnected) {
      statusColor = Colors.greenAccent;
      statusText = 'Connected';
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          // Watch Icon / Avatar
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.watch_outlined, color: AppTheme.accent, size: 24),
          ),
          const SizedBox(width: 14),

          // Device Name & Status Pill
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deviceName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor,
                        boxShadow: isConnected
                            ? [
                                BoxShadow(
                                  color: Colors.greenAccent.withValues(alpha: 0.6),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                )
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12,
                        color: isConnected ? Colors.greenAccent : Colors.grey[400],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (isConnected && bleService.telemetry.battery != null) ...[
                      const SizedBox(width: 8),
                      Text('•', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      const SizedBox(width: 8),
                      Icon(Icons.battery_std, size: 13, color: Colors.grey[400]),
                      Text(
                        '${bleService.telemetry.battery}%',
                        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Single Sync All Icon Button with Loading Spinner
          if (isConnected)
            IconButton(
              tooltip: 'Sync Watch Data',
              icon: isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                    )
                  : const Icon(Icons.sync, color: AppTheme.accent, size: 22),
              onPressed: isSyncing ? null : () => bleService.syncAll(),
            ),
        ],
      ),
    );
  }
}
