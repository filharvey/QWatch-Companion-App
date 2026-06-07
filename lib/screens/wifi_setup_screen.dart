import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wifi_scan/wifi_scan.dart';
import '../ble/ble_manager.dart';

class WifiSetupScreen extends StatefulWidget {
  const WifiSetupScreen({super.key});

  @override
  State<WifiSetupScreen> createState() => _WifiSetupScreenState();
}

class _WifiSetupScreenState extends State<WifiSetupScreen> {
  final _passwordController = TextEditingController();
  final _ssidController = TextEditingController();
  List<WiFiAccessPoint> _networks = [];
  String? _selectedSsid;
  bool _scanning = false;
  bool _sending = false;
  bool _useManual = false;

  @override
  void initState() {
    super.initState();
    _scanNetworks();
  }

  Future<void> _scanNetworks() async {
    setState(() => _scanning = true);
    try {
      final can = await WiFiScan.instance.canStartScan(askPermissions: true);
      if (can == CanStartScan.yes) {
        await WiFiScan.instance.startScan();
        final results = await WiFiScan.instance.getScannedResults();
        final seen = <String>{};
        setState(() {
          _networks = results
              .where((n) => n.ssid.isNotEmpty && seen.add(n.ssid))
              .toList()
            ..sort((a, b) => (b.level ?? -100).compareTo(a.level ?? -100));
        });
      } else {
        // iOS or no permission — fall back to manual entry
        setState(() => _useManual = true);
      }
    } catch (_) {
      setState(() => _useManual = true);
    } finally {
      setState(() => _scanning = false);
    }
  }

  Future<void> _send() async {
    final ssid = _selectedSsid ?? _ssidController.text.trim();
    final password = _passwordController.text;
    if (ssid.isEmpty) return;

    setState(() => _sending = true);
    try {
      await context.read<BleManager>().sendWifiCredentials(ssid, password);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WiFi credentials sent to watch')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WiFi Setup')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CurrentWifiBanner(),
            if (_useManual) ...[
              TextField(
                controller: _ssidController,
                decoration: const InputDecoration(
                  labelText: 'Network name (SSID)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Select network', style: Theme.of(context).textTheme.titleMedium),
                  TextButton.icon(
                    onPressed: _scanning ? null : _scanNetworks,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Rescan'),
                  ),
                ],
              ),
              if (_scanning)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Expanded(
                  child: RadioGroup<String>(
                    groupValue: _selectedSsid,
                    onChanged: (v) => setState(() => _selectedSsid = v),
                    child: ListView.builder(
                      itemCount: _networks.length,
                      itemBuilder: (_, i) {
                        final n = _networks[i];
                        return RadioListTile<String>(
                          value: n.ssid,
                          title: Text(n.ssid),
                          secondary: Icon(
                            Icons.wifi,
                            color: n.level > -60 ? Colors.green : Colors.orange,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              TextButton(
                onPressed: () => setState(() => _useManual = true),
                child: const Text('Enter network name manually'),
              ),
              const SizedBox(height: 4),
            ],
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _sending ? null : _send,
              child: _sending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Send to Watch'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _ssidController.dispose();
    super.dispose();
  }
}

class _CurrentWifiBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ssid = context.watch<BleManager>().watchSettings.wifiSsid;
    if (ssid.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi, size: 16, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Text('Watch configured for: ', style: TextStyle(color: Colors.blue.shade700)),
          Text(ssid, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
        ],
      ),
    );
  }
}
