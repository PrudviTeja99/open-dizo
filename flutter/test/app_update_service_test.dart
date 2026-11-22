import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:open_dizo/services/app_update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppUpdateService Version Tests', () {
    test('isVersionNewer correctly compares semantic versions', () {
      // Remote newer than local
      expect(AppUpdateService.isVersionNewer('v1.1.5', '1.1.4'), isTrue);
      expect(AppUpdateService.isVersionNewer('1.2.0', '1.1.9'), isTrue);
      expect(AppUpdateService.isVersionNewer('v2.0.0', '1.9.9'), isTrue);

      // Same versions
      expect(AppUpdateService.isVersionNewer('v1.1.5', '1.1.5'), isFalse);
      expect(AppUpdateService.isVersionNewer('1.1.5', '1.1.5'), isFalse);

      // Local newer than remote
      expect(AppUpdateService.isVersionNewer('v1.1.4', '1.1.5'), isFalse);
      expect(AppUpdateService.isVersionNewer('1.1.0', '1.1.5'), isFalse);
      expect(AppUpdateService.isVersionNewer('1.0.9', '1.1.0'), isFalse);
    });

    test('Loads version dynamically from PackageInfo', () async {
      PackageInfo.setMockInitialValues(
        appName: 'Open Dizo',
        packageName: 'bpt.studiohq.open_dizo',
        version: '1.1.5',
        buildNumber: '7',
        buildSignature: '',
        installerStore: null,
      );

      final version = await AppUpdateService.getInstalledVersion();
      expect(version, equals('1.1.5'));
      expect(AppUpdateService.currentVersion, equals('1.1.5'));
    });
  });
}
