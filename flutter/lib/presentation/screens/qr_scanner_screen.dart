import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/utils/watch_qr_parser.dart';
import '../../models/log_entry.dart';
import '../../services/ble_service.dart';

class QrScannerScreen extends StatefulWidget {
  final BleService bleService;

  const QrScannerScreen({super.key, required this.bleService});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with SingleTickerProviderStateMixin {
  MobileScannerController? _controller;
  bool _isCameraInitialized = false;
  bool _permissionDenied = false;
  bool _hasScanned = false;
  bool _isConnecting = false;

  late final AnimationController _animController;
  late final Animation<double> _scanAnimation;
  final TextEditingController _manualMacController = TextEditingController();

  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    if (_isMobile) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        setState(() {
          _permissionDenied = true;
        });
      }
      return;
    }

    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      returnImage: false,
    );

    if (mounted) {
      setState(() {
        _isCameraInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _manualMacController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned || _isConnecting) return;

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.isNotEmpty) {
        _handleQrResult(rawValue);
        break;
      }
    }
  }

  Future<void> _handleQrResult(String rawText) async {
    setState(() {
      _hasScanned = true;
    });

    final payload = WatchQrParser.parse(rawText);

    if (!payload.isValid || payload.mac == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unrecognized QR: "$rawText". Please scan the watch pairing code.',
          ),
          backgroundColor: Colors.amber.shade900,
          action: SnackBarAction(
            label: 'Try Again',
            textColor: Colors.white,
            onPressed: () {
              if (mounted) setState(() => _hasScanned = false);
            },
          ),
        ),
      );
      return;
    }

    // Valid watch payload found!
    setState(() {
      _isConnecting = true;
    });

    widget.bleService.log(
      'QR Scanned: ${payload.name ?? "DIZO Watch"} [${payload.mac}]',
      type: LogType.success,
    );

    // Stop camera while connecting
    _controller?.stop();

    final success = await widget.bleService.connectByMacAddress(
      payload.mac!,
      displayName: payload.name,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected to ${payload.name ?? "Watch"}!'),
          backgroundColor: Colors.green.shade800,
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isConnecting = false;
        _hasScanned = false;
      });
      _controller?.start();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to connect to ${payload.mac}. Ensure watch is awake.'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  void _showManualEntryDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Watch MAC Address'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the MAC address or raw QR payload shown on your watch:',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _manualMacController,
              autofocus: true,
              style: const TextStyle(fontFamily: 'monospace', letterSpacing: 1.2),
              decoration: const InputDecoration(
                hintText: 'e.g. CC:EA:FF:AA:42:7F',
                prefixIcon: Icon(Icons.bluetooth),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = _manualMacController.text.trim();
              Navigator.of(ctx).pop();
              if (text.isNotEmpty) {
                _handleQrResult(text);
              }
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Watch QR Code'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_isMobile && _controller != null) ...[
            ValueListenableBuilder<MobileScannerState>(
              valueListenable: _controller!,
              builder: (context, state, child) {
                final isOn = state.torchState == TorchState.on;
                return IconButton(
                  icon: Icon(isOn ? Icons.flash_on : Icons.flash_off),
                  tooltip: isOn ? 'Turn Off Flash' : 'Turn On Flash',
                  onPressed: () => _controller!.toggleTorch(),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.cameraswitch_outlined),
              tooltip: 'Switch Camera',
              onPressed: () => _controller!.switchCamera(),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.keyboard),
            tooltip: 'Enter MAC Manually',
            onPressed: _showManualEntryDialog,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_isMobile) {
      return _buildDesktopFallback();
    }

    if (_permissionDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off, size: 64, color: Colors.orangeAccent),
              const SizedBox(height: 16),
              const Text(
                'Camera Permission Required',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Open-DIZO needs camera access to scan the pairing QR code displayed on your watch screen.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.settings),
                label: const Text('Open Settings'),
                onPressed: () => openAppSettings(),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.keyboard),
                label: const Text('Enter MAC Address Manually'),
                onPressed: _showManualEntryDialog,
              ),
            ],
          ),
        ),
      );
    }

    if (!_isCameraInitialized || _controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        // Camera Viewfinder
        MobileScanner(
          controller: _controller!,
          onDetect: _onDetect,
        ),

        // Darkened overlay with clear viewfinder cutout
        LayoutBuilder(
          builder: (context, constraints) {
            final scanBoxSize = constraints.maxWidth * 0.72;
            return Stack(
              children: [
                ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.65),
                    BlendMode.srcOut,
                  ),
                  child: Stack(
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          backgroundBlendMode: BlendMode.dstOut,
                        ),
                      ),
                      Align(
                        alignment: Alignment.center,
                        child: Container(
                          width: scanBoxSize,
                          height: scanBoxSize,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Corner framing brackets
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: scanBoxSize,
                    height: scanBoxSize,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.cyanAccent, width: 2.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: AnimatedBuilder(
                      animation: _scanAnimation,
                      builder: (context, child) {
                        return Align(
                          alignment: FractionalOffset(0.5, _scanAnimation.value),
                          child: Container(
                            height: 2.5,
                            width: scanBoxSize * 0.88,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.cyanAccent,
                                  Colors.white,
                                  Colors.cyanAccent,
                                  Colors.transparent,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.cyanAccent.withValues(alpha: 0.8),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Instructional Guide at Top
                Positioned(
                  top: 36,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code, color: Colors.cyanAccent, size: 20),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Align watch screen QR code inside the box',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Connecting overlay indicator
                if (_isConnecting)
                  Container(
                    color: Colors.black.withValues(alpha: 0.75),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E2E),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.cyanAccent),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Colors.cyanAccent),
                            SizedBox(height: 16),
                            Text(
                              'Connecting to Watch...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Initializing Bluetooth LE services',
                              style: TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildDesktopFallback() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28.0),
        child: Container(
          constraints: const Duration(milliseconds: 0) == Duration.zero
              ? const BoxConstraints(maxWidth: 480)
              : null,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.qr_code_scanner, size: 72, color: Colors.cyanAccent),
              const SizedBox(height: 16),
              const Text(
                'Direct Watch Pairing',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'Camera viewfinder scanning is enabled on Android.\nOn Linux desktop, enter your watch MAC address or raw QR payload below to connect instantly:',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _manualMacController,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Watch MAC or QR text',
                  hintText: 'CC:EA:FF:AA:42:7F',
                  prefixIcon: const Icon(Icons.bluetooth),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: _isConnecting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.link),
                  label: Text(_isConnecting ? 'Connecting...' : 'Connect to Watch'),
                  onPressed: _isConnecting
                      ? null
                      : () {
                          final text = _manualMacController.text.trim();
                          if (text.isNotEmpty) {
                            _handleQrResult(text);
                          }
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
