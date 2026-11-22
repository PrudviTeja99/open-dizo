import 'package:flutter_blue_plus/flutter_blue_plus.dart';

enum SignalTier { strong, medium, weak }

class DiscoveredDevice {
  final BluetoothDevice device;
  final String name;
  final String mac;
  final int rssi;
  final bool isDizo;

  DiscoveredDevice({
    required this.device,
    required this.name,
    required this.mac,
    required this.rssi,
    required this.isDizo,
  });

  SignalTier get signalTier {
    if (rssi >= -65) return SignalTier.strong;
    if (rssi >= -80) return SignalTier.medium;
    return SignalTier.weak;
  }

  factory DiscoveredDevice.fromScanResult(ScanResult r) {
    final rawName = r.device.platformName.isNotEmpty
        ? r.device.platformName
        : (r.advertisementData.advName.isNotEmpty
            ? r.advertisementData.advName
            : 'Unknown Device');

    final upperName = rawName.toUpperCase();
    final isDizo = upperName.contains('DIZO') ||
        upperName.contains('WATCH') ||
        upperName.contains('RH291');

    return DiscoveredDevice(
      device: r.device,
      name: rawName,
      mac: r.device.remoteId.str,
      rssi: r.rssi,
      isDizo: isDizo,
    );
  }
}
