import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../ble/ble_manager.dart';
import '../models/watch_settings.dart';
import '../models/face_assets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  WatchSettings? _settings;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final s = await context.read<BleManager>().readSettings();
      setState(() => _settings = s);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_settings == null) return;
    setState(() => _saving = true);
    try {
      await context.read<BleManager>().writeSettings(_settings!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved to watch')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          if (!_loading && _settings != null)
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ],
      ));
    }
    final s = _settings!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Clock mode
        Text('Clock Mode', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<ClockMode>(
          segments: const [
            ButtonSegment(value: ClockMode.digital, label: Text('Digital'), icon: Icon(Icons.access_time)),
            ButtonSegment(value: ClockMode.analogue, label: Text('Analogue'), icon: Icon(Icons.watch)),
          ],
          selected: {s.clockMode},
          onSelectionChanged: (v) => setState(() => _settings = s.copyWith(clockMode: v.first)),
        ),

        const Divider(height: 32),

        if (s.clockMode == ClockMode.digital) ...[
          Text('Digital Face', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _FaceSelector(
            names: s.digitalFaces.isNotEmpty ? s.digitalFaces : null,
            count: s.digitalFaces.isNotEmpty ? s.digitalFaces.length : 8,
            selected: s.digitalFaceIndex,
            onChanged: (i) => setState(() => _settings = s.copyWith(digitalFaceIndex: i)),
          ),
          const Divider(height: 32),
        ],

        if (s.clockMode == ClockMode.analogue) ...[
          Text('Analogue Face', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _FaceSelector(
            names: s.analogueFaces.isNotEmpty ? s.analogueFaces : null,
            count: s.analogueFaces.isNotEmpty ? s.analogueFaces.length : 8,
            selected: s.analogueFaceIndex,
            onChanged: (i) => setState(() => _settings = s.copyWith(analogueFaceIndex: i)),
          ),
          const Divider(height: 32),
        ],

        // Steps toggle
        SwitchListTile(
          title: const Text('Step Counter'),
          subtitle: const Text('Enable pedometer (uses IMU)'),
          value: s.stepsActive,
          onChanged: (v) => setState(() => _settings = s.copyWith(stepsActive: v)),
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }
}

class _FaceSelector extends StatelessWidget {
  final int count;
  final int selected;
  final ValueChanged<int> onChanged;
  final List<String>? names;

  const _FaceSelector({
    required this.count,
    required this.selected,
    required this.onChanged,
    this.names,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, i) {
          final isSelected = i == selected;
          final label = (names != null && i < names!.length) ? names![i] : '${i + 1}';
          final asset = faceAsset(label);

          // Selected face is larger, unselected faces are dimmed
          final double imgSize = isSelected ? 86.0 : 68.0;

          return GestureDetector(
            onTap: () => onChanged(i),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  width: imgSize + (isSelected ? 8 : 0),
                  height: imgSize + (isSelected ? 8 : 0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? primary : Colors.transparent,
                  ),
                  padding: EdgeInsets.all(isSelected ? 4 : 0),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipOval(
                        child: ColorFiltered(
                          colorFilter: isSelected
                              ? const ColorFilter.mode(
                                  Colors.transparent, BlendMode.multiply)
                              : ColorFilter.mode(
                                  Colors.black.withOpacity(0.35),
                                  BlendMode.darken),
                          child: SizedBox(
                            width: imgSize,
                            height: imgSize,
                            child: asset != null
                                ? Image.asset(asset, fit: BoxFit.cover)
                                : ColoredBox(
                                    color: Colors.grey.shade300,
                                    child: Center(
                                      child: Text('${i + 1}',
                                          style: const TextStyle(fontSize: 22)),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      if (isSelected)
                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: primary, width: 2),
                            ),
                            child: Icon(Icons.check, size: 14, color: primary),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 90,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? primary : Colors.grey.shade500,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
