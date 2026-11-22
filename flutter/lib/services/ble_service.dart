import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/dizo_uuids.dart';
import '../models/discovered_device.dart';
import '../models/log_entry.dart';
import '../models/watch_telemetry.dart';
import '../models/watch_settings.dart';
import 'htsmart_protocol.dart';

/// Central BLE Service managing connections, characteristic I/O, telemetry,
/// and complete watch options/settings according to clean protocol specifications.
class BleService extends ChangeNotifier {
  BluetoothDevice? _device;
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isScanning = false;
  bool _isSyncing = false;
  bool _isMeasuringHealth = false;

  BluetoothCharacteristic? _charFF02;
  BluetoothCharacteristic? _charFF03;
  BluetoothCharacteristic? _charFEA1;

  WatchTelemetry _telemetry = const WatchTelemetry();
  WatchSettings _settings = const WatchSettings();

  final List<LogEntry> _logs = [];
  final List<StreamSubscription> _subscriptions = [];
  final List<DiscoveredDevice> _discoveredDevices = [];
  StreamSubscription? _scanResultsSub;
  Timer? _periodicSyncTimer;
  Timer? _healthMeasureTimer;

  String? _lastDeviceMac;
  String? _lastDeviceName;

  BleService() {
    _loadPersistedData();
  }

  // Getters
  BluetoothDevice? get device => _device;
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  bool get isScanning => _isScanning;
  bool get isSyncing => _isSyncing;
  bool get isMeasuringHealth => _isMeasuringHealth;
  WatchTelemetry get telemetry => _telemetry;
  WatchSettings get settings => _settings;
  List<LogEntry> get logs => List.unmodifiable(_logs);
  List<DiscoveredDevice> get discoveredDevices => List.unmodifiable(_discoveredDevices);
  String? get lastDeviceMac => _lastDeviceMac;
  String? get lastDeviceName => _lastDeviceName;

