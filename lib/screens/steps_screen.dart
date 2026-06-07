import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../ble/ble_manager.dart';
import '../models/step_entry.dart';

class StepsScreen extends StatefulWidget {
  const StepsScreen({super.key});

  @override
  State<StepsScreen> createState() => _StepsScreenState();
}

class _StepsScreenState extends State<StepsScreen> {
  List<StepEntry>? _entries;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final entries = await context.read<BleManager>().readSteps();
      setState(() => _entries = entries);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Step History'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
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
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 8),
          Text(_error!),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ],
      ));
    }
    final entries = _entries ?? [];
    if (entries.isEmpty) {
      return const Center(child: Text('No step data available'));
    }

    final maxSteps = entries.map((e) => e.steps).reduce((a, b) => a > b ? a : b);
    final totalToday = entries.isNotEmpty ? entries.last.steps : 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Today: $totalToday steps',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('Last 7 days',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 24),
          Expanded(
            child: BarChart(
              BarChartData(
                maxY: maxSteps.toDouble() * 1.2,
                barGroups: entries.asMap().entries.map((entry) {
                  final i = entry.key;
                  final e = entry.value;
                  return BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                      toY: e.steps.toDouble(),
                      color: i == entries.length - 1
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.primaryContainer,
                      width: 20,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ]);
                }).toList(),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, _) {
                        final i = value.toInt();
                        if (i < 0 || i >= entries.length) return const SizedBox();
                        final parts = entries[i].date.split('-');
                        final label = parts.length == 3 ? '${parts[2]}/${parts[1]}' : '';
                        return Text(label, style: const TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
