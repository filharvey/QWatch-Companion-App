import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/step_entry.dart';
import '../models/watch_settings.dart';
import '../services/phone_weather_service.dart';
import '../services/background_service.dart';
import 'qwatch_uuids.dart';

enum WatchConnectionState { disconnected, scanning, connecting, connected }

class BleManager extends ChangeNotifier {
  BluetoothDevice? _device;
  Map<String, BluetoothCharacteristic> _chars = {};
  StreamSubscription? _batterySubscription;
  StreamSubscription? _statusSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _bgTickSubscription;
  bool _autoReconnect = false;

  // Track last send times for rate limiting
  DateTime? _lastTimeSent;
  DateTime? _lastWeatherSent;

  WatchConnectionState connectionState = WatchConnectionState.disconnected;
  int batteryPercent = 0;
  bool wifiConnected = false;
  bool ntpSynced = false;
  WatchSettings watchSettings = WatchSettings.defaults();

  bool get isConnected => connectionState == WatchConnectionState.connected;

  // Scan for a QWatch device by name (avoids 128-bit UUID filtering issues on Android).
  Future<void> scan() async {
    if (connectionState != WatchConnectionState.disconnected) return;

    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    connectionState = WatchConnectionState.scanning;
    notifyListeners();

    final completer = Completer<BluetoothDevice?>();

    final sub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final advName = r.advertisementData.advName;
        final platName = r.device.platformName;
        final name = advName.isNotEmpty ? advName : platName;
        if (name == 'QWatch' && !completer.isCompleted) {
          completer.complete(r.device);
        }
      }
    });

    await FlutterBluePlus.startScan();

    // Wait for device found OR 20 s timeout
    final device = await completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () => null,
    );

    await sub.cancel();
    await FlutterBluePlus.stopScan();

    if (device != null) {
      // Let the BLE stack settle before connecting — prevents Android error 133
      await Future.delayed(const Duration(milliseconds: 500));
      await connect(device);
    } else {
      connectionState = WatchConnectionState.disconnected;
      notifyListeners();
    }
  }

  Future<void> connect(BluetoothDevice device) async {
    connectionState = WatchConnectionState.connecting;
    notifyListeners();

    try {
      await device.connect(timeout: const Duration(seconds: 10));
      _device = device;
      _autoReconnect = true;

      // Watch for unexpected disconnects and auto-reconnect
      await _connectionSubscription?.cancel();
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected && _autoReconnect) {
          _onUnexpectedDisconnect();
        }
      });

      final services = await device.discoverServices();
      final watchService = services.firstWhere(
        (s) => s.serviceUuid == Guid(QWatchUUIDs.service),
      );

      _chars = {
        for (final c in watchService.characteristics)
          c.characteristicUuid.toString(): c,
      };

      await _subscribeToBattery();
      await _subscribeToStatus();
      watchSettings = await readSettings();

      connectionState = WatchConnectionState.connected;
      notifyListeners();

      // Start background service and immediate sync
      await startBackgroundService();
      updateBackgroundNotification('Connected to QWatch');
      _startBackgroundTicks();
      await _sendTime();
      await _fetchAndSendWeather();
    } catch (e) {
      print('[BLE] connect failed: $e');
      connectionState = WatchConnectionState.disconnected;
      notifyListeners();
    }
  }

  void _onUnexpectedDisconnect() async {
    await _bgTickSubscription?.cancel();
    _bgTickSubscription = null;
    await _batterySubscription?.cancel();
    await _statusSubscription?.cancel();
    _chars = {};
    connectionState = WatchConnectionState.disconnected;
    notifyListeners();
    await stopBackgroundService();

    // Wait for the watch to wake and restart advertising
    await Future.delayed(const Duration(seconds: 3));
    if (_autoReconnect) {
      scan();
    }
  }

  Future<void> disconnect() async {
    _autoReconnect = false;
    await _bgTickSubscription?.cancel();
    _bgTickSubscription = null;
    await _connectionSubscription?.cancel();
    await _batterySubscription?.cancel();
    await _statusSubscription?.cancel();
    await _device?.disconnect();
    _device = null;
    _chars = {};
    connectionState = WatchConnectionState.disconnected;
    notifyListeners();
    await stopBackgroundService();
  }

  // WiFi provisioning
  Future<void> sendWifiCredentials(String ssid, String password) async {
    await _write(QWatchUUIDs.wifiSsid, utf8.encode(ssid));
    await _write(QWatchUUIDs.wifiPassword, utf8.encode(password));
    await _write(QWatchUUIDs.wifiApply, [0x01]);
  }

  // Read 7-day step history
  Future<List<StepEntry>> readSteps() async {
    final bytes = await _read(QWatchUUIDs.steps);
    return StepEntry.fromBytes(bytes);
  }

  // Read + write settings JSON
  Future<WatchSettings> readSettings() async {
    final bytes = await _read(QWatchUUIDs.settings);
    final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    return WatchSettings.fromJson(json);
  }

  Future<void> writeSettings(WatchSettings settings) async {
    final bytes = utf8.encode(jsonEncode(settings.toJson()));
    await _write(QWatchUUIDs.settings, bytes);
  }

  // Internal helpers
  Future<List<int>> _read(String uuid) async {
    final c = _chars[uuid];
    if (c == null) throw StateError('Characteristic $uuid not found');
    return c.read();
  }

  Future<void> _write(String uuid, List<int> data) async {
    final c = _chars[uuid];
    if (c == null) throw StateError('Characteristic $uuid not found');
    await c.write(data, withoutResponse: false);
  }

  Future<void> _subscribeToBattery() async {
    final c = _chars[QWatchUUIDs.battery];
    if (c == null) return;
    await c.setNotifyValue(true);
    _batterySubscription = c.lastValueStream.listen((bytes) {
      if (bytes.isNotEmpty) {
        batteryPercent = bytes[0];
        notifyListeners();
      }
    });
  }

  Future<void> _subscribeToStatus() async {
    final c = _chars[QWatchUUIDs.status];
    if (c == null) return;
    await c.setNotifyValue(true);
    _statusSubscription = c.lastValueStream.listen((bytes) {
      if (bytes.length >= 2) {
        wifiConnected = bytes[0] != 0;
        ntpSynced = bytes[1] != 0;
        notifyListeners();
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Background tick handling
  // ---------------------------------------------------------------------------

  void _startBackgroundTicks() {
    _bgTickSubscription?.cancel();
    _bgTickSubscription =
        FlutterBackgroundService().on('tick').listen((_) => _onTick());
  }

  Future<void> _onTick() async {
    if (!isConnected) return;

    final now = DateTime.now();

    // Send time every 5 minutes
    final lastTime = _lastTimeSent;
    if (lastTime == null || now.difference(lastTime).inMinutes >= 5) {
      await _sendTime();
    }

    // Send weather every 30 minutes
    final lastWeather = _lastWeatherSent;
    if (lastWeather == null || now.difference(lastWeather).inMinutes >= 30) {
      await _fetchAndSendWeather();
    }
  }

  Future<void> sendTimeNow() => _sendTime();
  Future<void> sendWeatherNow() => _fetchAndSendWeather();

  Future<void> _sendTime() async {
    final c = _chars[QWatchUUIDs.time];
    if (c == null) {
      print('[BLE>>] Time characteristic not found');
      return;
    }

    final now = DateTime.now();
    final unixTs = now.millisecondsSinceEpoch ~/ 1000;
    final utcOffset = now.timeZoneOffset.inSeconds;

    final buf = ByteData(8);
    buf.setUint32(0, unixTs, Endian.little);
    buf.setInt32(4, utcOffset, Endian.little);

    print('[BLE>>] Sending time: unix=$unixTs  utc_offset=${utcOffset}s  '
        '(${now.toLocal()})');
    try {
      await c.write(buf.buffer.asUint8List(), withoutResponse: false);
      _lastTimeSent = now;
      print('[BLE>>] Time sent OK');
    } catch (e) {
      print('[BLE>>] Time send failed: $e');
    }
  }

  Future<void> _fetchAndSendWeather() async {
    final c = _chars[QWatchUUIDs.weather];
    if (c == null) {
      print('[BLE>>] Weather characteristic not found');
      return;
    }

    print('[BLE>>] Fetching weather from Open-Meteo...');
    final result = await PhoneWeatherService.fetch();
    if (result == null) {
      print('[BLE>>] Weather fetch failed — not sending');
      return;
    }

    final json = result.toWatchJson();
    print('[BLE>>] Sending weather: $json');
    try {
      await c.write(utf8.encode(json), withoutResponse: false);
      _lastWeatherSent = DateTime.now();
      print('[BLE>>] Weather sent OK');
    } catch (e) {
      print('[BLE>>] Weather send failed: $e');
    }
  }
}
