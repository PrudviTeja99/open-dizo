import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';

// ══════════════════════════════════════════════════════════════
//  DIZO Watch D — BLE Protocol Constants
//  Reference: BLE protocol specification
//  UUIDs confirmed matching via nRF Connect scan on Watch D
// ══════════════════════════════════════════════════════════════

class DizoUuids {
  static final Guid servicePrimary =
      Guid('000001ff-3c17-d293-8e48-14fe2e4da212');
  static final Guid serviceSecondary =
      Guid('0000d0ff-3c17-d293-8e48-14fe2e4da212');
  static final Guid serviceFee7 =
      Guid('0000fee7-0000-1000-8000-00805f9b34fb');

  // Primary service characteristics
  static final Guid charFF02Write =
      Guid('0000ff02-3c17-d293-8e48-14fe2e4da212'); // Write commands
  static final Guid charFF03Notify =
      Guid('0000ff03-3c17-d293-8e48-14fe2e4da212'); // Receive responses
  static final Guid charFF04Rw =
      Guid('0000ff04-3c17-d293-8e48-14fe2e4da212'); // Config

  // Secondary (D0FF) characteristics
  static final Guid charFFD2 =
      Guid('0000ffd2-3c17-d293-8e48-14fe2e4da212'); // Device info

  // FEE7 service (status heartbeat)
  static final Guid charFEA1Notify =
      Guid('0000fea1-0000-1000-8000-00805f9b34fb'); // Live status
}

// ══════════════════════════════════════════════════════════════
//  MAIN APP
// ══════════════════════════════════════════════════════════════

void main() {
  runApp(const DizoWatchApp());
}

