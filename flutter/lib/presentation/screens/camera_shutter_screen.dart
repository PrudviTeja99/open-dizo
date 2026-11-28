import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../services/ble_service.dart';

/// Remote Camera Shutter screen: puts the DIZO Watch D into camera shutter mode
/// and launches/triggers the phone camera when the watch sends shutter events.
class CameraShutterScreen extends StatefulWidget {
  final BleService bleService;

  const CameraShutterScreen({super.key, required this.bleService});

  @override
  State<CameraShutterScreen> createState() => _CameraShutterScreenState();
}

class _CameraShutterScreenState extends State<CameraShutterScreen> {
  static const MethodChannel _channel =
      MethodChannel('bpt.studiohq.open_dizo/notifications');

  bool _cameraLaunched = false;

  @override
  void initState() {
    super.initState();
    widget.bleService.setCameraMode(true);
    widget.bleService.cameraShutterCount.addListener(_onShutterChanged);
  }

  @override
  void dispose() {
    widget.bleService.cameraShutterCount.removeListener(_onShutterChanged);
    widget.bleService.setCameraMode(false);
    super.dispose();
  }

  void _onShutterChanged() {
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Watch shutter triggered (#${widget.bleService.cameraShutterCount.value})',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _openPhoneCamera() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('openCamera');
      if (mounted) {
        setState(() => _cameraLaunched = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open camera: $e'),
            backgroundColor: AppTheme.heartRate,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.bleService.isConnected;
    final count = widget.bleService.cameraShutterCount.value;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Remote Camera Shutter'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.accent.withValues(alpha: 0.45),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  size: 52,
                  color: AppTheme.accent,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Watch Remote Camera',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isConnected
                    ? 'Camera mode is active on your DIZO Watch D. Tap the shutter icon or shake your wrist to snap a photo.'
                    : 'Connect your watch first, then open your phone camera.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Shutter Triggers Received',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.accent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: const Color(0xFF0A0C10),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.photo_camera_rounded),
                  label: Text(
                    _cameraLaunched ? 'Re-open Phone Camera' : 'Open Phone Camera',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  onPressed: _openPhoneCamera,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Exit Camera Mode',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
