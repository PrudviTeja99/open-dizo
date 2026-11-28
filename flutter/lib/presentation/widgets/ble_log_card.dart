import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/log_entry.dart';

class BleLogCard extends StatelessWidget {
  final List<LogEntry> logs;
  final ScrollController scrollController;
  final VoidCallback onClear;
  final VoidCallback? onCopy;
  final VoidCallback? onExport;

  const BleLogCard({
    super.key,
    required this.logs,
    required this.scrollController,
    required this.onClear,
    this.onCopy,
    this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'BLE LOG (${logs.length})',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w700,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onCopy != null)
                    IconButton(
                      tooltip: 'Copy Logs',
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      icon: const Icon(Icons.copy_rounded, size: 17, color: AppTheme.textSecondary),
                      onPressed: logs.isEmpty ? null : onCopy,
                    ),
                  if (onExport != null)
                    IconButton(
                      tooltip: 'Export .txt',
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      icon: const Icon(Icons.share_rounded, size: 17, color: AppTheme.accent),
                      onPressed: logs.isEmpty ? null : onExport,
                    ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: logs.isEmpty ? null : onClear,
                    child: Text(
                      'Clear',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: logs.isEmpty ? Colors.grey[700] : Colors.grey[400],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.terminalBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: logs.isEmpty
                ? const Center(
                    child: Text(
                      'No BLE events logged yet.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(10),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final entry = logs[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '[${entry.time}] ',
                                style: TextStyle(color: Colors.grey[700], fontSize: 11),
                              ),
                              TextSpan(
                                text: entry.message,
                                style: TextStyle(color: entry.color, fontSize: 11),
                              ),
                            ],
                          ),
                          style: const TextStyle(fontFamily: 'monospace', height: 1.5),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
