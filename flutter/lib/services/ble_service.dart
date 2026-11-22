import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';

import '../core/constants/dizo_uuids.dart';
import '../models/discovered_device.dart';
import '../models/log_entry.dart';
import '../models/watch_telemetry.dart';
import 'htsmart_protocol.dart';

/// Central BLE Service managing connections, characteristic I/O, and telemetry
class BleService extends ChangeNotifier {
  BluetoothDevice? _device;
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isScanning = false;

  BluetoothCharacteristic? _charFF02;
  BluetoothCharacteristic? _charFF03;
  BluetoothCharacteristic? _charFEA1;

  WatchTelemetry _telemetry = const WatchTelemetry();
  final List<LogEntry> _logs = [];
  final List<StreamSubscription> _subscriptions = [];
  final List<DiscoveredDevice> _discoveredDevices = [];
  StreamSubscription? _scanResultsSub;

  // Getters
  BluetoothDevice? get device => _device;
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  bool get isScanning => _isScanning;
  WatchTelemetry get telemetry => _telemetry;
  List<LogEntry> get logs => List.unmodifiable(_logs);
  List<DiscoveredDevice> get discoveredDevices => List.unmodifiable(_discoveredDevices);

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  void log(String message, {LogType type = LogType.info}) {
    debugPrint('[BleService] [${type.name.toUpperCase()}] $message');
    _logs.add(LogEntry(
      message: message,
      type: type,
      time: DateFormat('HH:mm:ss').format(DateTime.now()),
    ));
    if (_logs.length > 200) {
      _logs.removeAt(0);
    }
    notifyListeners();
  }

  String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');

  Future<bool> requestPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    final scanGranted = (statuses[Permission.bluetoothScan]?.isGranted ?? false) ||
        (statuses[Permission.bluetoothScan]?.isLimited ?? false);
    final connectGranted = (statuses[Permission.bluetoothConnect]?.isGranted ?? false) ||
        (statuses[Permission.bluetoothConnect]?.isLimited ?? false);
    final locGranted = (statuses[Permission.locationWhenInUse]?.isGranted ?? false) ||
        (statuses[Permission.locationWhenInUse]?.isLimited ?? false);