class DizoWatchApp extends StatelessWidget {
  const DizoWatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DIZO Watch Sync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0F13),
        colorSchemeSeed: const Color(0xFF6C63FF),
        useMaterial3: true,
        cardTheme: const CardTheme(
          color: Color(0xFF1A1A24),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            side: BorderSide(color: Color(0xFF2A2A3E)),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  HOME PAGE
// ══════════════════════════════════════════════════════════════

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Connection state
  BluetoothDevice? _device;
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isScanning = false;

  // BLE characteristics
  BluetoothCharacteristic? _charFF02;
  BluetoothCharacteristic? _charFF03;
  BluetoothCharacteristic? _charFEA1;

  // Live data from watch
  int? _steps;
  int? _heartRate;
  int? _battery;
  int? _calories;
  int? _spo2;
  double? _distanceMeters;

  // Log entries
  final List<LogEntry> _logs = [];
  final ScrollController _logScrollController = ScrollController();

  // Subscriptions
  final List<StreamSubscription> _subscriptions = [];

  // Clock timer
  Timer? _clockTimer;
  String _currentTime = '--:--:--';
  String _currentDate = '';

  @override
  void initState() {
    super.initState();
    _updateClock();
    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateClock(),
    );
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _logScrollController.dispose();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  void _updateClock() {
    final now = DateTime.now();
    setState(() {
      _currentTime = DateFormat('HH:mm:ss').format(now);
      _currentDate = DateFormat('EEEE, MMMM d, y').format(now);
    });
  }

  // ── Logging ──

  void _log(String message, {LogType type = LogType.info}) {
    setState(() {
      _logs.add(LogEntry(
        message: message,
        type: type,
        time: DateFormat('HH:mm:ss').format(DateTime.now()),
      ));
      if (_logs.length > 200) _logs.removeAt(0);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');

  // ── Permissions ──

  Future<bool> _requestPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    final allGranted = statuses.values.every(
      (s) => s.isGranted || s.isLimited,
    );

    if (!allGranted) {
      _log('Bluetooth/Location permissions denied', type: LogType.error);
    }
    return allGranted;
  }

  // ── Scan & Connect ──

  Future<void> _scanAndConnect() async {
    if (_isConnected) {
      _disconnect();
      return;
    }

    if (!await _requestPermissions()) return;

    // Check if Bluetooth is on
    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      _log('Bluetooth is OFF — please enable it', type: LogType.error);
      await FlutterBluePlus.turnOn();
      return;
    }

    setState(() {
      _isScanning = true;
      _isConnecting = false;
    });
    _log('Scanning for DIZO Watch D...');

    // Start scan
    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 12),
      androidScanMode: AndroidScanMode.lowLatency,
    );

    // Listen for scan results
    bool found = false;
    await for (final results in FlutterBluePlus.scanResults) {
      for (final r in results) {
        final name = r.device.platformName;
        if (name.toUpperCase().contains('DIZO')) {
          _log('Found: $name (${r.device.remoteId})', type: LogType.success);
          await FlutterBluePlus.stopScan();
          found = true;
          setState(() {
            _isScanning = false;
            _isConnecting = true;
          });
          await _connectToDevice(r.device);
          return;
        }
      }
    }

    setState(() => _isScanning = false);
    if (!found) {
      _log('DIZO Watch D not found. Make sure it\'s nearby and not connected to another device.', type: LogType.error);
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      _log('Connecting to ${device.platformName}...');
      await device.connect(autoConnect: false, timeout: const Duration(seconds: 10));

      _log('Connected! Discovering services...', type: LogType.success);
      _device = device;

      // Listen for disconnection
      final sub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _log('Watch disconnected', type: LogType.error);
          _onDisconnected();
        }
      });
      _subscriptions.add(sub);

      // Discover services
      final services = await device.discoverServices();

      _log('Found ${services.length} services');
      for (final s in services) {
        _log('  Service: ${s.uuid}', type: LogType.info);
      }

      // Get primary service and characteristics
      final primaryService = services.firstWhere(
        (s) => s.uuid == DizoUuids.servicePrimary,
        orElse: () => throw Exception('Primary service not found!'),
      );

      _charFF02 = primaryService.characteristics.firstWhere(
        (c) => c.uuid == DizoUuids.charFF02Write,
        orElse: () => throw Exception('FF02 (Write) not found!'),
      );
      _log('FF02 (Write) ✓', type: LogType.success);

      _charFF03 = primaryService.characteristics.firstWhere(
        (c) => c.uuid == DizoUuids.charFF03Notify,
        orElse: () => throw Exception('FF03 (Notify) not found!'),
      );

      // Enable FF03 notifications
      await _charFF03!.setNotifyValue(true);
      final ff03Sub = _charFF03!.onValueReceived.listen((value) {
        _log('FF03 ← ${_hex(value)}', type: LogType.data);
      });
      _subscriptions.add(ff03Sub);
      _log('FF03 notifications ✓', type: LogType.success);

      // Try FEA1 (live status heartbeat)
      try {
        final fee7Service = services.firstWhere(
          (s) => s.uuid == DizoUuids.serviceFee7,
        );
        _charFEA1 = fee7Service.characteristics.firstWhere(
          (c) => c.uuid == DizoUuids.charFEA1Notify,
        );
        await _charFEA1!.setNotifyValue(true);
        final fea1Sub = _charFEA1!.onValueReceived.listen((value) {
          _log('FEA1 ← ${_hex(value)}', type: LogType.data);
          _decodeFEA1(value);
        });
        _subscriptions.add(fea1Sub);
        _log('FEA1 (Status) ✓', type: LogType.success);
      } catch (e) {
        _log('FEA1 not available: $e', type: LogType.error);
      }

      setState(() {
        _isConnected = true;
        _isConnecting = false;
      });

      // Auto sync time on connect
      _log('Auto-syncing time...');
      await _syncTime();

    } catch (e) {
      _log('Connection failed: $e', type: LogType.error);
      setState(() {
        _isConnecting = false;
        _isConnected = false;
      });
    }
  }

  void _disconnect() {
    _device?.disconnect();
    _onDisconnected();
    _log('Disconnected by user');
  }

  void _onDisconnected() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    setState(() {
      _isConnected = false;
      _isConnecting = false;
      _device = null;
      _charFF02 = null;
      _charFF03 = null;
      _charFEA1 = null;
      _steps = null;
      _heartRate = null;
      _battery = null;
      _calories = null;
      _spo2 = null;
      _distanceMeters = null;
    });
  }

  // ── Decode FEA1 status packets ──

  void _decodeFEA1(List<int> data) {
    if (data.length < 2) return;
    final packetType = data[0];

    setState(() {
      switch (packetType) {
        case 0x07: // Activity status frame
          if (data.length >= 3) {
            _steps = (data[2] << 8) | data[1];
          }
          if (data.length >= 6) {
            _calories = ((data[5] << 8) | data[4]) ~/ 10;
          }
          if (data.length >= 9) {
            _distanceMeters = ((data[8] << 8) | data[7]) / 100.0;
          }
          break;
        case 0x08: // Heart rate
          if (data.length >= 2 && data[1] >= 30 && data[1] <= 220) {
            _heartRate = data[1];
          }
          break;
        case 0x05: // Battery
          if (data.length >= 2 && data[1] <= 100) {
            _battery = data[1];
          }
          break;
        case 0x0A: // SpO2
          if (data.length >= 3 && data[2] >= 80 && data[2] <= 100) {
            _spo2 = data[2];
          }
          break;
      }
    });
  }

  // ══════════════════════════════════════════
  //  COMMANDS → FF02
  // ══════════════════════════════════════════

  Future<void> _writeFF02(List<int> bytes, String label) async {
    if (_charFF02 == null) {
      _log('Not connected!', type: LogType.error);
      return;
    }
    try {
      _log('$label → FF02: ${_hex(bytes)}', type: LogType.send);
      await _charFF02!.write(bytes, withoutResponse: false);
      _log('$label sent ✓', type: LogType.success);
    } catch (e) {
      // Fallback: write without response
      try {
        await _charFF02!.write(bytes, withoutResponse: true);
        _log('$label sent (no-response) ✓', type: LogType.success);
      } catch (e2) {
        _log('$label failed: $e2', type: LogType.error);
      }
    }
  }

  /// Linwear official binding algorithm (bandingKeyAlgo:mac:)
  /// Key = ((random % 10000) + sum(mac_bytes)) % 1000000
  int _calcBindingKey(int randomVal, String mac) {
    final cleanMac = mac.replaceAll(':', '').replaceAll('-', '').trim();
    int macSum = 0;
    if (cleanMac.length == 12) {
      for (int i = 0; i < 12; i += 2) {
        macSum += int.parse(cleanMac.substring(i, i + 2), radix: 16);
      }
    } else {
      // Fallback to DIZO Watch D known MAC: CC:EA:FF:AA:42:7F
      macSum = 0xCC + 0xEA + 0xFF + 0xAA + 0x42 + 0x7F; // 1056
    }
    return ((randomVal % 10000) + macSum) % 1000000;
  }

  /// Linwear Time Sync Protocol:
  /// 1. Handshake/Binding: AT+BDQ:<calculated_key>,<random_val>
  /// 2. UTC Time:          AT+SUT:<unix_timestamp>
  /// 3. Trigger Mode:      AT+SUT:0
  /// 4. Timezone offset:   AT+STZ:<minutes_from_gmt>
  /// 5. Time format:       AT+SUM:0 (12h) or AT+SUM:1 (24h)
  // ── HTSmart / FitCloudPro Protocol Implementation ──
  static const List<int> _crcTable = [
    0, 49345, 49537, 320, 49921, 960, 640, 49729, 50689, 1728, 1920, 51009, 1280, 50625, 50305, 1088,
    52225, 3264, 3456, 52545, 3840, 53185, 52865, 3648, 2560, 51905, 52097, 2880, 51457, 2496, 2176, 51265,
    55297, 6336, 6528, 55617, 6912, 56257, 55937, 6720, 7680, 57025, 57217, 8000, 56577, 7616, 7296, 56385,
    5120, 54465, 54657, 5440, 55041, 6080, 5760, 54849, 53761, 4800, 4992, 54081, 4352, 53697, 53377, 4160,
    61441, 12480, 12672, 61761, 13056, 62401, 62081, 12864, 13824, 63169, 63361, 14144, 62721, 13760, 13440, 62529,
    15360, 64705, 64897, 15680, 65281, 16320, 16000, 65089, 64001, 15040, 15232, 64321, 14592, 63937, 63617, 14400,
    10240, 59585, 59777, 10560, 60161, 11200, 10880, 59969, 60929, 11968, 12160, 61249, 11520, 60865, 60545, 11328,
    58369, 9408, 9600, 58689, 9984, 59329, 59009, 9792, 8704, 58049, 58241, 9024, 57601, 8640, 8320, 57409,
    40961, 24768, 24960, 41281, 25344, 41921, 41601, 25152, 26112, 42689, 42881, 26432, 42241, 26048, 25728, 42049,
    27648, 44225, 44417, 27968, 44801, 28608, 28288, 44609, 43521, 27328, 27520, 43841, 26880, 43457, 43137, 26688,
    30720, 47297, 47489, 31040, 47873, 31680, 31360, 47681, 48641, 32448, 32640, 48961, 32000, 48577, 48257, 31808,
    46081, 29888, 30080, 46401, 30464, 47041, 46721, 30272, 29184, 45761, 45953, 29504, 45313, 29120, 28800, 45121,
    20480, 37057, 37249, 20800, 37633, 21440, 21120, 37441, 38401, 22208, 22400, 38721, 21760, 38337, 38017, 21568,
    39937, 23744, 23936, 40257, 24320, 40897, 40577, 24128, 23040, 39617, 39809, 23360, 39169, 22976, 22656, 38977,
    34817, 18624, 18816, 35137, 19200, 35777, 35457, 19008, 19968, 36545, 36737, 20288, 36097, 19904, 19584, 35905,
    17408, 33985, 34177, 17728, 34561, 18368, 18048, 34369, 33281, 17088, 17280, 33601, 16640, 33217, 32897, 16448
  ];

  static int _calcCrc16(List<int> data) {
    int crc = 0;
    for (final b in data) {
      crc = ((crc >> 8) ^ _crcTable[(b ^ crc) & 0xFF]) & 0xFFFF;
    }
    return crc;
  }

  static List<int> _buildHTSmartTimePacket(DateTime dt, {int seq = 1}) {
    final yearVal = dt.year - 2000;
    final month = dt.month;
    final day = dt.day;
    final hour = dt.hour;
    final minute = dt.minute;
    final second = dt.second;

    final b0 = ((yearVal << 2) | (month >> 2)) & 0xFF;
    final b1 = ((month << 6) | (day << 1) | (hour >> 4)) & 0xFF;
    final b2 = ((hour << 4) | (minute >> 2)) & 0xFF;
    final b3 = ((minute << 6) | second) & 0xFF;

    final cmdPacket = [
      0x02, 0x00,       // CmdPacket: cmdId=2 (SET), version=0
      0x01, 0x00, 0x04, // KeyPacket: keyId=1 (TIME), len=4
      b0, b1, b2, b3    // 4-byte packed time
    ];

    final len = cmdPacket.length;
    final crc = _calcCrc16(cmdPacket);

    return [
      0xAB, 0x00,                 // Magic & Flags
      (len >> 8) & 0xFF, len & 0xFF, // Length (Big Endian)
      (crc >> 8) & 0xFF, crc & 0xFF, // CRC16 (Big Endian)
      (seq >> 8) & 0xFF, seq & 0xFF, // Sequence ID
      ...cmdPacket,
    ];
  }

  Future<void> _syncTime() async {
    final now = DateTime.now();
    _log('Synchronizing DIZO Watch D via HTSmart protocol...');

    final packet = _buildHTSmartTimePacket(now, seq: 1);
    _log('Sending 17-byte HTSmart frame: ${_hex(packet)}', type: LogType.send);

    await _writeFF02(packet, 'Time Sync (HTSmart)');
    _log('Time sync packet dispatched to FF02! Waiting for ACK...', type: LogType.success);
  }

  Future<void> _syncSteps() async {
    await _writeFF02([0x03, 0x01], '🚶 Steps sync');
  }

  Future<void> _syncHealth() async {
    await _writeFF02([0x03, 0x03], '❤️ HR sync');
    await Future.delayed(const Duration(milliseconds: 300));
    await _writeFF02([0x03, 0x04], '🩸 SpO2 sync');
  }

  Future<void> _syncSleep() async {
    await _writeFF02([0x03, 0x02], '😴 Sleep sync');
  }

  Future<void> _readBattery() async {
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
        _log('FFD2 ← ${_hex(value)}', type: LogType.data);
        if (value.isNotEmpty) {
          setState(() => _battery = value[0]);
          _log('Battery: ${value[0]}%');
        }
      }
    } catch (e) {
      _log('Battery read failed: $e', type: LogType.error);
    }
  }

  // ══════════════════════════════════════════
  //  UI
  // ══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            // ── Header ──
            Center(
              child: Column(
                children: [
                  const Text('⌚', style: TextStyle(fontSize: 36)),
                  const SizedBox(height: 4),
                  const Text(
                    'DIZO Watch D',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'BLE Time Sync',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Status pill ──
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A24),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: const Color(0xFF2A2A3E)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isConnected
                            ? Colors.greenAccent
                            : _isConnecting || _isScanning
                                ? Colors.orangeAccent
                                : Colors.redAccent,
                        boxShadow: _isConnected
                            ? [BoxShadow(color: Colors.greenAccent.withOpacity(0.5), blurRadius: 6)]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isConnected
                          ? 'Connected — ${_device?.platformName ?? "Watch"}'
                          : _isConnecting
                              ? 'Connecting...'
                              : _isScanning
                                  ? 'Scanning...'
                                  : 'Disconnected',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Connect / Disconnect button ──
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: (_isScanning || _isConnecting) ? null : _scanAndConnect,
                icon: Icon(_isConnected ? Icons.link_off : Icons.bluetooth_searching),
                label: Text(
                  _isConnected ? 'Disconnect' : 'Connect to Watch',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isConnected ? Colors.grey[800] : accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Time card ──
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📅  PHONE TIME',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.5,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22223A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _currentTime,
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _currentDate,
                            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isConnected ? _syncTime : null,
                        icon: const Text('🕐', style: TextStyle(fontSize: 18)),
                        label: const Text('Sync Time Now'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.grey[700]!),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Actions card ──
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚡  ACTIONS',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.5,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _actionButton('🔋', 'Battery', _isConnected ? _readBattery : null)),
                        const SizedBox(width: 10),
                        Expanded(child: _actionButton('🚶', 'Sync Steps', _isConnected ? _syncSteps : null)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _actionButton('❤️', 'Sync Health', _isConnected ? _syncHealth : null)),
                        const SizedBox(width: 10),
                        Expanded(child: _actionButton('😴', 'Sync Sleep', _isConnected ? _syncSleep : null)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Live data card ──
            if (_isConnected)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📊  WATCH DATA',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.5,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _dataCell('${_steps ?? "--"}', 'Steps')),
                          const SizedBox(width: 8),
                          Expanded(child: _dataCell('${_heartRate ?? "--"}', 'Heart Rate')),
                          const SizedBox(width: 8),
                          Expanded(child: _dataCell('${_battery ?? "--"}', 'Battery %')),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _dataCell('${_calories ?? "--"}', 'Calories')),
                          const SizedBox(width: 8),
                          Expanded(child: _dataCell('${_spo2 ?? "--"}', 'SpO2 %')),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _dataCell(
                              _distanceMeters != null
                                  ? _distanceMeters!.toStringAsFixed(1)
                                  : '--',
                              'Distance (m)',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),

            // ── BLE Log ──
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '📡  BLE LOG',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.5,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _logs.clear()),
                          child: Text(
                            'Clear',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A0A10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF2A2A3E)),
                      ),
                      child: ListView.builder(
                        controller: _logScrollController,
                        padding: const EdgeInsets.all(10),
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          final entry = _logs[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '[${entry.time}] ',
                                    style: TextStyle(color: Colors.grey[700], fontSize: 11),
                                  ),
                                  TextSpan(
                                    text: entry.message,
                                    style: TextStyle(color: entry.color, fontSize: 11),
                                  ),
                                ],
                              ),
                              style: const TextStyle(fontFamily: 'monospace', height: 1.5),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            Center(
              child: Text(
                'Protocol: OpenWear (github.com/Jason3105/OpenWear)\n'
                'No cloud · No accounts · 100% local',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(String icon, String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF22223A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A2A3E)),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: onTap != null ? Colors.white : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dataCell(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF22223A),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6C63FF),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  LOG ENTRY MODEL
// ══════════════════════════════════════════════════════════════

enum LogType { info, success, error, data, send }

class LogEntry {
  final String message;
  final LogType type;
  final String time;

  LogEntry({required this.message, required this.type, required this.time});

  Color get color {
    switch (type) {
      case LogType.info:
        return const Color(0xFF88AADD);
      case LogType.success:
        return const Color(0xFF00E676);
      case LogType.error:
        return const Color(0xFFFF5252);
      case LogType.data:
        return const Color(0xFFFFAB40);
      case LogType.send:
        return const Color(0xFFCE93D8);
    }
  }
}
