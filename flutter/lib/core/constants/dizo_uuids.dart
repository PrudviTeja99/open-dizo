import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Bluetooth GATT Service and Characteristic UUIDs for DIZO Watch D
class DizoUuids {
  // Primary Wristband Service (000001ff)
  static final Guid servicePrimary =
      Guid('000001ff-3c17-d293-8e48-14fe2e4da212');

  // Primary Service Characteristics
  static final Guid charFF02Write =
      Guid('0000ff02-3c17-d293-8e48-14fe2e4da212'); // Command write endpoint
  static final Guid charFF03Notify =
      Guid('0000ff03-3c17-d293-8e48-14fe2e4da212'); // Notification / response endpoint
  static final Guid charFF04Rw =
      Guid('0000ff04-3c17-d293-8e48-14fe2e4da212'); // Device configuration

  // Secondary Service (D0FF)
  static final Guid serviceSecondary =
      Guid('0000d0ff-3c17-d293-8e48-14fe2e4da212');
  static final Guid charFFD2 =
      Guid('0000ffd2-3c17-d293-8e48-14fe2e4da212'); // Battery and device info

  // Heartbeat & Live Telemetry Service (FEE7)
  static final Guid serviceFee7 =
      Guid('0000fee7-0000-1000-8000-00805f9b34fb');
  static final Guid charFEA1Notify =
      Guid('0000fea1-0000-1000-8000-00805f9b34fb'); // Real-time sensor stream

  // Realtek Silent DFU OTA Service (00006287)
  static final Guid serviceDfu =
      Guid('00006287-3c17-d293-8e48-14fe2e4da212');
  static final Guid charDfuControl =
      Guid('00006487-3c17-d293-8e48-14fe2e4da212'); // DFU Control Point
  static final Guid charDfuData =
      Guid('00006387-3c17-d293-8e48-14fe2e4da212'); // DFU Data Endpoint
}
