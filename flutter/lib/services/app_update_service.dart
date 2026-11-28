import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class AppReleaseInfo {
  final String tagName;
  final String title;
  final String releaseNotes;
  final String apkDownloadUrl;
  final String apkFileName;
  final int apkSizeBytes;
  final bool isNewerVersion;

  const AppReleaseInfo({
    required this.tagName,
    required this.title,
    required this.releaseNotes,
    required this.apkDownloadUrl,
    required this.apkFileName,
    required this.apkSizeBytes,
    required this.isNewerVersion,
  });
}

class AppUpdateService {
  static String _cachedVersion = '1.3.2';

  /// Returns the currently installed application version (e.g. "1.3.2")
  static String get currentVersion => _cachedVersion;

  /// Loads current version dynamically from platform package info
  static Future<String> getInstalledVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) {
        _cachedVersion = info.version;
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Failed to load package info: $e');
    }
    return _cachedVersion;
  }

  static const String repoOwner = 'PrudviTeja99';
  static const String repoName = 'open-dizo';
  static const MethodChannel _channel = MethodChannel('bpt.studiohq.open_dizo/updater');

  /// Queries GitHub Releases API for the latest release
  static Future<AppReleaseInfo?> checkForUpdate() async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    try {
      await getInstalledVersion();

      final uri = Uri.parse('https://api.github.com/repos/$repoOwner/$repoName/releases/latest');
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'Open-Dizo-App');
      request.headers.set('Accept', 'application/vnd.github.v3+json');

      final response = await request.close();
      if (response.statusCode != 200) {
        throw Exception('GitHub API returned status code ${response.statusCode}');
      }

      final jsonStr = await response.transform(utf8.decoder).join();
      final Map<String, dynamic> data = jsonDecode(jsonStr);

      final tagName = data['tag_name'] as String? ?? '';
      final title = data['name'] as String? ?? tagName;
      final body = data['body'] as String? ?? 'No release notes provided.';

      // Search for the .apk file in release assets
      final List<dynamic> assets = data['assets'] as List<dynamic>? ?? [];
      Map<String, dynamic>? apkAsset;
      for (final a in assets) {
        final name = a['name'] as String? ?? '';
        if (name.endsWith('.apk')) {
          apkAsset = a as Map<String, dynamic>;
          break;
        }
      }

      if (apkAsset == null) {
        return null;
      }

      final downloadUrl = apkAsset['browser_download_url'] as String? ?? '';
      final fileName = apkAsset['name'] as String? ?? 'open-dizo.apk';
      final sizeBytes = apkAsset['size'] as int? ?? 0;

      final isNewer = _isVersionNewer(tagName, _cachedVersion);

      return AppReleaseInfo(
        tagName: tagName,
        title: title,
        releaseNotes: body,
        apkDownloadUrl: downloadUrl,
        apkFileName: fileName,
        apkSizeBytes: sizeBytes,
        isNewerVersion: isNewer,
      );
    } finally {
      client.close();
    }
  }

  /// Downloads the release APK with real-time progress reporting
  static Future<File> downloadApk({
    required String downloadUrl,
    required String fileName,
    void Function(double progress, int received, int total)? onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    if (file.existsSync()) {
      file.deleteSync();
    }

    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(downloadUrl));
      request.headers.set('User-Agent', 'Open-Dizo-App');
      final response = await request.close();

      if (response.statusCode >= 300 && response.statusCode < 400) {
        // Follow redirect (GitHub asset download redirects to S3/CDN)
        final redirectUrl = response.headers.value(HttpHeaders.locationHeader);
        if (redirectUrl != null) {
          return downloadApk(
            downloadUrl: redirectUrl,
            fileName: fileName,
            onProgress: onProgress,
          );
        }
      }

      if (response.statusCode != 200) {
        throw Exception('Download failed with status: ${response.statusCode}');
      }

      final total = response.contentLength;
      int received = 0;
      final sink = file.openWrite();

      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        if (onProgress != null && total > 0) {
          onProgress(received / total, received, total);
        }
      }

      await sink.flush();
      await sink.close();
      return file;
    } finally {
      client.close();
    }
  }

  /// Triggers Android Package Installer via native FileProvider Intent
  static Future<bool> installApk(String filePath) async {
    try {
      final bool? success = await _channel.invokeMethod<bool>('installApk', {'filePath': filePath});
      return success ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to launch installer: ${e.message}');
    }
  }

  @visibleForTesting
  static bool isVersionNewer(String remoteTag, String localVersion) => _isVersionNewer(remoteTag, localVersion);

  /// Compares version string like "v1.1.5" vs "1.1.4"
  static bool _isVersionNewer(String remoteTag, String localVersion) {
    final cleanRemote = remoteTag.replaceAll(RegExp(r'[^0-9.]'), '');
    final cleanLocal = localVersion.replaceAll(RegExp(r'[^0-9.]'), '');

    final rParts = cleanRemote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final lParts = cleanLocal.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final maxLen = math.max(rParts.length, lParts.length);
    for (int i = 0; i < maxLen; i++) {
      final r = i < rParts.length ? rParts[i] : 0;
      final l = i < lParts.length ? lParts[i] : 0;
      if (r > l) return true;
      if (r < l) return false;
    }
    return false;
  }
}
