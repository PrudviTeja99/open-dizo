import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../models/clock_style.dart';
import '../../models/log_entry.dart';
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
    position: ClockPosition.center,
    size: ClockSize.standard,
    isVisible: true,
    textColor: Colors.white,
    showDate: true,
    showBattery: true,
    showSteps: true,
    showHeartRate: true,
  );

  bool _isLoading = true;
  bool _isDraggingClock = false;

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
    StateSetter? updateDialog;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            updateDialog = setDialogState;
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

        // 1. Build custom dial binary with clock positioning, style, color and CRC
        final Uint8List dialBinary = await DialBuilderService.buildDialBinary(
          wallpaperPngBytes: wallpaperBytes,
          clockPosition: _clockStyle.position,
          isClockVisible: _clockStyle.isVisible,
          textColor: _clockStyle.textColor,
          hardwareStyleIndex: _clockStyle.templateStyle.hardwareStyleIndex,
          clockWidth: _clockStyle.boxWidth.round(),
          clockHeight: _clockStyle.boxHeight.round(),
        );

        final watchDevice = widget.bleService.device;
        final watchMac = watchDevice?.remoteId.str;

        // 2. Stream and flash via Realtek DFU over BLE
        await DfuFlasherService.flashDialBinary(
          device: widget.bleService.device!,
          dialBinary: dialBinary,
          onProgress: (prog, sent, total, speed, msg) {
            progressValue = prog;
            speedValue = speed;
            statusText = msg;
            updateDialog?.call(() {});
          },
        );

        // 3. Post-DFU Watch Reconnection & Switch Dial (#4)
        if (watchMac != null) {
          statusText = 'Watch rebooting... Reconnecting in 4s...';
          updateDialog?.call(() {});
          await Future.delayed(const Duration(seconds: 4));
          statusText = 'Reconnecting to DIZO Watch D...';
          updateDialog?.call(() {});
          await widget.bleService.connectByMacAddress(watchMac);
          if (widget.bleService.isConnected) {
            statusText = 'Activating new custom watch face...';
            updateDialog?.call(() {});
            await Future.delayed(const Duration(milliseconds: 600));
            await widget.bleService.switchDial(4);
          }
        }

        // Success
        isCompleted = true;
        progressValue = 1.0;
        statusText = 'Watch face flashed and activated successfully!';
        widget.bleService.log('Watch face flashed & activated ✓', type: LogType.success);
        updateDialog?.call(() {});
      } catch (e, stack) {
        debugPrint('[DialStudio] Flashing error: $e\n$stack');
        widget.bleService.log('Flashing error: $e', type: LogType.error);
        errorMessage = 'Flashing error: $e';
        updateDialog?.call(() {});
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
                physics: _isDraggingClock
                    ? const NeverScrollableScrollPhysics()
                    : const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                children: [
                  // Live Watch Frame Preview (Hold to vibrate and drag)
                  WatchCanvasPreview(
                    wallpaperFile: currentWallpaperFile,
                    clockStyle: _clockStyle,
                    scale: 0.95,
                    onDragStateChanged: (dragging) => setState(() => _isDraggingClock = dragging),
                    onClockDragged: (newX, newY) => setState(() {
                      _clockStyle = _clockStyle.copyWith(
                        position: ClockPosition('Custom', newX, newY, isCustom: true),
                      );
                    }),
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
                              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.5), width: 1.5),
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

                  // Section 2: Clock Styles Carousel (like wallpaper gallery)
                  _buildSectionHeader('🎨  CLOCK STYLES'),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 114,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: ClockTemplateStyle.gallery.map((style) {
                        final isSelected = _clockStyle.templateStyle.id == style.id;
                        return GestureDetector(
                          onTap: () => setState(() {
                            final bool wasVertical = _clockStyle.isVertical;
                            final bool willBeVertical = style.isStacked;
                            _clockStyle = _clockStyle.copyWith(
                              templateStyle: style,
                              textColor: style.primaryColor,
                              isStacked: willBeVertical,
                            );
                            if (wasVertical != willBeVertical && !_clockStyle.position.isCustom) {
                              _clockStyle = _clockStyle.copyWith(
                                position: ClockPosition.getPresets(isVertical: willBeVertical).first,
                              );
                            }
                          }),
                          child: Container(
                            width: 96,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF161622),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? AppTheme.accent : AppTheme.border,
                                width: isSelected ? 2.5 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.accent.withValues(alpha: 0.35),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Stack(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Miniature Preview Box
                                      Container(
                                        height: 44,
                                        width: style.isStacked ? 38 : 68,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.6),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: style.primaryColor.withValues(alpha: 0.45),
                                            width: 1,
                                          ),
                                        ),
                                        child: Center(
                                          child: style.isStacked
                                              ? Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      '10',
                                                      style: _getMiniatureStyle(style, isHour: true),
                                                    ),
                                                    Text(
                                                      '08',
                                                      style: _getMiniatureStyle(style, isHour: false),
                                                    ),
                                                  ],
                                                )
                                              : Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text('10', style: _getMiniatureStyle(style, isHour: true)),
                                                    Text(':', style: _getMiniatureStyle(style, isHour: true)),
                                                    Text('08', style: _getMiniatureStyle(style, isHour: false)),
                                                  ],
                                                ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        style.name,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                          color: isSelected ? Colors.white : Colors.grey[400],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        style.subtitle.split(' • ').first,
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: Colors.grey[500],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
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
                                      child: const Icon(Icons.check, size: 12, color: Colors.white),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Section 3: Clock Display & Customization
                  _buildSectionHeader('⏰  CLOCK & COMPLICATIONS'),
                  const SizedBox(height: 10),

                  // Clock Visibility Switch Tile
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: SwitchListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      title: const Text(
                        'Show Clock on Dial',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        _clockStyle.isVisible
                            ? 'Clock is active (drag preview to move freely)'
                            : 'Clock removed (clean wallpaper only)',
                        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                      ),
                      value: _clockStyle.isVisible,
                      activeThumbColor: AppTheme.accent,
                      onChanged: (val) => setState(() {
                        _clockStyle = _clockStyle.copyWith(isVisible: val);
                      }),
                    ),
                  ),

                  if (_clockStyle.isVisible) ...[
                    const SizedBox(height: 14),

                    // Clock Layout Orientation Chips (Horizontal 120x73 vs Vertical 78x126)
                    Row(
                      children: [
                        Text(
                          'Layout: ',
                          style: TextStyle(fontSize: 13, color: Colors.grey[400], fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('⬌ Horizontal (120×73)'),
                          selected: !_clockStyle.isStacked,
                          selectedColor: AppTheme.accent,
                          labelStyle: TextStyle(
                            color: !_clockStyle.isStacked ? Colors.white : Colors.grey[400],
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          onSelected: (_) => setState(() {
                            if (_clockStyle.isStacked) {
                              _clockStyle = _clockStyle.copyWith(
                                isStacked: false,
                                position: _clockStyle.position.isCustom
                                    ? _clockStyle.position
                                    : ClockPosition.getPresets(isVertical: false).first,
                              );
                            }
                          }),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('⬍ Vertical (78×126)'),
                          selected: _clockStyle.isStacked,
                          selectedColor: AppTheme.accent,
                          labelStyle: TextStyle(
                            color: _clockStyle.isStacked ? Colors.white : Colors.grey[400],
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          onSelected: (_) => setState(() {
                            if (!_clockStyle.isStacked) {
                              _clockStyle = _clockStyle.copyWith(
                                isStacked: true,
                                position: _clockStyle.position.isCustom
                                    ? _clockStyle.position
                                    : ClockPosition.getPresets(isVertical: true).first,
                              );
                            }
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Clock Text Size Chips
                    Row(
                      children: [
                        Text(
                          'Size: ',
                          style: TextStyle(fontSize: 13, color: Colors.grey[400], fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        ...ClockSize.values.map((size) {
                          final isSelected = _clockStyle.size == size;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(size.label),
                              selected: isSelected,
                              selectedColor: AppTheme.accent,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : Colors.grey[400],
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                              onSelected: (_) => setState(() {
                                _clockStyle = _clockStyle.copyWith(size: size);
                              }),
                            ),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Active Display Box Information
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.aspect_ratio_rounded, size: 16, color: AppTheme.accent),
                          const SizedBox(width: 8),
                          Text(
                            'Active Outer Box: ',
                            style: TextStyle(fontSize: 12, color: Colors.grey[400], fontWeight: FontWeight.w600),
                          ),
                          Text(
                            _clockStyle.isVertical
                                ? '78×126px Vertical Box (Full-Height Digits)'
                                : '120×73px Horizontal Box (1:1 Accurate)',
                            style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Clock Position Presets & Custom Coordinates
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ...ClockPosition.getPresets(isVertical: _clockStyle.isVertical).map((pos) {
                            final isSelected = !_clockStyle.position.isCustom &&
                                _clockStyle.position.label == pos.label;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
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
                                  _clockStyle = _clockStyle.copyWith(
                                    position: pos,
                                  );
                                  _isDraggingClock = false;
                                }),
                              ),
                            );
                          }),
                          if (_clockStyle.position.isCustom)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text('Custom (${_clockStyle.position.x}, ${_clockStyle.position.y})'),
                                selected: true,
                                selectedColor: AppTheme.accent,
                                labelStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                                onSelected: (_) {},
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.touch_app_outlined, size: 14, color: AppTheme.accent),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Hold the clock until it vibrates to select and drag it freely.',
                            style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Section 3: Text & Accent Color
                    _buildSectionHeader('🎨  TEXT COLOR'),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: _availableColors.map((color) {
                        final isSelected = _clockStyle.textColor.toARGB32() == color.toARGB32();
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
                                  ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8)]
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Section 4: Complications & Widgets
                    _buildSectionHeader('📅  DATE & DISPLAY'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        FilterChip(
                          label: const Text('📅 Show Date'),
                          selected: _clockStyle.showDate,
                          selectedColor: AppTheme.accent,
                          labelStyle: TextStyle(
                            color: _clockStyle.showDate ? Colors.black : Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (val) => setState(() {
                            _clockStyle = _clockStyle.copyWith(showDate: val);
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, color: Color(0xFF38BDF8), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Watch hardware specification: Custom wallpaper dials render Time and Date with 1:1 pixel accuracy. Multi-metric complications (steps, battery, heart rate) are featured on factory built-in dials.',
                              style: TextStyle(fontSize: 11, color: Colors.blueGrey[200], height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
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

  TextStyle _getMiniatureStyle(ClockTemplateStyle style, {required bool isHour}) {
    final color = isHour ? style.primaryColor : (style.secondaryColor ?? style.primaryColor);
    final isOutline = !isHour && style.hasOutlineMinutes;

    TextStyle base;
    switch (style.fontFamily) {
      case ClockFontFamily.athletic:
        base = GoogleFonts.teko(fontSize: 14, fontWeight: FontWeight.w700, height: 0.88);
        break;
      case ClockFontFamily.block3d:
        base = GoogleFonts.bungee(fontSize: 9.5, fontWeight: FontWeight.w900, height: 0.95);
        break;
      case ClockFontFamily.casual:
        base = GoogleFonts.fredoka(fontSize: 11, fontWeight: FontWeight.w700, height: 0.95);
        break;
      case ClockFontFamily.pixel:
        base = GoogleFonts.pressStart2p(fontSize: 6.5, fontWeight: FontWeight.w400, height: 1.0);
        break;
      case ClockFontFamily.techno:
        base = GoogleFonts.orbitron(fontSize: 9.5, fontWeight: FontWeight.w900, height: 0.95);
        break;
      case ClockFontFamily.minimal:
        base = GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w400, height: 0.95);
        break;
      case ClockFontFamily.neon:
        base = GoogleFonts.shareTechMono(fontSize: 11, fontWeight: FontWeight.w700, height: 0.95);
        break;
      case ClockFontFamily.modern:
      default:
        base = GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w900, height: 0.95);
        break;
    }

    if (isOutline) {
      return base.copyWith(
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = color,
      );
    }
    return base.copyWith(color: color);
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
