import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../core/theme/app_theme.dart';
import '../../models/wallpaper_item.dart';
import '../../services/wallpaper_storage_service.dart';

/// Screen allowing the user to zoom in/out, pan, and crop an image to 240x286
class ImageAdjustScreen extends StatefulWidget {
  final File rawImageFile;
  final WallpaperStorageService storageService;

  const ImageAdjustScreen({
    super.key,
    required this.rawImageFile,
    required this.storageService,
  });

  @override
  State<ImageAdjustScreen> createState() => _ImageAdjustScreenState();
}

class _ImageAdjustScreenState extends State<ImageAdjustScreen> {
  final GlobalKey _cropKey = GlobalKey();
  final TransformationController _transformController = TransformationController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _zoom(double factor) {
    final matrix = _transformController.value.clone();
    matrix.scale(factor, factor);
    _transformController.value = matrix;
  }

  void _resetTransform() {
    _transformController.value = Matrix4.identity();
  }

  Future<void> _captureAndSave() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final boundary = _cropKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Render boundary not found');
      }

      // 240 display width * pixelRatio = exact 240 pixels width
      const double targetWidth = 240.0;
      final double logicalWidth = boundary.size.width;
      final double pixelRatio = targetWidth / logicalWidth;

      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Failed to encode cropped image to bytes');
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // Save single optimized 240x286 image to app storage
      final WallpaperItem item = await widget.storageService.saveProcessedWallpaper(pngBytes);

      if (mounted) {
        Navigator.of(context).pop(item);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to crop wallpaper: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const double dialW = 240.0;
    const double dialH = 286.0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Adjust Wallpaper', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Reset Framing',
            onPressed: _resetTransform,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Pinch to zoom in/out or drag to fit your wallpaper to the watch display.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),

            // Viewport & Cropping Window
            Expanded(
              child: Center(
                child: Container(
                  width: dialW,
                  height: dialH,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.accent, width: 2),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withOpacity(0.3),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: RepaintBoundary(
                      key: _cropKey,
                      child: Container(
                        width: dialW,
                        height: dialH,
                        color: Colors.black,
                        child: InteractiveViewer(
                          transformationController: _transformController,
                          minScale: 0.5,
                          maxScale: 5.0,
                          boundaryMargin: const EdgeInsets.all(double.infinity),
                          child: Image.file(
                            widget.rawImageFile,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Zoom Controls Toolbar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    onPressed: () => _zoom(0.85),
                    icon: const Icon(Icons.zoom_out),
                    tooltip: 'Zoom Out',
                  ),
                  const SizedBox(width: 20),
                  IconButton.filledTonal(
                    onPressed: () => _zoom(1.15),
                    icon: const Icon(Icons.zoom_in),
                    tooltip: 'Zoom In',
                  ),
                ],
              ),
            ),

            // Bottom Action Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: Colors.grey[700]!),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _captureAndSave,
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check),
                      label: Text(_isProcessing ? 'Saving...' : 'Confirm & Fit'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
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
