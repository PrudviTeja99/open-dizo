import 'package:flutter_test/flutter_test.dart';
import 'package:open_dizo/core/utils/watch_qr_parser.dart';

void main() {
  group('WatchQrParser Tests', () {
    test('Parses official app query string format', () {
      const raw = 'BtName=DIZO%20Watch%20D&MAC=CC:EA:FF:AA:42:7F&adaptNum=RH291A';
      final payload = WatchQrParser.parse(raw);

      expect(payload.isValid, isTrue);
      expect(payload.mac, equals('CC:EA:FF:AA:42:7F'));
      expect(payload.name, equals('DIZO Watch D'));
      expect(payload.model, equals('RH291A'));
    });

    test('Parses htsmart URI scheme format', () {
      const raw = 'htsmart://bind?mac=cc:ea:ff:aa:42:7f&name=DIZO+Watch+D';
      final payload = WatchQrParser.parse(raw);

      expect(payload.isValid, isTrue);
      expect(payload.mac, equals('CC:EA:FF:AA:42:7F'));
      expect(payload.name, equals('DIZO Watch D'));
    });

    test('Parses raw colon-delimited MAC address', () {
      const raw = 'CC:EA:FF:AA:42:7F';
      final payload = WatchQrParser.parse(raw);

      expect(payload.isValid, isTrue);
      expect(payload.mac, equals('CC:EA:FF:AA:42:7F'));
    });

    test('Parses hyphen-delimited MAC address', () {
      const raw = 'cc-ea-ff-aa-42-7f';
      final payload = WatchQrParser.parse(raw);

      expect(payload.isValid, isTrue);
      expect(payload.mac, equals('CC:EA:FF:AA:42:7F'));
    });

    test('Rejects invalid non-watch QR codes', () {
      const raw = 'https://dizo.net/download-app';
      final payload = WatchQrParser.parse(raw);

      expect(payload.isValid, isFalse);
      expect(payload.mac, isNull);
    });
  });
}
