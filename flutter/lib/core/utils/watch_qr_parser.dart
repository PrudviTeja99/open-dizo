class WatchQrPayload {
  final String? mac;
  final String? name;
  final String? model;
  final String raw;
  final bool isValid;

  const WatchQrPayload({
    this.mac,
    this.name,
    this.model,
    required this.raw,
    required this.isValid,
  });

  @override
  String toString() =>
      'WatchQrPayload(mac: $mac, name: $name, model: $model, isValid: $isValid)';
}

class WatchQrParser {
  static final RegExp _macRegex = RegExp(
    r'([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})',
  );

  /// Parses the on-screen QR code string from DIZO / HTSmart smartwatches.
  ///
  /// Examples:
  /// - `BtName=DIZO%20Watch%20D&MAC=CC:EA:FF:AA:42:7F&adaptNum=RH291A`
  /// - `htsmart://bind?mac=CC:EA:FF:AA:42:7F&name=DIZO+Watch+D`
  /// - `CC:EA:FF:AA:42:7F`
  static WatchQrPayload parse(String rawText) {
    final trimmed = rawText.trim();
    String? mac;
    String? name;
    String? model;

    // 1. Key-value pair parsing (& delimited)
    if (trimmed.contains('&') || trimmed.contains('=')) {
      final queryPart = trimmed.contains('?')
          ? trimmed.substring(trimmed.indexOf('?') + 1)
          : trimmed;

      final pairs = queryPart.split('&');
      for (final pair in pairs) {
        if (!pair.contains('=')) continue;
        final eqIdx = pair.indexOf('=');
        final key = pair.substring(0, eqIdx).trim().toLowerCase();
        final val = pair.substring(eqIdx + 1).trim();

        if (key == 'mac') {
          mac = _cleanMac(val);
        } else if (key == 'btname' || key == 'name') {
          name = Uri.decodeComponent(val.replaceAll('+', ' '));
        } else if (key == 'adaptnum' || key == 'model') {
          model = val;
        }
      }
    }

    // 2. Direct MAC address matching fallback
    if (mac == null || mac.isEmpty) {
      final match = _macRegex.firstMatch(trimmed);
      if (match != null) {
        mac = _cleanMac(match.group(0)!);
      }
    }

    final isValid = mac != null && mac.isNotEmpty;
    return WatchQrPayload(
      mac: mac,
      name: name ?? (isValid ? 'DIZO Watch' : null),
      model: model,
      raw: trimmed,
      isValid: isValid,
    );
  }

  static String _cleanMac(String rawMac) {
    return rawMac.replaceAll('-', ':').toUpperCase().trim();
  }
}
