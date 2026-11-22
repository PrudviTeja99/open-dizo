import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../models/clock_style.dart';
import '../../models/wallpaper_item.dart';
import '../../services/ble_service.dart';
import '../../services/wallpaper_storage_service.dart';
import '../../services/dial_builder_service.dart';
import '../../services/dfu_flasher_service.dart';
import '../widgets/watch_canvas_preview.dart';
import 'image_adjust_screen.dart';

class DialStudioScreen extends StatefulWidget {
  final BleService bleService;

  const DialStudioScreen({super.key, required this.bleService});

  @override
  State<DialStudioScreen> createState() => _DialStudioScreenState();
}

class _DialStudioScreenState extends State<DialStudioScreen> {
  final WallpaperStorageService _storageService = WallpaperStorageService();
  WallpaperItem? _selectedWallpaper;
  ClockStyle _clockStyle = const ClockStyle(
    position: ClockPosition.bottom,
    textColor: Colors.white,
    showDate: true,
    showBattery: true,
    showSteps: true,
    showHeartRate: true,
  );

  bool _isLoading = true;

  final List<Color> _availableColors = const [
    Colors.white,
    Color(0xFF00E5FF), // Cyber Cyan
    Color(0xFFFFEA00), // Solar Yellow
    Color(0xFF00E676), // Emerald Green
    Color(0xFFFF4081), // Neon Pink
    Color(0xFFB388FF), // Lavender
  ];

  @override
  void initState() {
    super.initState();
    _initStorage();
  }

  Future<void> _initStorage() async {
    await _storageService.init();
    if (_storageService.items.isNotEmpty) {
      _selectedWallpaper = _storageService.items.first;
    }
    setState(() => _isLoading = false);
  }

  Future<void> _pickNewWallpaper() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final rawFile = File(result.files.single.path!);

        if (!mounted) return;

        // Open interactive zoom & crop screen
        final WallpaperItem? savedItem = await Navigator.of(context).push<WallpaperItem>(
          MaterialPageRoute(
            builder: (_) => ImageAdjustScreen(
              rawImageFile: rawFile,
              storageService: _storageService,
            ),
          ),
        );

