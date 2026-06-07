import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Called from main() before runApp().
Future<void> initBackgroundService() async {
  // Android 13+ requires the notification channel to exist before the
  // foreground service can call startForeground() — create it explicitly.
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'qwatch_sync',
    'QWatch Sync',
    description: 'Keeps QWatch time and weather in sync',
    importance: Importance.low,
  );
  final FlutterLocalNotificationsPlugin fln = FlutterLocalNotificationsPlugin();
  await fln
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // Also request POST_NOTIFICATIONS permission (Android 13+).
  await fln
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();

  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: _onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'qwatch_sync',
      initialNotificationTitle: 'QWatch',
      initialNotificationContent: 'Syncing time and weather…',
      foregroundServiceNotificationId: 8877,
      foregroundServiceTypes: [AndroidForegroundType.connectedDevice],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: _onStart,
      onBackground: _onIosBackground,
    ),
  );
}

/// Starts the background service (call when BLE connects).
Future<void> startBackgroundService() async {
  final service = FlutterBackgroundService();
  if (!await service.isRunning()) {
    await service.startService();
  }
}

/// Stops the background service (call when BLE disconnects).
Future<void> stopBackgroundService() async {
  final service = FlutterBackgroundService();
  service.invoke('stop');
}

/// Updates the foreground notification text (e.g. "Connected to QWatch").
void updateBackgroundNotification(String content) {
  final service = FlutterBackgroundService();
  service.invoke('update_notification', {'content': content});
}

// ---------------------------------------------------------------------------
// Background isolate entry point
// ---------------------------------------------------------------------------

@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  service.on('stop').listen((_) => service.stopSelf());

  service.on('update_notification').listen((data) {
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'QWatch',
        content: data?['content'] as String? ?? 'Connected',
      );
    }
  });

  // Tick every minute — main isolate listens and decides what to send
  Timer.periodic(const Duration(minutes: 1), (_) {
    service.invoke('tick', {
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  });

  // Send an immediate tick on start so time is synced right away
  await Future.delayed(const Duration(seconds: 2));
  service.invoke('tick', {'ts': DateTime.now().millisecondsSinceEpoch});
}

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  return true;
}
