import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/geo_location.dart';
import '../models/units.dart';
import '../models/weather_data.dart';
import '../services/weather_repository.dart';
import '../state/settings_controller.dart';
import '../utils/formatting.dart';
import '../widgets/charts/historical_chart.dart';

/// Shows historical temperature and precipitation charts for a location.
class HistoricalScreen extends StatefulWidget {
  const HistoricalScreen({super.key, required this.location});

  final GeoLocation location;

  @override
  State<HistoricalScreen> createState() => _HistoricalScreenState();
}

class _HistoricalScreenState extends State<HistoricalScreen> {
  // The reanalysis archive lags real time by a few days.
  static const _archiveLagDays = 5;

  late int _days;
  HistoricalData? _data;
  bool _loading = false;
  String? _error;

  static const _options = [7, 30, 90, 365];

  @override
  void initState() {
    super.initState();
    _days = context.read<SettingsController>().settings.historicalDays;
    if (!_options.contains(_days)) _days = 30;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final repository = context.read<WeatherRepository>();
    final settings = context.read<SettingsController>().settings;
    final end = DateTime.now().subtract(const Duration(days: _archiveLagDays));
    final start = end.subtract(Duration(days: _days));
    try {
      final data = await repository.fetchHistorical(
        widget.location,
        start,
        end,
        settings,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
        if (data.days.isEmpty) {
          _error = 'No historical data available for this range.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>().settings;
    final fmt = Formatting(settings.use24HourClock);
    final color = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: Text('History · ${widget.location.name}'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 8,
              children: _options.map((d) {
                return ChoiceChip(
                  label: Text(d == 365 ? '1 year' : '$d days'),
                  selected: _days == d,
                  onSelected: (_) {
                    setState(() => _days = d);
                    context.read<SettingsController>().setHistoricalDays(d);
                    _load();
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.history_toggle_off, size: 48),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else if (_data != null) ...[
              _statsSummary(_data!, settings),
              const SizedBox(height: 16),
              Text('Temperature',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: HistoricalTempChart(
                    data: _data!,
                    tempUnit: settings.temperatureUnit,
                    formatting: fmt,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _legend(context),
              const SizedBox(height: 16),
              Text('Precipitation',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: HistoricalPrecipChart(
                    data: _data!,
                    precipUnit: settings.precipitationUnit,
                    formatting: fmt,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Historical data from Open-Meteo archive (ERA5)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statsSummary(HistoricalData data, settings) {
    final temps = data.days
        .where((d) => d.tempMean != null)
        .map((d) => d.tempMean!)
        .toList();
    final maxT = data.days
        .where((d) => d.tempMax != null)
        .map((d) => d.tempMax!)
        .fold<double?>(null, (a, b) => a == null ? b : (b > a ? b : a));
    final minT = data.days
        .where((d) => d.tempMin != null)
        .map((d) => d.tempMin!)
        .fold<double?>(null, (a, b) => a == null ? b : (b < a ? b : a));
    final avgT = temps.isEmpty
        ? null
        : temps.reduce((a, b) => a + b) / temps.length;
    final totalP = data.days
        .where((d) => d.precipitationSum != null)
        .map((d) => d.precipitationSum!)
        .fold<double>(0, (a, b) => a + b);

    final unit = settings.temperatureUnit as TemperatureUnit;
    final pUnit = settings.precipitationUnit as PrecipitationUnit;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 24,
          runSpacing: 12,
          children: [
            if (avgT != null) _stat('Avg temp', unit.format(avgT, digits: 1)),
            if (maxT != null) _stat('Highest', unit.format(maxT)),
            if (minT != null) _stat('Lowest', unit.format(minT)),
            _stat('Total rain', pUnit.format(totalP)),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        Text(value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _legend(BuildContext context) {
    Widget item(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 14, height: 3, color: c),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        );
    return Wrap(
      spacing: 16,
      children: [
        item(Colors.orangeAccent, 'Max'),
        item(Colors.lightBlueAccent, 'Min'),
        item(Colors.grey, 'Mean'),
      ],
    );
  }
}
