import 'dart:io';

/// Represents a processed 240x286 wallpaper stored in the app's local library
class WallpaperItem {
  final String id;
  final String filePath;
  final DateTime createdAt;

  const WallpaperItem({
    required this.id,
    required this.filePath,
    required this.createdAt,
  });

  bool get exists => File(filePath).existsSync();

  Map<String, dynamic> toJson() => {
        'id': id,
        'filePath': filePath,
        'createdAt': createdAt.toIso8601String(),
      };

  factory WallpaperItem.fromJson(Map<String, dynamic> json) => WallpaperItem(
        id: json['id'] as String,
        filePath: json['filePath'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
