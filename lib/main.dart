import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ble/ble_manager.dart';
import 'screens/home_screen.dart';
import 'services/background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initBackgroundService();
  runApp(
    ChangeNotifierProvider(
      create: (_) => BleManager(),
      child: const QWatchApp(),
    ),
  );
}

class QWatchApp extends StatelessWidget {
  const QWatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QWatch',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
