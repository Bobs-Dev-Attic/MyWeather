import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/units.dart';
import '../services/weather_repository.dart';
import '../state/settings_controller.dart';
import 'source_settings_screen.dart';

/// Global app preferences plus entry points into per-source configuration.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SettingsController>();
    final settings = controller.settings;
    final repository = context.read<WeatherRepository>();
    final sources = repository.sources;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _header(context, 'Units'),
          _DropdownTile<TemperatureUnit>(
            title: 'Temperature',
            value: settings.temperatureUnit,
            items: TemperatureUnit.values,
            labelOf: (u) => u.label,
            onChanged: controller.setTemperatureUnit,
          ),
          _DropdownTile<WindSpeedUnit>(
            title: 'Wind speed',
            value: settings.windSpeedUnit,
            items: WindSpeedUnit.values,
            labelOf: (u) => u.label,
            onChanged: controller.setWindSpeedUnit,
          ),
          _DropdownTile<PrecipitationUnit>(
            title: 'Precipitation',
            value: settings.precipitationUnit,
            items: PrecipitationUnit.values,
            labelOf: (u) => u.label,
            onChanged: controller.setPrecipitationUnit,
          ),
          _DropdownTile<PressureUnit>(
            title: 'Pressure',
            value: settings.pressureUnit,
            items: PressureUnit.values,
            labelOf: (u) => u.label,
            onChanged: controller.setPressureUnit,
          ),

          _header(context, 'Appearance'),
          _DropdownTile<ThemeMode>(
            title: 'Theme',
            value: settings.themeMode,
            items: ThemeMode.values,
            labelOf: (m) => switch (m) {
              ThemeMode.system => 'System default',
              ThemeMode.light => 'Light',
              ThemeMode.dark => 'Dark',
            },
            onChanged: controller.setThemeMode,
          ),
          SwitchListTile(
            title: const Text('Weather animations'),
            subtitle: const Text('Animated sky, rain, snow and more'),
            value: settings.animationsEnabled,
            onChanged: controller.setAnimationsEnabled,
          ),
          SwitchListTile(
            title: const Text('Reduced motion'),
            subtitle: const Text('Slow down animations'),
            value: settings.reducedMotion,
            onChanged: settings.animationsEnabled
                ? controller.setReducedMotion
                : null,
          ),
          SwitchListTile(
            title: const Text('24-hour clock'),
            value: settings.use24HourClock,
            onChanged: controller.set24HourClock,
          ),

          _header(context, 'Data'),
          SwitchListTile(
            title: const Text('Automatic refresh'),
            subtitle: const Text(
                'Refresh on open, honouring each source\'s update interval'),
            value: settings.autoRefresh,
            onChanged: controller.setAutoRefresh,
          ),
          ListTile(
            title: const Text('Primary source'),
            subtitle: Text(_primaryLabel(settings.primarySourceId, sources)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickPrimary(context, controller, sources),
          ),
          ListTile(
            title: const Text('Default history range'),
            subtitle: Text(settings.historicalDays == 365
                ? '1 year'
                : '${settings.historicalDays} days'),
            trailing: DropdownButton<int>(
              value: [7, 30, 90, 365].contains(settings.historicalDays)
                  ? settings.historicalDays
                  : 30,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 7, child: Text('7 days')),
                DropdownMenuItem(value: 30, child: Text('30 days')),
                DropdownMenuItem(value: 90, child: Text('90 days')),
                DropdownMenuItem(value: 365, child: Text('1 year')),
              ],
              onChanged: (v) {
                if (v != null) controller.setHistoricalDays(v);
              },
            ),
          ),

          _header(context, 'Weather sources'),
          ...sources.map((source) {
            final config = settings.configFor(source.id);
            return ListTile(
              leading: Icon(
                config.enabled ? Icons.cloud_done : Icons.cloud_off,
                color: config.enabled
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
              ),
              title: Text(source.displayName),
              subtitle: Text(
                [
                  config.enabled ? 'Enabled' : 'Disabled',
                  if (source.requiresApiKey)
                    (config.apiKey?.isNotEmpty ?? false)
                        ? 'API key set'
                        : 'API key needed',
                  'every ${config.updateIntervalMinutes}m',
                ].join(' · '),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SourceSettingsScreen(sourceId: source.id),
              )),
            );
          }),

          _header(context, 'About'),
          const ListTile(
            title: Text('MyWeather'),
            subtitle: Text(
              'Aggregates multiple free weather services. '
              'Data © Open-Meteo, MET Norway, OpenWeatherMap, WeatherAPI.com.',
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _primaryLabel(String? id, List sources) {
    if (id == null) return 'Automatic (by priority)';
    for (final s in sources) {
      if (s.id == id) return s.displayName;
    }
    return 'Automatic (by priority)';
  }

  void _pickPrimary(
      BuildContext context, SettingsController controller, List sources) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String?>(
                title: const Text('Automatic (by priority)'),
                value: null,
                groupValue: controller.settings.primarySourceId,
                onChanged: (v) {
                  controller.setPrimarySource(v);
                  Navigator.pop(context);
                },
              ),
              ...sources.map((s) => RadioListTile<String?>(
                    title: Text(s.displayName),
                    value: s.id,
                    groupValue: controller.settings.primarySourceId,
                    onChanged: (v) {
                      controller.setPrimarySource(v);
                      Navigator.pop(context);
                    },
                  )),
            ],
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 1,
          ),
        ),
      );
}

class _DropdownTile<T> extends StatelessWidget {
  const _DropdownTile({
    required this.title,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
  });

  final String title;
  final T value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      trailing: DropdownButton<T>(
        value: value,
        underline: const SizedBox.shrink(),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(labelOf(e))))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}