        if (savedItem != null && mounted) {
          setState(() {
            _selectedWallpaper = savedItem;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmAndFlash() async {
    if (!widget.bleService.isConnected || widget.bleService.device == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please connect to DIZO Watch D first before flashing.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedWallpaper == null || !_selectedWallpaper!.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or upload a wallpaper first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final bool? proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Flash Custom Watch Face?'),
        content: const Text(
          'This will stream and flash your custom wallpaper dial directly to your DIZO Watch D over BLE. '
          'Please keep your watch nearby and do not close the app during the update.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
            child: const Text('Start Flashing', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (proceed != true || !mounted) return;

    // Start packaging and flashing
    _executeFlashSession();
  }

  void _executeFlashSession() {
    double progressValue = 0.0;
    String statusText = 'Packaging watch face binary...';
    double speedValue = 0.0;
    bool isCompleted = false;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Text('⚡ Flashing Dial', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (isCompleted)
                    const Icon(Icons.check_circle, color: Colors.greenAccent)
                  else if (errorMessage != null)
                    const Icon(Icons.error, color: Colors.redAccent)
                  else
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                    ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: progressValue,
                    backgroundColor: Colors.grey[800],
                    color: errorMessage != null ? Colors.redAccent : AppTheme.accent,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${(progressValue * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      if (speedValue > 0)
                        Text(
                          '${speedValue.toStringAsFixed(1)} KB/s',
                          style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    errorMessage ?? statusText,
                    style: TextStyle(
                      fontSize: 12,
                      color: errorMessage != null ? Colors.redAccent : Colors.grey[400],
                    ),
                  ),
                ],
              ),
              actions: [
                if (isCompleted || errorMessage != null)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      if (isCompleted) {
                        Navigator.of(context).pop(); // Return to dashboard
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                    child: Text(isCompleted ? 'Done' : 'Close', style: const TextStyle(color: Colors.white)),
                  ),
              ],
            );
          },
        );
      },
    );

    // Run async background packaging & flashing
    Future.microtask(() async {
      try {
        final Uint8List wallpaperBytes = await File(_selectedWallpaper!.filePath).readAsBytes();

        // 1. Build custom dial binary with clock positioning and CRC
        final Uint8List dialBinary = await DialBuilderService.buildDialBinary(
          wallpaperPngBytes: wallpaperBytes,
          clockPosition: _clockStyle.position,
        );

        // 2. Stream and flash via Realtek DFU over BLE
        await DfuFlasherService.flashDialBinary(
          device: widget.bleService.device!,
          dialBinary: dialBinary,
          onProgress: (prog, sent, total, speed, msg) {
            // Update dialog state
            (context as Element).visitChildren((element) {
              element.markNeedsBuild();
            });
          },
        );

        // Success
        isCompleted = true;
        statusText = 'Watch face flashed and activated successfully!';
        if (mounted) setState(() {});
      } catch (e) {
        errorMessage = 'Flashing error: $e';
        if (mounted) setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      );
    }

    final File? currentWallpaperFile =
        _selectedWallpaper != null ? File(_selectedWallpaper!.filePath) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Watch Face Studio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                children: [
                  // Live Watch Frame Preview
                  WatchCanvasPreview(
                    wallpaperFile: currentWallpaperFile,
                    clockStyle: _clockStyle,
                    scale: 0.95,
                  ),
                  const SizedBox(height: 20),

                  // Section 1: Wallpaper Library & Custom Picker
                  _buildSectionHeader('🖼️  WALLPAPER'),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 92,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        // Pick New Photo Tile
                        GestureDetector(
                          onTap: _pickNewWallpaper,
                          child: Container(
                            width: 76,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.accent.withOpacity(0.5), width: 1.5),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined, color: AppTheme.accent, size: 28),
                                const SizedBox(height: 4),
                                const Text('New', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),

                        // Saved Wallpapers History Carousel
                        ..._storageService.items.map((item) {
                          final isSelected = _selectedWallpaper?.id == item.id;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedWallpaper = item),
                            onLongPress: () => _confirmDeleteWallpaper(item),
                            child: Container(
                              width: 76,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? AppTheme.accent : AppTheme.border,
                                  width: isSelected ? 3 : 1,
                                ),
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(11),
                                    child: Image.file(
                                      File(item.filePath),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  if (isSelected)
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppTheme.accent,
                                        ),
                                        child: const Icon(Icons.check, size: 14, color: Colors.white),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Section 2: Clock Position
                  _buildSectionHeader('📍  CLOCK POSITION'),
                  const SizedBox(height: 10),
                  Row(
                    children: ClockPosition.values.map((pos) {
                      final isSelected = _clockStyle.position == pos;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(pos.label),
                            selected: isSelected,
                            selectedColor: AppTheme.accent,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey[400],
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                            onSelected: (_) => setState(() {
                              _clockStyle = _clockStyle.copyWith(position: pos);
                            }),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Section 3: Text & Accent Color
                  _buildSectionHeader('🎨  TEXT COLOR'),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: _availableColors.map((color) {
                      final isSelected = _clockStyle.textColor.value == color.value;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _clockStyle = _clockStyle.copyWith(textColor: color);
                        }),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: isSelected
                                ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 8)]
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Section 4: Complications & Widgets
                  _buildSectionHeader('📊  COMPLICATIONS'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('📅 Date'),
                        selected: _clockStyle.showDate,
                        onSelected: (val) => setState(() {
                          _clockStyle = _clockStyle.copyWith(showDate: val);
                        }),
                      ),
                      FilterChip(
                        label: const Text('🔋 Battery'),
                        selected: _clockStyle.showBattery,
                        onSelected: (val) => setState(() {
                          _clockStyle = _clockStyle.copyWith(showBattery: val);
                        }),
                      ),
                      FilterChip(
                        label: const Text('🚶 Steps'),
                        selected: _clockStyle.showSteps,
                        onSelected: (val) => setState(() {
                          _clockStyle = _clockStyle.copyWith(showSteps: val);
                        }),
                      ),
                      FilterChip(
                        label: const Text('❤️ Heart Rate'),
                        selected: _clockStyle.showHeartRate,
                        onSelected: (val) => setState(() {
                          _clockStyle = _clockStyle.copyWith(showHeartRate: val);
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),

            // Bottom Action Bar: Cancel & Confirm
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
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
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _confirmAndFlash,
                      icon: const Icon(Icons.flash_on),
                      label: const Text('Confirm & Flash'),
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

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        letterSpacing: 1.5,
        color: Colors.grey[500],
        fontWeight: FontWeight.w600,
      ),
    );
  }

  void _confirmDeleteWallpaper(WallpaperItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete Wallpaper?'),
        content: const Text('Do you want to remove this wallpaper from your saved library?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _storageService.deleteWallpaper(item);
              if (_selectedWallpaper?.id == item.id) {
                setState(() {
                  _selectedWallpaper =
                      _storageService.items.isNotEmpty ? _storageService.items.first : null;
                });
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