    final hasPermission = (scanGranted && connectGranted) || locGranted;
    if (!hasPermission) {
      log('Bluetooth permissions denied — please enable in Settings', type: LogType.error);
      return false;
    }
    return true;
  }

  Future<void> scanAndConnect() async {
    if (_isConnected) {
      disconnect();
      return;
    }

    if (!await requestPermissions()) return;

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      log('Bluetooth is OFF — please enable it', type: LogType.error);
      await FlutterBluePlus.turnOn();
      return;
    }

    _isScanning = true;
    _isConnecting = false;
    notifyListeners();
    log('Scanning for DIZO Watch D...');

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 12),
      androidScanMode: AndroidScanMode.lowLatency,
    );

    bool found = false;
    await for (final results in FlutterBluePlus.scanResults) {
      for (final r in results) {
        final name = r.device.platformName;
        if (name.toUpperCase().contains('DIZO')) {
          log('Found: $name (${r.device.remoteId})', type: LogType.success);
          await FlutterBluePlus.stopScan();
          found = true;
          _isScanning = false;
          _isConnecting = true;
          notifyListeners();
          await connectToDevice(r.device);
          return;
        }
      }
    }

    _isScanning = false;
    notifyListeners();
    if (!found) {
      log('DIZO Watch D not found. Ensure it is nearby and not bonded to another host.',
          type: LogType.error);
    }
  }

  /// Scans for all nearby BLE devices and updates `discoveredDevices` list in real-time.
  Future<void> startDiscoveryScan({Duration timeout = const Duration(seconds: 15)}) async {
    if (!await requestPermissions()) return;

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      log('Bluetooth is OFF — please enable it', type: LogType.error);
      await FlutterBluePlus.turnOn();
      return;
    }

    _discoveredDevices.clear();
    _isScanning = true;
    notifyListeners();
    log('Scanning for nearby smartwatches...', type: LogType.info);

    await _scanResultsSub?.cancel();
    _scanResultsSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final existingIdx = _discoveredDevices.indexWhere(
          (d) => d.mac.toUpperCase() == r.device.remoteId.str.toUpperCase(),
        );
        final item = DiscoveredDevice.fromScanResult(r);
        if (existingIdx >= 0) {
          _discoveredDevices[existingIdx] = item;
        } else {
          _discoveredDevices.add(item);
        }
      }

      // Sort DIZO smartwatches first, then by signal strength
      _discoveredDevices.sort((a, b) {
        if (a.isDizo && !b.isDizo) return -1;
        if (!a.isDizo && b.isDizo) return 1;
        return b.rssi.compareTo(a.rssi);
      });
      notifyListeners();
    });

    try {
      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidScanMode: AndroidScanMode.lowLatency,
      );
    } catch (e) {
      log('Error during scan: $e', type: LogType.error);
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Stops ongoing discovery scan
  Future<void> stopDiscoveryScan() async {
    await FlutterBluePlus.stopScan();
    await _scanResultsSub?.cancel();
    _scanResultsSub = null;
    _isScanning = false;
    notifyListeners();
  }

  /// Connects directly to a specific watch MAC address (e.g. from QR code scan or manual entry).
  Future<bool> connectByMacAddress(String macAddress, {String? displayName}) async {
    if (_isConnected) {
      disconnect();
    }

    if (!await requestPermissions()) return false;

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      log('Bluetooth is OFF — please enable it', type: LogType.error);
      await FlutterBluePlus.turnOn();
      return false;
    }

    await stopDiscoveryScan();

    final cleanMac = macAddress.replaceAll('-', ':').toUpperCase().trim();
    final nameLabel = displayName != null && displayName.isNotEmpty ? displayName : 'Watch';
    log('Targeting $nameLabel at MAC: $cleanMac', type: LogType.info);

    _isConnecting = true;
    notifyListeners();

    // 1. Direct connect attempt using remoteId
    try {
      final targetDevice = BluetoothDevice.fromId(cleanMac);
      log('Connecting directly to $cleanMac...');
      await connectToDevice(targetDevice);
      if (_isConnected) {
        return true;
      }
    } catch (e) {
      log('Direct connect attempt note: $e, falling back to targeted scan...', type: LogType.info);
    }

    // 2. Targeted scan fallback if direct connection failed
    _isScanning = true;
    notifyListeners();
    log('Searching specifically for $cleanMac...');

    BluetoothDevice? foundDevice;
    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 8),
        androidScanMode: AndroidScanMode.lowLatency,
      );

      await for (final results in FlutterBluePlus.scanResults) {
        for (final r in results) {
          if (r.device.remoteId.str.toUpperCase() == cleanMac) {
            foundDevice = r.device;
            await FlutterBluePlus.stopScan();
            break;
          }
        }
        if (foundDevice != null) break;
      }
    } catch (e) {
      log('Targeted scan error: $e', type: LogType.error);
    } finally {
      _isScanning = false;
      notifyListeners();
    }

    if (foundDevice != null) {
      log('Found target watch! Connecting...', type: LogType.success);
      await connectToDevice(foundDevice);
      return _isConnected;
    } else {
      _isConnecting = false;
      notifyListeners();
      log('Watch $cleanMac not found nearby. Make sure it is powered on.', type: LogType.error);
      return false;
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      log('Connecting to ${device.platformName.isNotEmpty ? device.platformName : device.remoteId.str}...');
      await device.connect(autoConnect: false, timeout: const Duration(seconds: 10));

      log('Connected! Discovering services...', type: LogType.success);
      _device = device;

      final sub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          log('Watch disconnected', type: LogType.error);
          _onDisconnected();
        }
      });
      _subscriptions.add(sub);

      try {
        await device.requestMtu(250);
        log('MTU configured');
      } catch (e) {
        log('MTU negotiation skipped: $e', type: LogType.info);
      }

      final services = await device.discoverServices();
      log('Discovered ${services.length} services');

      // Primary service (000001ff)
      final primaryService = services.firstWhere(
        (s) => s.uuid == DizoUuids.servicePrimary || s.uuid.str128.toLowerCase().contains('01ff'),
        orElse: () => throw Exception('Primary service (01ff) not found!'),
      );

      _charFF02 = primaryService.characteristics.firstWhere(
        (c) => c.uuid == DizoUuids.charFF02Write || c.uuid.str128.toLowerCase().contains('ff02'),
        orElse: () => throw Exception('FF02 (Write) not found!'),
      );

      _charFF03 = primaryService.characteristics.firstWhere(
        (c) => c.uuid == DizoUuids.charFF03Notify || c.uuid.str128.toLowerCase().contains('ff03'),
        orElse: () => throw Exception('FF03 (Notify) not found!'),
      );

      await _charFF03!.setNotifyValue(true);
      final ff03Sub = _charFF03!.onValueReceived.listen((value) {
        log('FF03 ← ${_hex(value)}', type: LogType.data);
      });
      _subscriptions.add(ff03Sub);
      log('FF03 notification stream active ✓', type: LogType.success);

      // Heartbeat & status (FEE7)
      try {
        final fee7Service = services.firstWhere(
          (s) => s.uuid == DizoUuids.serviceFee7 || s.uuid.str128.toLowerCase().contains('fee7'),
        );
        _charFEA1 = fee7Service.characteristics.firstWhere(
          (c) => c.uuid == DizoUuids.charFEA1Notify || c.uuid.str128.toLowerCase().contains('fea1'),
        );
        await _charFEA1!.setNotifyValue(true);
        final fea1Sub = _charFEA1!.onValueReceived.listen((value) {
          log('FEA1 ← ${_hex(value)}', type: LogType.data);
          _decodeFEA1(value);
        });
        _subscriptions.add(fea1Sub);
        log('FEA1 telemetry stream active ✓', type: LogType.success);
      } catch (e) {
        log('FEA1 characteristic optional or inactive: $e', type: LogType.info);
      }

      _isConnected = true;
      _isConnecting = false;
      notifyListeners();

      // Maintain active session with the watch firmware
      log('Authenticating session with watch...');
      await writeFF02(HtsmartProtocol.buildLoginPacket(), 'Session Auth');

      // Auto time sync on connection
      log('Auto-synchronizing watch time...');
      await syncTime();
    } catch (e) {
      log('Connection failed: $e', type: LogType.error);
      _isConnected = false;
      _isConnecting = false;
      notifyListeners();
    }
  }

  void disconnect() {
    _device?.disconnect();
    _onDisconnected();
    log('Disconnected by user');
  }

  void _onDisconnected() {
    _scanResultsSub?.cancel();
    _scanResultsSub = null;
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    _isConnected = false;
    _isConnecting = false;
    _device = null;
    _charFF02 = null;
    _charFF03 = null;
    _charFEA1 = null;
    _telemetry = const WatchTelemetry();
    notifyListeners();
  }

  void _decodeFEA1(List<int> data) {
    if (data.length < 2) return;
    final packetType = data[0];

    switch (packetType) {
      case 0x07: // Activity frame
        int? steps = _telemetry.steps;
        int? calories = _telemetry.calories;
        double? distance = _telemetry.distanceMeters;

        if (data.length >= 3) steps = (data[2] << 8) | data[1];
        if (data.length >= 6) calories = ((data[5] << 8) | data[4]) ~/ 10;
        if (data.length >= 9) distance = ((data[8] << 8) | data[7]) / 100.0;

        _telemetry = _telemetry.copyWith(
          steps: steps,
          calories: calories,
          distanceMeters: distance,
        );
        notifyListeners();
        break;

      case 0x08: // Heart rate
        if (data.length >= 2 && data[1] >= 30 && data[1] <= 220) {
          _telemetry = _telemetry.copyWith(heartRate: data[1]);
          notifyListeners();
        }
        break;

      case 0x05: // Battery
        if (data.length >= 2 && data[1] <= 100) {
          _telemetry = _telemetry.copyWith(battery: data[1]);
          notifyListeners();
        }
        break;

      case 0x0A: // SpO2
        if (data.length >= 3 && data[2] >= 80 && data[2] <= 100) {
          _telemetry = _telemetry.copyWith(spo2: data[2]);
          notifyListeners();
        }
        break;
    }
  }

  Future<void> writeFF02(List<int> bytes, String label) async {
    if (_charFF02 == null) {
      log('Not connected!', type: LogType.error);
      return;
    }
    try {
      log('$label → FF02: ${_hex(bytes)}', type: LogType.send);
      await _charFF02!.write(bytes, withoutResponse: false);
      log('$label sent ✓', type: LogType.success);
    } catch (e) {
      try {
        await _charFF02!.write(bytes, withoutResponse: true);
        log('$label sent (no-response) ✓', type: LogType.success);
      } catch (e2) {
        log('$label failed: $e2', type: LogType.error);
      }
    }
  }

  Future<void> syncTime() async {
    final now = DateTime.now();
    log('Building HTSmart time synchronization packet...');
    final packet = HtsmartProtocol.buildTimeSyncPacket(now, seq: 1);
    await writeFF02(packet, 'Time Sync (HTSmart)');
  }

  Future<void> syncSteps() async {
    await writeFF02([0x03, 0x01], '🚶 Steps sync');
  }

  Future<void> syncHealth() async {
    await writeFF02([0x03, 0x03], '❤️ HR sync');
    await Future.delayed(const Duration(milliseconds: 300));
    await writeFF02([0x03, 0x04], '🩸 SpO2 sync');
  }

  Future<void> syncSleep() async {
    await writeFF02([0x03, 0x02], '😴 Sleep sync');
  }

  Future<void> readBattery() async {
    try {
      final services = await _device?.discoverServices();
      final secService = services?.firstWhere(
        (s) => s.uuid == DizoUuids.serviceSecondary,
      );
      final charFFD2 = secService?.characteristics.firstWhere(
        (c) => c.uuid == DizoUuids.charFFD2,
      );
      if (charFFD2 != null) {
        final value = await charFFD2.read();
        log('FFD2 ← ${_hex(value)}', type: LogType.data);
        if (value.isNotEmpty) {
          _telemetry = _telemetry.copyWith(battery: value[0]);
          notifyListeners();
          log('Battery: ${value[0]}%', type: LogType.info);
        }
      }
    } catch (e) {
      log('Battery query failed: $e', type: LogType.error);
    }
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }
}
