import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/app_update_service.dart';

class AppUpdateDialog extends StatefulWidget {
  const AppUpdateDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const AppUpdateDialog(),
    );
  }

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  bool _isChecking = true;
  String? _errorMessage;
  AppReleaseInfo? _releaseInfo;

  // Download state
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  File? _downloadedFile;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _isChecking = true;
      _errorMessage = null;
    });

    try {
      final info = await AppUpdateService.checkForUpdate();
      if (!mounted) return;
      setState(() {
        _isChecking = false;
        _releaseInfo = info;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isChecking = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _startDownloadAndInstall() async {
    if (_releaseInfo == null) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _errorMessage = null;
    });

    try {
      final file = await AppUpdateService.downloadApk(
        downloadUrl: _releaseInfo!.apkDownloadUrl,
        fileName: _releaseInfo!.apkFileName,
        onProgress: (prog, received, total) {
          if (mounted) {
            setState(() {
              _downloadProgress = prog;
              _receivedBytes = received;
              _totalBytes = total;
            });
          }
        },
      );

      if (!mounted) return;
      setState(() {
        _downloadedFile = file;
        _isDownloading = false;
      });

      // Automatically trigger package installer
      await AppUpdateService.installApk(file.path);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _errorMessage = 'Download/Install failed: ${e.toString().replaceAll('Exception: ', '')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.system_update_alt_rounded, color: AppTheme.accent, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'App Updates',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _buildContent(),
      ),
      actions: _buildActions(),
    );
  }

  Widget _buildContent() {
    if (_isChecking) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppTheme.accent),
            const SizedBox(height: 16),
            Text(
              'Checking GitHub Releases...',
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Current: v${AppUpdateService.currentVersion}',
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.orangeAccent, size: 40),
            const SizedBox(height: 12),
            Text(
              'Unable to Check Updates',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (_isDownloading) {
      final receivedMb = (_receivedBytes / (1024 * 1024)).toStringAsFixed(1);
      final totalMb = (_totalBytes / (1024 * 1024)).toStringAsFixed(1);
      final percent = (_downloadProgress * 100).toStringAsFixed(0);

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Downloading APK...',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  '$percent%',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accent),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _downloadProgress > 0 ? _downloadProgress : null,
                minHeight: 8,
                backgroundColor: AppTheme.surfaceLight,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$receivedMb MB of $totalMb MB',
              style: TextStyle(color: Colors.grey[400], fontSize: 11),
            ),
          ],
        ),
      );
    }

    if (_downloadedFile != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, color: Color(0xFF00E676), size: 44),
            const SizedBox(height: 12),
            const Text(
              'Download Complete!',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              'Installer launched. Tap below if installation did not start automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (_releaseInfo != null) {
      final hasUpdate = _releaseInfo!.isNewerVersion;
      final sizeMb = (_releaseInfo!.apkSizeBytes / (1024 * 1024)).toStringAsFixed(1);

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasUpdate ? Icons.new_releases : Icons.verified,
                color: hasUpdate ? AppTheme.accent : const Color(0xFF00E676),
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasUpdate ? 'Update Available!' : 'App is Up to Date',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      'Latest: ${_releaseInfo!.tagName} · Installed: v${AppUpdateService.currentVersion}',
                      style: TextStyle(color: Colors.grey[400], fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _releaseInfo!.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                    ),
                    Text(
                      '$sizeMb MB',
                      style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Text(
                  'Release Notes:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[400]),
                ),
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: SingleChildScrollView(
                    child: Text(
                      _releaseInfo!.releaseNotes,
                      style: const TextStyle(fontSize: 12, height: 1.3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  List<Widget> _buildActions() {
    if (_isChecking || _isDownloading) {
      return [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Dismiss', style: TextStyle(color: Colors.grey)),
        ),
      ];
    }

    if (_errorMessage != null) {
      return [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _check,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
          child: const Text('Try Again', style: TextStyle(color: Colors.white)),
        ),
      ];
    }

    if (_downloadedFile != null) {
      return [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () => AppUpdateService.installApk(_downloadedFile!.path),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
          child: const Text('Re-open Installer', style: TextStyle(color: Colors.white)),
        ),
      ];
    }

    if (_releaseInfo != null) {
      if (_releaseInfo!.isNewerVersion) {
        return [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: _startDownloadAndInstall,
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Download & Install'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
          ),
        ];
      } else {
        return [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: _startDownloadAndInstall,
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Re-install'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.surfaceLight),
          ),
        ];
      }
    }

    return [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Close', style: TextStyle(color: Colors.grey)),
      ),
    ];
  }
}
