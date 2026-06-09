import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../ble/ble_manager.dart';
import 'wifi_setup_screen.dart';
import 'steps_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _sendingTime = false;
  bool _sendingWeather = false;

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleManager>();

    return Scaffold(
      appBar: AppBar(title: const Text('QWatch')),
      body: ble.isConnected ? _connected(context, ble) : _disconnected(context, ble),
    );
  }

  Future<void> _tapSendTime(BleManager ble) async {
    setState(() => _sendingTime = true);
    await ble.sendTimeNow();
    if (mounted) setState(() => _sendingTime = false);
  }

  Future<void> _tapSendWeather(BleManager ble) async {
    setState(() => _sendingWeather = true);
    await ble.sendWeatherNow();
    if (mounted) setState(() => _sendingWeather = false);
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
              const SizedBox(height: 8),
              _DebugCard(
                sendingTime: _sendingTime,
                sendingWeather: _sendingWeather,
                onSendTime: () => _tapSendTime(ble),
                onSendWeather: () => _tapSendWeather(ble),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DebugCard extends StatelessWidget {
  final bool sendingTime;
  final bool sendingWeather;
  final VoidCallback onSendTime;
  final VoidCallback onSendWeather;

  const _DebugCard({
    required this.sendingTime,
    required this.sendingWeather,
    required this.onSendTime,
    required this.onSendWeather,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bug_report,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text('Debug',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        )),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: sendingTime ? null : onSendTime,
                    icon: sendingTime
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.access_time, size: 18),
                    label: const Text('Send Time'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: sendingWeather ? null : onSendWeather,
                    icon: sendingWeather
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud, size: 18),
                    label: const Text('Send Weather'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
