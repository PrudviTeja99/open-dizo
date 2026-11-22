import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/ble_service.dart';

class ActionsCard extends StatelessWidget {
  final BleService bleService;

  const ActionsCard({super.key, required this.bleService});

  @override
  Widget build(BuildContext context) {
    final isConnected = bleService.isConnected;
    final isSyncing = bleService.isSyncing;

    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'QUICK TOOLS',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: Colors.grey[400],
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (isConnected)
                Row(
                  children: [
                    const Icon(Icons.bolt, size: 13, color: Colors.amberAccent),
                    const SizedBox(width: 4),
                    Text(
                      'Auto-sync: Active (60s)',
                      style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Find Watch (Vibrate)
              Expanded(
                child: _toolTile(
                  icon: Icons.vibration,
                  color: Colors.amberAccent,
                  title: 'Find Watch',
                  subtitle: 'Vibrate band',
                  enabled: isConnected,
                  onTap: () {
                    bleService.findWatch();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Vibrating DIZO Watch D...'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              // Unified Sync
              Expanded(
                child: _toolTile(
                  icon: isSyncing ? Icons.hourglass_top : Icons.sync,
                  color: AppTheme.accent,
                  title: isSyncing ? 'Syncing...' : 'Sync Now',
                  subtitle: 'Refresh all vitals',
                  enabled: isConnected && !isSyncing,
                  onTap: () => bleService.syncAll(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toolTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: enabled ? color.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: enabled ? color : Colors.grey, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: enabled ? Colors.white : Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: enabled ? Colors.grey[400] : Colors.grey[700],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
