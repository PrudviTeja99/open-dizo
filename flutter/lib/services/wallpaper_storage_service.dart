import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/wallpaper_item.dart';

/// Manages local storage of processed 240x286 wallpapers and history
class WallpaperStorageService extends ChangeNotifier {
  static const String _prefKey = 'saved_wallpapers_history_v1';
  List<WallpaperItem> _items = [];

  List<WallpaperItem> get items => List.unmodifiable(_items);

  Future<void> init() async {
    await loadWallpapers();
  }

  Future<Directory> _getWallpapersDir() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final wpDir = Directory('${docsDir.path}/dizo_wallpapers');
    if (!await wpDir.exists()) {
      await wpDir.create(recursive: true);
    }
    return wpDir;
  }

  Future<void> loadWallpapers() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefKey);
    if (jsonStr != null) {
      try {
        final List<dynamic> list = jsonDecode(jsonStr);
        _items = list
            .map((e) => WallpaperItem.fromJson(e as Map<String, dynamic>))
            .where((item) => item.exists)
            .toList();
        _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } catch (e) {
        debugPrint('Error loading wallpaper history: $e');
        _items = [];
      }
    }
    notifyListeners();
  }

  Future<WallpaperItem> saveProcessedWallpaper(Uint8List imageBytes) async {
    final dir = await _getWallpapersDir();
    final id = 'wp_${DateTime.now().millisecondsSinceEpoch}';
    final file = File('${dir.path}/$id.png');

    // Save only this single optimized 240x286 image
    await file.writeAsBytes(imageBytes, flush: true);

    final item = WallpaperItem(
      id: id,
      filePath: file.path,
      createdAt: DateTime.now(),
    );

    _items.insert(0, item);
    await _persist();
    notifyListeners();
    return item;
  }

  Future<void> deleteWallpaper(WallpaperItem item) async {
    try {
      final file = File(item.filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting wallpaper file: $e');
    }

    _items.removeWhere((i) => i.id == item.id);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _items.map((i) => i.toJson()).toList();
    await prefs.setString(_prefKey, jsonEncode(list));
  }
}
