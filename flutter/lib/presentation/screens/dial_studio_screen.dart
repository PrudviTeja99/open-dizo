import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final bool isEmbedded;

  const DialStudioScreen({
    super.key,
    required this.bleService,
    this.isEmbedded = false,
  });

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
  int _activeEditorTab = 0; // 0 = Background, 1 = Style, 2 = Color & Layout

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
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLayout = prefs.getString('last_flashed_studio_layout');
      if (savedLayout != null) {
        final decoded = jsonDecode(savedLayout) as Map<String, dynamic>;
        final styleMap = decoded['clockStyle'] as Map<String, dynamic>?;
        if (styleMap != null) {
          _clockStyle = ClockStyle.fromJson(styleMap);
        }
        final wpId = decoded['wallpaperId'] as String?;
        if (wpId != null && _storageService.items.isNotEmpty) {
          final match = _storageService.items.where((w) => w.id == wpId);
          if (match.isNotEmpty) {
            _selectedWallpaper = match.first;
          }
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveLastFlashedLayout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'last_flashed_studio_layout',
        jsonEncode({
          'wallpaperId': _selectedWallpaper?.id,
          'clockStyle': _clockStyle.toJson(),
        }),
      );
    } catch (_) {}
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
        await _saveLastFlashedLayout();
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
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              title: const Text('Watch Face Studio',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              elevation: 0,
              backgroundColor: Colors.transparent,
            ),
      body: SafeArea(
        child: Column(
          children: [
            // Full-page scrollable studio (preview + 3-tab editor scroll together smoothly)
            Expanded(
              child: ListView(
                physics: _isDraggingClock
                    ? const NeverScrollableScrollPhysics()
                    : const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                children: [
                  // 1. Live Watch Preview
                  Center(
                    child: WatchCanvasPreview(
                      wallpaperFile: currentWallpaperFile,
                      clockStyle: _clockStyle,
                      scale: 0.9,
                      onDragStateChanged: (dragging) => setState(() => _isDraggingClock = dragging),
                      onClockDragged: (newX, newY) => setState(() {
                        _clockStyle = _clockStyle.copyWith(
                          position: ClockPosition('Custom', newX, newY, isCustom: true),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      _clockStyle.isVisible
                          ? 'Hold & drag clock on preview to reposition'
                          : 'Wallpaper-only mode (clock hidden)',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Clean 3-Tab Studio Editor Bar
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        _buildEditorTabPill(0, Icons.photo_library_rounded, 'Background'),
                        _buildEditorTabPill(1, Icons.watch_rounded, 'Clock Style'),
                        _buildEditorTabPill(2, Icons.palette_rounded, 'Color & Layout'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Active Editor Panel
                  if (_activeEditorTab == 0) _buildBackgroundEditorTab(),
                  if (_activeEditorTab == 1) _buildClockStyleEditorTab(),
                  if (_activeEditorTab == 2) _buildColorLayoutEditorTab(),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // 4. Bottom Action Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                children: [
                  if (!widget.isEmbedded) ...[
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
                  ],
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _confirmAndFlash,
                      icon: const Icon(Icons.flash_on_rounded),
                      label: Text(
                        widget.bleService.isConnected ? 'Apply to Watch' : 'Connect Watch to Apply',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: const Color(0xFF0A0C10),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
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

  Widget _buildEditorTabPill(int index, IconData icon, String label) {
    final isSelected = _activeEditorTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeEditorTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? const Color(0xFF0A0C10) : AppTheme.textSecondary,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? const Color(0xFF0A0C10) : AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundEditorTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('WALLPAPER GALLERY'),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.84,
          ),
          itemCount: _storageService.items.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return GestureDetector(
                onTap: _pickNewWallpaper,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.accent.withValues(alpha: 0.55),
                      width: 1.5,
                    ),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_rounded, color: AppTheme.accent, size: 26),
                      SizedBox(height: 4),
                      Text('Add Photo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              );
            }
            final item = _storageService.items[index - 1];
            final isSelected = _selectedWallpaper?.id == item.id;
            return GestureDetector(
              onTap: () => setState(() => _selectedWallpaper = item),
              onLongPress: () => _confirmDeleteWallpaper(item),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? AppTheme.accent : AppTheme.border,
                    width: isSelected ? 2.5 : 1,
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Image.file(File(item.filePath), fit: BoxFit.cover),
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
          },
        ),
        const SizedBox(height: 8),
        const Text(
          'Tip: Long-press any saved wallpaper to delete it.',
          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
        ),
      ],
    );
  }

  Widget _buildClockStyleEditorTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: SwitchListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: const Text(
              'Show Clock on Dial',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            subtitle: Text(
              _clockStyle.isVisible
                  ? 'Customize typography, layout & size below'
                  : 'Wallpaper only (no clock overlay)',
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
            value: _clockStyle.isVisible,
            activeThumbColor: AppTheme.accent,
            onChanged: (val) => setState(() {
              _clockStyle = _clockStyle.copyWith(isVisible: val);
            }),
          ),
        ),
        if (_clockStyle.isVisible) ...[
          const SizedBox(height: 16),
          _buildSectionHeader('TYPOGRAPHY'),
          const SizedBox(height: 10),
          SizedBox(
            height: 106,
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
                    width: 92,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161622),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? AppTheme.accent : AppTheme.border,
                        width: isSelected ? 2.5 : 1,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                height: 44,
                                width: style.isStacked ? 38 : 64,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: style.primaryColor.withValues(alpha: 0.45),
                                  ),
                                ),
                                child: Center(
                                  child: style.isStacked
                                      ? Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text('10', style: _getMiniatureStyle(style, isHour: true)),
                                            Text('08', style: _getMiniatureStyle(style, isHour: false)),
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
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  color: isSelected ? Colors.white : Colors.grey[400],
                                ),
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
                              child: const Icon(Icons.check, size: 11, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Orientation: ', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Horizontal'),
                selected: !_clockStyle.isStacked,
                selectedColor: AppTheme.accent,
                labelStyle: TextStyle(
                  color: !_clockStyle.isStacked ? const Color(0xFF0A0C10) : AppTheme.textSecondary,
                  fontWeight: FontWeight.w700,
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
                label: const Text('Stacked'),
                selected: _clockStyle.isStacked,
                selectedColor: AppTheme.accent,
                labelStyle: TextStyle(
                  color: _clockStyle.isStacked ? const Color(0xFF0A0C10) : AppTheme.textSecondary,
                  fontWeight: FontWeight.w700,
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
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Size: ', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
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
                      color: isSelected ? const Color(0xFF0A0C10) : AppTheme.textSecondary,
                      fontWeight: FontWeight.w700,
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
        ],
      ],
    );
  }

  Widget _buildColorLayoutEditorTab() {
    if (!_clockStyle.isVisible) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: Text(
            'Enable "Show Clock on Dial" in the Clock Style tab to customize color and layout.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('CLOCK COLOR'),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _availableColors.map((color) {
            final isSelected = _clockStyle.textColor.toARGB32() == color.toARGB32();
            return GestureDetector(
              onTap: () => setState(() {
                _clockStyle = _clockStyle.copyWith(textColor: color);
              }),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: Border.all(
                    color: isSelected ? Colors.white : AppTheme.border,
                    width: isSelected ? 3 : 1,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 8)]
                      : null,
                ),
                child: isSelected
                    ? Icon(
                        Icons.check,
                        size: 16,
                        color: color == Colors.white ? Colors.black : Colors.white,
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
        _buildSectionHeader('POSITION'),
        const SizedBox(height: 10),
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
                      color: isSelected ? const Color(0xFF0A0C10) : AppTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    onSelected: (_) => setState(() {
                      _clockStyle = _clockStyle.copyWith(position: pos);
                      _isDraggingClock = false;
                    }),
                  ),
                );
              }),
              if (_clockStyle.position.isCustom)
                ChoiceChip(
                  label: Text('Custom (${_clockStyle.position.x}, ${_clockStyle.position.y})'),
                  selected: true,
                  selectedColor: AppTheme.accent,
                  labelStyle: const TextStyle(
                    color: Color(0xFF0A0C10),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  onSelected: (_) {},
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _buildSectionHeader('DATE DISPLAY'),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: SwitchListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: const Text(
              'Show Date on Dial',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            subtitle: Text(
              _clockStyle.showDate
                  ? 'Choose a date format style below'
                  : 'Date hidden from watch face',
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
            value: _clockStyle.showDate,
            activeThumbColor: AppTheme.accent,
            onChanged: (val) => setState(() {
              _clockStyle = _clockStyle.copyWith(showDate: val);
            }),
          ),
        ),
        if (_clockStyle.showDate) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 92,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: DateStyle.values.map((ds) {
                final isSelected = _clockStyle.dateStyle == ds;
                final isPill = ds == DateStyle.pillBadge;
                return GestureDetector(
                  onTap: () => setState(() {
                    _clockStyle = _clockStyle.copyWith(dateStyle: ds);
                  }),
                  child: Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161622),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? AppTheme.accent : AppTheme.border,
                        width: isSelected ? 2.5 : 1,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                height: 38,
                                width: 80,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _clockStyle.textColor.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Center(
                                  child: Container(
                                    padding: isPill
                                        ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
                                        : EdgeInsets.zero,
                                    decoration: isPill
                                        ? BoxDecoration(
                                            color: _clockStyle.textColor.withValues(alpha: 0.18),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: _clockStyle.textColor.withValues(alpha: 0.4),
                                            ),
                                          )
                                        : null,
                                    child: Text(
                                      ds.sample,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: _clockStyle.textColor,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                ds.label,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  color: isSelected ? Colors.white : Colors.grey[400],
                                ),
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
                              child: const Icon(Icons.check, size: 11, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
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
