import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../ble/ble_manager.dart';
import 'wifi_setup_screen.dart';
import 'steps_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleManager>();

    return Scaffold(
      appBar: AppBar(title: const Text('QWatch')),
      body: ble.isConnected ? _connected(context, ble) : _disconnected(context, ble),
    );
  }

  Widget _disconnected(BuildContext context, BleManager ble) {
    final scanning = ble.connectionState == WatchConnectionState.scanning ||
        ble.connectionState == WatchConnectionState.connecting;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.watch, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No watch connected', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 24),
          scanning
              ? const CircularProgressIndicator()
              : FilledButton.icon(
                  onPressed: () => ble.scan(),
                  icon: const Icon(Icons.bluetooth_searching),
                  label: const Text('Scan for QWatch'),
                ),
        ],
      ),
    );
  }

  Widget _connected(BuildContext context, BleManager ble) {
    return Column(
      children: [
        // Status bar
        Container(
          color: Colors.green.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.bluetooth_connected, color: Colors.green, size: 16),
              const SizedBox(width: 8),
              Text('QWatch connected', style: TextStyle(color: Colors.green.shade800)),
              const Spacer(),
              Icon(
                ble.wifiConnected ? Icons.wifi : Icons.wifi_off,
                size: 16,
                color: ble.wifiConnected ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 8),
              const Icon(Icons.battery_std, size: 16),
              Text('${ble.batteryPercent}%'),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => ble.disconnect(),
                child: const Text('Disconnect'),
              ),
            ],
          ),
        ),

        // Navigation tiles
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _NavTile(
                icon: Icons.wifi,
                title: 'WiFi Setup',
                subtitle: ble.wifiConnected ? 'Connected' : 'Not connected — tap to configure',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const WifiSetupScreen())),
              ),
              _NavTile(
                icon: Icons.directions_walk,
                title: 'Step History',
                subtitle: '7-day chart',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const StepsScreen())),
              ),
              _NavTile(
                icon: Icons.settings,
                title: 'Settings',
                subtitle: 'Watch face, clock mode',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen())),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