  Future<void> _loadPersistedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastDeviceMac = prefs.getString('last_device_mac');
      _lastDeviceName = prefs.getString('last_device_name');
      final cachedTel = prefs.getString('cached_telemetry');
      if (cachedTel != null) {
        _telemetry = WatchTelemetry.fromJson(cachedTel);
      }
      final cachedSettings = prefs.getString('cached_settings');
      if (cachedSettings != null) {
        _settings = WatchSettings.fromJson(cachedSettings);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[BleService] Error loading persisted data: $e');
    }
  }

  Future<void> _saveTelemetry() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_telemetry', _telemetry.toJson());
    } catch (e) {
      debugPrint('[BleService] Error saving telemetry: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_settings', _settings.toJson());
    } catch (e) {
      debugPrint('[BleService] Error saving settings: $e');
    }
  }

  Future<void> _saveLastDevice(String mac, String name) async {
    try {
      _lastDeviceMac = mac;
      _lastDeviceName = name;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_device_mac', mac);
      await prefs.setString('last_device_name', name);
    } catch (e) {
      debugPrint('[BleService] Error saving last device: $e');
    }
  }

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
        final d = DiscoveredDevice.fromScanResult(r);
        final existingIdx = _discoveredDevices.indexWhere((item) => item.mac == d.mac);
        if (existingIdx >= 0) {
          _discoveredDevices[existingIdx] = d;
        } else {
          _discoveredDevices.add(d);
        }
      }
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
      final success = await connectToDevice(targetDevice, displayName: nameLabel);
      if (success) {
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
      return await connectToDevice(foundDevice, displayName: nameLabel);
    } else {
      _isConnecting = false;
      notifyListeners();
      log('Watch $cleanMac not found nearby. Make sure it is powered on.', type: LogType.error);
      return false;
    }
  }

  Future<bool> connectToDevice(BluetoothDevice device, {String? displayName}) async {
    try {
      final devName = displayName ?? (device.platformName.isNotEmpty ? device.platformName : device.remoteId.str);
      log('Connecting to $devName...');
      _isConnecting = true;
      _device = device;
      notifyListeners();

      await device.connect(autoConnect: false, timeout: const Duration(seconds: 12));

      log('Connected! Discovering services...', type: LogType.success);

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
      for (final s in services) {
        log('Service: ${s.uuid.str128}', type: LogType.info);
      }

      final primaryService = services.firstWhere(
        (s) => s.uuid == DizoUuids.servicePrimary || s.uuid.str128.toLowerCase().contains('ff01'),
        orElse: () => throw Exception('Primary DIZO GATT service (FF01) not found!'),
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
        _decodeIncomingPacket(value, 'FF03');
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
          _decodeIncomingPacket(value, 'FEA1');
        });
        _subscriptions.add(fea1Sub);
        log('FEA1 telemetry stream active ✓', type: LogType.success);
      } catch (e) {
        log('FEA1 characteristic optional or inactive: $e', type: LogType.info);
      }

      _isConnected = true;
      _isConnecting = false;
      await _saveLastDevice(device.remoteId.str, devName);
      notifyListeners();

      // Maintain active session with the watch firmware
      log('Authenticating session with watch...');
      await writeFF02(HtsmartProtocol.buildLoginPacket(), 'Session Auth');

      // Auto-synchronize all metrics immediately upon connection
      await syncAll(isAuto: true);

      // Start periodic auto-refresh timer (every 60 seconds while connected)
      _periodicSyncTimer?.cancel();
      _periodicSyncTimer = Timer.periodic(const Duration(seconds: 60), (_) {
        if (_isConnected && !_isSyncing) {
          syncAll(isAuto: true);
        }
      });

      return true;
    } catch (e) {
      log('Connection failed: $e', type: LogType.error);
      _isConnected = false;
      _isConnecting = false;
      notifyListeners();
      return false;
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
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
    _healthMeasureTimer?.cancel();
    _healthMeasureTimer = null;
    _isMeasuringHealth = false;

    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    _isConnected = false;
    _isConnecting = false;
    _isSyncing = false;
    _device = null;
    _charFF02 = null;
    _charFF03 = null;
    _charFEA1 = null;
    // Retain _telemetry cache so health metrics remain visible on the dashboard!
    notifyListeners();
  }

  /// Unified packet processor handling both framed (0xAB) and direct GATT notifications
  void _decodeIncomingPacket(List<int> data, String source) {
    if (data.isEmpty) return;

    // Check for standard HTSmart transport frame: [0xAB, flags, len_hi, len_lo, crc_hi, crc_lo, seq_hi, seq_lo, cmdId, 0x00, keyId, klen_hi, klen_lo, keyData...]
    if (data.length >= 13 && data[0] == 0xAB) {
      final cmdId = data[8];
      final keyId = data[10];
      final keyDataLength = ((data[11] << 8) | data[12]) & 0xFFFF;
      final keyData = data.length >= 13 + keyDataLength
          ? data.sublist(13, 13 + keyDataLength)
          : (data.length > 13 ? data.sublist(13) : <int>[]);

      _handleCmdKey(cmdId, keyId, keyData, source);
      return;
    }

    // Direct / unframed packet format
    if (data.length >= 3 && (data[0] == 0x02 || data[0] == 0x05)) {
      final cmdId = data[0];
      final keyId = data[2];
      final keyData = data.length > 3 ? data.sublist(3) : <int>[];
      _handleCmdKey(cmdId, keyId, keyData, source);
      return;
    }

    // Legacy / Realtek telemetry frames
    _decodeLegacyTelemetry(data);
  }

  void _handleCmdKey(int cmdId, int keyId, List<int> keyData, String source) {
    // 1. TodayTotalData response: Cmd 0x05, Key 0x22 (34)
    if (cmdId == 0x05 && keyId == 0x22 && keyData.length >= 24) {
      final steps = _bytesToInt(keyData, 0, 4);
      final distMeters = _bytesToInt(keyData, 4, 4).toDouble();
      final calories = _bytesToInt(keyData, 8, 4);
      final deepSleep = _bytesToInt(keyData, 12, 4);
      final lightSleep = _bytesToInt(keyData, 16, 4);
      final hr = _bytesToInt(keyData, 20, 4);

      _telemetry = _telemetry.copyWith(
        steps: steps,
        distanceMeters: distMeters,
        calories: calories,
        deepSleepMinutes: deepSleep,
        lightSleepMinutes: lightSleep,
        heartRate: (hr >= 30 && hr <= 220) ? hr : _telemetry.heartRate,
        lastSyncTime: DateTime.now(),
      );
      _saveTelemetry();
      notifyListeners();
      log('Today Metrics: $steps steps, ${(distMeters / 1000.0).toStringAsFixed(2)} km, $calories kcal, Sleep: ${deepSleep + lightSleep}m, HR: $hr BPM', type: LogType.success);
      return;
    }

    // 2. Real-Time Healthy Data stream: Cmd 0x05, Key 0x24 (36)
    if (cmdId == 0x05 && keyId == 0x24 && keyData.length >= 10) {
      final hr = keyData.length > 6 ? keyData[6] & 0xFF : 0;
      final spo2 = keyData.length > 7 ? keyData[7] & 0xFF : 0;
      final dbp = keyData.length > 8 ? keyData[8] & 0xFF : 0;
      final sbp = keyData.length > 9 ? keyData[9] & 0xFF : 0;
      final respiratory = keyData.length > 10 ? keyData[10] & 0xFF : 0;
      final pressure = keyData.length >= 17 ? keyData[16] & 0xFF : null;

      _telemetry = _telemetry.copyWith(
        heartRate: (hr >= 30 && hr <= 220) ? hr : _telemetry.heartRate,
        spo2: (spo2 >= 70 && spo2 <= 100) ? spo2 : _telemetry.spo2,
        diastolicBp: dbp > 30 ? dbp : _telemetry.diastolicBp,
        systolicBp: sbp > 50 ? sbp : _telemetry.systolicBp,
        respiratoryRate: respiratory > 5 ? respiratory : _telemetry.respiratoryRate,
        pressure: pressure,
        lastSyncTime: DateTime.now(),
      );
      _saveTelemetry();
      notifyListeners();
      log('Live Sensor: HR $hr BPM, SpO2 $spo2%, BP $sbp/$dbp mmHg', type: LogType.data);
      return;
    }

    // 3. Battery Status: Cmd 0x02, Key 0x1C (28)
    if (cmdId == 0x02 && keyId == 0x1C && keyData.isNotEmpty) {
      final isCharging = keyData[0] == 1;
      final percent = keyData.length >= 3 ? keyData[2] : (keyData.length >= 2 ? keyData[1] : 0);
      if (percent >= 0 && percent <= 100) {
        _telemetry = _telemetry.copyWith(battery: percent, lastSyncTime: DateTime.now());
        _saveTelemetry();
        notifyListeners();
        log('Battery updated: $percent% ${isCharging ? "(Charging)" : ""}', type: LogType.info);
      }
      return;
    }

    // 4. WristbandConfig TLV response: Cmd 0x02, Key 0x21 (33)
    if (cmdId == 0x02 && keyId == 0x21 && keyData.length >= 40) {
      _parseWristbandConfigTLV(keyData);
      return;
    }

    // 5. Historical sync stream chunk or finish (Cmd 0x05, Key 0x08)
    if (cmdId == 0x05 && keyId == 0x08) {
      // Send sync acknowledgement
      writeFF02(HtsmartProtocol.buildSyncAckPacket(success: true), 'Sync ACK');
      return;
    }
  }

  void _decodeLegacyTelemetry(List<int> data) {
    if (data.length < 2) return;
    final packetType = data[0];
    bool changed = false;

    switch (packetType) {
      case 0x07: // Activity frame (Steps, Calories, Distance)
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
          lastSyncTime: DateTime.now(),
        );
        changed = true;
        break;

      case 0x08: // Heart rate
        if (data.length >= 2 && data[1] >= 30 && data[1] <= 220) {
          _telemetry = _telemetry.copyWith(heartRate: data[1], lastSyncTime: DateTime.now());
          changed = true;
        }
        break;

      case 0x05: // Battery
        if (data.length >= 2 && data[1] <= 100) {
          _telemetry = _telemetry.copyWith(battery: data[1], lastSyncTime: DateTime.now());
          changed = true;
        }
        break;

      case 0x0A: // SpO2
        if (data.length >= 3 && data[2] >= 70 && data[2] <= 100) {
          _telemetry = _telemetry.copyWith(spo2: data[2], lastSyncTime: DateTime.now());
          changed = true;
        }
        break;
    }

    if (changed) {
      _saveTelemetry();
      notifyListeners();
    }
  }

  void _parseWristbandConfigTLV(List<int> bArr) {
    try {
      int idx = 0;
      int brightness = _settings.brightness;
      int timeout = _settings.screenTimeoutSeconds;
      int vibration = _settings.vibrationIntensity;
      bool rtw = _settings.raiseToWakeEnabled;
      int rtwStart = _settings.raiseToWakeStartHour * 60 + _settings.raiseToWakeStartMinute;
      int rtwEnd = _settings.raiseToWakeEndHour * 60 + _settings.raiseToWakeEndMinute;
      bool dndAllDay = _settings.dndAllDay;
      bool dndPeriod = _settings.dndEnabled;
      int dndStart = _settings.dndStartHour * 60 + _settings.dndStartMinute;
      int dndEnd = _settings.dndEndHour * 60 + _settings.dndEndMinute;
      bool continuous = _settings.continuousHealthEnabled;
      int contInterval = _settings.healthIntervalMinutes;
      bool sedentary = _settings.sedentaryEnabled;
      int sedInterval = _settings.sedentaryIntervalMinutes;
      bool drinkWater = _settings.drinkWaterEnabled;
      int drinkInterval = _settings.drinkWaterIntervalMinutes;
      bool is24h = _settings.is24HourFormat;
      bool isMetric = _settings.isMetricUnit;
      bool isRightHand = _settings.isRightHand;

      while (idx + 1 < bArr.length) {
        final type = bArr[idx];
        final len = bArr[idx + 1] & 0xFF;
        final dataStart = idx + 2;
        if (dataStart + len > bArr.length) break;
        final itemData = bArr.sublist(dataStart, dataStart + len);

        switch (type) {
          case 122: // BrightnessVibrateConfig (0x7A)
            if (itemData.length >= 32) {
              timeout = itemData[0];
              brightness = itemData[24].clamp(1, 5);
              vibration = itemData[31].clamp(0, 2);
            }
            break;
          case 45: // TurnWristLightingConfig (0x2D)
            if (itemData.length >= 5) {
              rtw = itemData[0] > 0;
              rtwStart = (itemData[1] << 8) | itemData[2];
              rtwEnd = (itemData[3] << 8) | itemData[4];
            }
            break;
          case 78: // NotDisturbConfig (0x4E)
            if (itemData.length >= 6) {
              dndAllDay = itemData[0] == 1;
              dndPeriod = itemData[1] == 1;
              dndStart = (itemData[2] << 8) | itemData[3];
              dndEnd = (itemData[4] << 8) | itemData[5];
            }
            break;
          case 36: // HealthyConfig (0x24)
            if (itemData.length >= 7) {
              continuous = itemData[0] == 1;
              contInterval = (itemData[5] << 8) | itemData[6];
            }
            break;
          case 39: // SedentaryConfig (0x27)
            if (itemData.length >= 7) {
              sedentary = (itemData[0] & 1) != 0;
              sedInterval = (itemData[5] << 8) | itemData[6];
            }
            break;
          case 42: // DrinkWaterConfig (0x2A)
            if (itemData.length >= 7) {
              drinkWater = itemData[0] > 0;
              drinkInterval = (itemData[1] << 8) | itemData[2];
            }
            break;
          case 26: // FunctionConfig (0x1A)
            if (itemData.length >= 2) {
              isRightHand = (itemData[1] & 1) != 0;
              is24h = (itemData[1] & (1 << 2)) == 0;
              isMetric = (itemData[1] & (1 << 3)) == 0;
            }
            break;
        }
        idx = dataStart + len;
      }

      _settings = _settings.copyWith(
        brightness: brightness,
        screenTimeoutSeconds: timeout,
        vibrationIntensity: vibration,
        raiseToWakeEnabled: rtw,
        raiseToWakeStartHour: rtwStart ~/ 60,
        raiseToWakeStartMinute: rtwStart % 60,
        raiseToWakeEndHour: rtwEnd ~/ 60,
        raiseToWakeEndMinute: rtwEnd % 60,
        dndEnabled: dndPeriod,
        dndAllDay: dndAllDay,
        dndStartHour: dndStart ~/ 60,
        dndStartMinute: dndStart % 60,
        dndEndHour: dndEnd ~/ 60,
        dndEndMinute: dndEnd % 60,
        continuousHealthEnabled: continuous,
        healthIntervalMinutes: contInterval,
        sedentaryEnabled: sedentary,
        sedentaryIntervalMinutes: sedInterval,
        drinkWaterEnabled: drinkWater,
        drinkWaterIntervalMinutes: drinkInterval,
        is24HourFormat: is24h,
        isMetricUnit: isMetric,
        isRightHand: isRightHand,
      );
      _saveSettings();
      notifyListeners();
      log('Watch configuration loaded ✓', type: LogType.success);
    } catch (e) {
      debugPrint('[BleService] Error parsing TLV: $e');
    }
  }

  static int _bytesToInt(List<int> bytes, int offset, int length) {
    int value = 0;
    for (int i = 0; i < length; i++) {
      if (offset + i < bytes.length) {
        value |= (bytes[offset + i] & 0xFF) << (8 * i);
      }
    }
    return value;
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

  /// Unified synchronization of all watch metrics (Time, Battery, Today Metrics, Config, Health)
  Future<void> syncAll({bool isAuto = false}) async {
    if (!_isConnected || _isSyncing) return;
    _isSyncing = true;
    notifyListeners();

    try {
      log(isAuto ? 'Auto-refreshing metrics...' : 'Synchronizing all watch data...', type: LogType.info);

      // 1. Time sync
      await syncTime();
      await Future.delayed(const Duration(milliseconds: 150));

      // 2. Battery query
      await queryBattery();
      await Future.delayed(const Duration(milliseconds: 150));

      // 3. Today's total metrics (Steps, Distance, Calories, Sleep, Heart Rate)
      await queryTodayMetrics();
      await Future.delayed(const Duration(milliseconds: 200));

      // 4. Watch configuration query (Brightness, Reminders, Preferences)
      await queryWatchConfig();
      await Future.delayed(const Duration(milliseconds: 200));

      // 5. Instant sensor health sample (HR & SpO2)
      await triggerLiveHealthSample();

      _telemetry = _telemetry.copyWith(lastSyncTime: DateTime.now());
      await _saveTelemetry();
      log('All metrics updated ✓', type: LogType.success);
    } catch (e) {
      log('Sync error: $e', type: LogType.error);
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> syncTime() async {
    final now = DateTime.now();
    final packet = HtsmartProtocol.buildTimeSyncPacket(now, seq: 1);
    await writeFF02(packet, 'Time Sync');
  }

  Future<void> queryBattery() async {
    final packet = HtsmartProtocol.buildBatteryQueryPacket();
    await writeFF02(packet, 'Battery Query');
  }

  Future<void> queryTodayMetrics() async {
    final packet = HtsmartProtocol.buildTodayTotalDataPacket();
    await writeFF02(packet, 'Today Total Metrics');
  }

  Future<void> queryWatchConfig() async {
    final packet = HtsmartProtocol.buildConfigQueryPacket();
    await writeFF02(packet, 'Watch Config Query');
  }

  /// Triggers a brief live health sensor sample (HR + SpO2)
  Future<void> triggerLiveHealthSample() async {
    final packet = HtsmartProtocol.buildRealTimeHealthPacket(healthyType: 0x07, durationMinutes: 1, enable: true);
    await writeFF02(packet, 'Health Sample Request');
  }

  /// Starts continuous real-time health measurement with live UI countdown
  Future<void> startLiveHealthMeasurement({int durationSeconds = 30}) async {
    if (!_isConnected || _isMeasuringHealth) return;
    _isMeasuringHealth = true;
    notifyListeners();
    log('Starting real-time health sensor measurement...');

    final packet = HtsmartProtocol.buildRealTimeHealthPacket(healthyType: 0x07, durationMinutes: 1, enable: true);
    await writeFF02(packet, 'Start Live Health Measurement');

    _healthMeasureTimer?.cancel();
    _healthMeasureTimer = Timer(Duration(seconds: durationSeconds), () {
      stopLiveHealthMeasurement();
    });
  }

  /// Stops real-time health measurement
  Future<void> stopLiveHealthMeasurement() async {
    _healthMeasureTimer?.cancel();
    _healthMeasureTimer = null;
    _isMeasuringHealth = false;
    notifyListeners();

    if (_isConnected) {
      final packet = HtsmartProtocol.buildRealTimeHealthPacket(healthyType: 0x07, durationMinutes: 0, enable: false);
      await writeFF02(packet, 'Stop Live Health Measurement');
      log('Live health measurement finished ✓', type: LogType.info);
    }
  }

  // --- Watch Options & Configuration Controls ---

  Future<void> updateBrightnessAndTimeout({
    required int brightness,
    required int timeoutSeconds,
    int vibration = 1,
  }) async {
    _settings = _settings.copyWith(
      brightness: brightness,
      screenTimeoutSeconds: timeoutSeconds,
      vibrationIntensity: vibration,
    );
    notifyListeners();
    await _saveSettings();

    if (_isConnected) {
      final packet = HtsmartProtocol.buildBrightnessVibratePacket(
        brightness: brightness,
        timeoutSeconds: timeoutSeconds,
        vibration: vibration,
      );
      await writeFF02(packet, 'Update Brightness & Timeout');
    }
  }

  Future<void> updateRaiseToWake({
    required bool enabled,
    int startHour = 8,
    int startMin = 0,
    int endHour = 22,
    int endMin = 0,
  }) async {
    _settings = _settings.copyWith(
      raiseToWakeEnabled: enabled,
      raiseToWakeStartHour: startHour,
      raiseToWakeStartMinute: startMin,
      raiseToWakeEndHour: endHour,
      raiseToWakeEndMinute: endMin,
    );
    notifyListeners();
    await _saveSettings();

    if (_isConnected) {
      final packet = HtsmartProtocol.buildTurnWristPacket(
        enable: enabled,
        startMinute: startHour * 60 + startMin,
        endMinute: endHour * 60 + endMin,
      );
      await writeFF02(packet, 'Update Raise to Wake');
    }
  }

  Future<void> updateDoNotDisturb({
    required bool enabled,
    bool allDay = false,
    int startHour = 22,
    int startMin = 0,
    int endHour = 7,
    int endMin = 0,
  }) async {
    _settings = _settings.copyWith(
      dndEnabled: enabled,
      dndAllDay: allDay,
      dndStartHour: startHour,
      dndStartMinute: startMin,
      dndEndHour: endHour,
      dndEndMinute: endMin,
    );
    notifyListeners();
    await _saveSettings();

    if (_isConnected) {
      final packet = HtsmartProtocol.buildNotDisturbPacket(
        enableAllDay: allDay,
        enablePeriod: enabled,
        startMinute: startHour * 60 + startMin,
        endMinute: endHour * 60 + endMin,
      );
      await writeFF02(packet, 'Update Do Not Disturb');
    }
  }

  Future<void> updateContinuousHealth({
    required bool enabled,
    int intervalMinutes = 30,
  }) async {
    _settings = _settings.copyWith(
      continuousHealthEnabled: enabled,
      healthIntervalMinutes: intervalMinutes,
    );
    notifyListeners();
    await _saveSettings();

    if (_isConnected) {
      final packet = HtsmartProtocol.buildHealthyMonitorPacket(
        enable: enabled,
        intervalMinutes: intervalMinutes,
      );
      await writeFF02(packet, 'Update Continuous Health');
    }
  }

  Future<void> updateSedentaryReminder({
    required bool enabled,
    int intervalMinutes = 60,
    int startHour = 9,
    int endHour = 18,
    bool dndLunch = true,
  }) async {
    _settings = _settings.copyWith(
      sedentaryEnabled: enabled,
      sedentaryIntervalMinutes: intervalMinutes,
      sedentaryStartHour: startHour,
      sedentaryEndHour: endHour,
      sedentaryDndEnabled: dndLunch,
    );
    notifyListeners();
    await _saveSettings();

    if (_isConnected) {
      final packet = HtsmartProtocol.buildSedentaryPacket(
        enable: enabled,
        dndLunch: dndLunch,
        startMinute: startHour * 60,
        endMinute: endHour * 60,
        intervalMinutes: intervalMinutes,
      );
      await writeFF02(packet, 'Update Sedentary Reminder');
    }
  }

  Future<void> updateDrinkWaterReminder({
    required bool enabled,
    int intervalMinutes = 60,
    int startHour = 9,
    int endHour = 20,
  }) async {
    _settings = _settings.copyWith(
      drinkWaterEnabled: enabled,
      drinkWaterIntervalMinutes: intervalMinutes,
      drinkWaterStartHour: startHour,
      drinkWaterEndHour: endHour,
    );
    notifyListeners();
    await _saveSettings();

    if (_isConnected) {
      final packet = HtsmartProtocol.buildDrinkWaterPacket(
        enable: enabled,
        intervalMinutes: intervalMinutes,
        startMinute: startHour * 60,
        endMinute: endHour * 60,
      );
      await writeFF02(packet, 'Update Drink Water Reminder');
    }
  }

  Future<void> updatePreferences({
    bool? is24Hour,
    bool? isMetric,
    bool? isRightHand,
    bool? weather,
    bool? disconnectReminder,
  }) async {
    _settings = _settings.copyWith(
      is24HourFormat: is24Hour,
      isMetricUnit: isMetric,
      isRightHand: isRightHand,
      weatherEnabled: weather,
      disconnectReminder: disconnectReminder,
    );
    notifyListeners();
    await _saveSettings();

    if (_isConnected) {
      final packet = HtsmartProtocol.buildFunctionConfigPacket(
        is24Hour: _settings.is24HourFormat,
        isMetric: _settings.isMetricUnit,
        isRightHand: _settings.isRightHand,
        weatherEnabled: _settings.weatherEnabled,
        disconnectReminder: _settings.disconnectReminder,
      );
      await writeFF02(packet, 'Update Watch Preferences');
    }
  }

  Future<void> findWatch() async {
    log('Triggering watch vibration alert...');
    final packet = HtsmartProtocol.buildFindWatchPacket();
    await writeFF02(packet, 'Find Watch (Vibrate)');
  }

  Future<void> restartWatch() async {
    log('Restarting watch...');
    final packet = HtsmartProtocol.buildRestartPacket();
    await writeFF02(packet, 'Restart Watch');
  }

  Future<void> turnOffWatch() async {
    log('Powering off watch...');
    final packet = HtsmartProtocol.buildTurnOffPacket();
    await writeFF02(packet, 'Turn Off Watch');
  }

  Future<void> resetWatch() async {
    log('Factory resetting watch...');
    final packet = HtsmartProtocol.buildResetPacket();
    await writeFF02(packet, 'Factory Reset Watch');
  }

  /// Switches active dial slot on watch (e.g. 4 for custom dial)
  Future<void> switchDial(int dialPosition) async {
    log('Switching active dial to slot #$dialPosition...');
    final packet = HtsmartProtocol.buildSwitchDialPacket(dialPosition);
    await writeFF02(packet, 'Switch Dial (#$dialPosition)');
  }

  static String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');

  @override
  void dispose() {
    _periodicSyncTimer?.cancel();
    _healthMeasureTimer?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }
}
