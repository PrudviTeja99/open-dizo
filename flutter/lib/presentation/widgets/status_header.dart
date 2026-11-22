import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/ble_service.dart';
import '../dialogs/connect_device_modal.dart';

class StatusHeader extends StatelessWidget {
  final BleService bleService;

  const StatusHeader({super.key, required this.bleService});

  @override
  Widget build(BuildContext context) {
    final isConnected = bleService.isConnected;
    final isConnecting = bleService.isConnecting;
    final isScanning = bleService.isScanning;
    final isSyncing = bleService.isSyncing;
    final isBusy = isConnecting || isScanning;

    final deviceName = isConnected
        ? (bleService.device?.platformName.isNotEmpty == true
            ? bleService.device!.platformName
            : (bleService.lastDeviceName ?? 'DIZO Watch D'))
        : (bleService.lastDeviceName ?? 'No Watch Connected');

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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isConnected ? AppTheme.accent.withValues(alpha: 0.35) : AppTheme.border,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Watch Avatar, Name, Status, Battery
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isConnected
                      ? AppTheme.accent.withValues(alpha: 0.15)
                      : AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isConnected ? AppTheme.accent.withValues(alpha: 0.4) : Colors.transparent,
                  ),
                ),
                child: Icon(
                  Icons.watch_rounded,
                  color: isConnected ? AppTheme.accent : Colors.grey[500],
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
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
                    const SizedBox(height: 4),
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
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isConnected && bleService.telemetry.battery != null) ...[
                          const SizedBox(width: 8),
                          Text('•', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          const SizedBox(width: 8),
                          Icon(Icons.battery_std, size: 13, color: Colors.grey[300]),
                          const SizedBox(width: 2),
                          Text(
                            '${bleService.telemetry.battery}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[300],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (isConnected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bluetooth_connected, size: 14, color: Colors.greenAccent),
                      SizedBox(width: 4),
                      Text(
                        'Active',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: AppTheme.border),
          const SizedBox(height: 14),

          // Labeled Action Buttons Row
          if (isConnected) ...[
            Row(
              children: [
                // Sync Now text button with spinner
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isSyncing ? null : () => bleService.syncAll(),
                    icon: isSyncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.sync, size: 18),
                    label: Text(
                      isSyncing ? 'Syncing...' : 'Sync Data',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Disconnect button
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isBusy ? null : () => bleService.disconnect(),
                    icon: const Icon(Icons.link_off, size: 16),
                    label: const Text(
                      'Disconnect',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // When Disconnected: Reconnect & Pair Options
            Row(
              children: [
                if (bleService.lastDeviceMac != null) ...[
                  // Reconnect Button
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isBusy
                          ? null
                          : () => bleService.connectByMacAddress(bleService.lastDeviceMac!),
                      icon: isBusy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.bolt, size: 18),
                      label: Text(
                        isBusy ? 'Connecting...' : 'Reconnect',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                // Pair / Switch Watch Button
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.cyanAccent,
                      side: BorderSide(color: Colors.cyanAccent.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isBusy ? null : () => ConnectDeviceModal.show(context, bleService),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(
                      bleService.lastDeviceMac != null ? 'Pair Another' : 'Connect Watch',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
