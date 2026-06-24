import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/source_config.dart';
import '../services/weather_repository.dart';
import '../services/weather_source.dart';
import '../state/settings_controller.dart';

/// Per-source configuration: enable, API key, update interval, rate limits,
/// priority and timeout — plus live usage against the configured limits.
class SourceSettingsScreen extends StatefulWidget {
  const SourceSettingsScreen({super.key, required this.sourceId});

  final String sourceId;

  @override
  State<SourceSettingsScreen> createState() => _SourceSettingsScreenState();
}

class _SourceSettingsScreenState extends State<SourceSettingsScreen> {
  late TextEditingController _apiKeyController;
  late SourceConfig _config;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _config = context.read<SettingsController>().configFor(widget.sourceId);
    _apiKeyController = TextEditingController(text: _config.apiKey ?? '');
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  WeatherSource get _source =>
      context.read<WeatherRepository>().sourceById(widget.sourceId)!;

  void _save(SourceConfig config) {
    setState(() => _config = config);
    context.read<SettingsController>().updateSourceConfig(config);
  }

  @override
  Widget build(BuildContext context) {
    final source = _source;
    final rateLimiter = context.read<WeatherRepository>().rateLimiter;
    final usedHour = rateLimiter.callsLastHour(source.id);
    final usedDay = rateLimiter.callsLastDay(source.id);

    return Scaffold(
      appBar: AppBar(title: Text(source.displayName)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(source.description,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
          SwitchListTile(
            title: const Text('Enabled'),
            subtitle: const Text('Include this source when fetching weather'),
            value: _config.enabled,
            onChanged: (v) => _save(_config.copyWith(enabled: v)),
          ),
          const Divider(),

          if (source.requiresApiKey) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _apiKeyController,
                obscureText: _obscureKey,
                decoration: InputDecoration(
                  labelText: 'API key',
                  helperText: 'Stored locally on this device only',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscureKey ? Icons.visibility : Icons.visibility_off),
                    onPressed: () =>
                        setState(() => _obscureKey = !_obscureKey),
                  ),
                ),
                onChanged: (v) => _save(
                    _config.copyWith(apiKey: v.trim().isEmpty ? null : v.trim())),
              ),
            ),
            if (source.apiKeySignupUrl != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Get a free API key'),
                    onPressed: () => _showUrl(source.apiKeySignupUrl!),
                  ),
                ),
              ),
            const Divider(),
          ],

          _SliderTile(
            title: 'Update interval',
            value: _config.updateIntervalMinutes.toDouble(),
            min: 5,
            max: 240,
            divisions: 47,
            label: '${_config.updateIntervalMinutes} min',
            description:
                'Reuse cached data newer than this before calling again',
            onChanged: (v) =>
                _save(_config.copyWith(updateIntervalMinutes: v.round())),
          ),
          _SliderTile(
            title: 'Max calls per hour',
            value: _config.maxCallsPerHour.toDouble(),
            min: 1,
            max: 500,
            divisions: 499,
            label: '${_config.maxCallsPerHour}',
            description: 'Used now: $usedHour / ${_config.maxCallsPerHour}',
            onChanged: (v) =>
                _save(_config.copyWith(maxCallsPerHour: v.round())),
          ),
          _SliderTile(
            title: 'Max calls per day',
            value: _config.maxCallsPerDay.toDouble(),
            min: 10,
            max: 10000,
            divisions: 999,
            label: '${_config.maxCallsPerDay}',
            description: 'Used today: $usedDay / ${_config.maxCallsPerDay}',
            onChanged: (v) =>
                _save(_config.copyWith(maxCallsPerDay: v.round())),
          ),
          _SliderTile(
            title: 'Priority',
            value: _config.priority.toDouble(),
            min: 0,
            max: 100,
            divisions: 100,
            label: '${_config.priority}',
            description: 'Lower wins when choosing the primary value',
            onChanged: (v) => _save(_config.copyWith(priority: v.round())),
          ),
          _SliderTile(
            title: 'Request timeout',
            value: _config.timeoutSeconds.toDouble(),
            min: 5,
            max: 60,
            divisions: 55,
            label: '${_config.timeoutSeconds} s',
            description: 'Give up on a request after this long',
            onChanged: (v) =>
                _save(_config.copyWith(timeoutSeconds: v.round())),
          ),

          const Divider(),
          ListTile(
            title: const Text('Capabilities'),
            subtitle: Text([
              'Historical data: ${source.supportsHistorical ? 'yes' : 'no'}',
              source.requiresApiKey ? 'Requires API key' : 'No API key needed',
            ].join(' · ')),
          ),
          ListTile(
            leading: const Icon(Icons.restart_alt),
            title: const Text('Reset usage counter'),
            subtitle: const Text('Clear recorded call history for this source'),
            onTap: () async {
              await rateLimiter.reset(source.id);
              if (mounted) setState(() {});
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_backup_restore),
            title: const Text('Restore defaults'),
            onTap: () {
              final def = source.defaultConfig;
              _apiKeyController.text = def.apiKey ?? '';
              _save(def);
            },
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(source.attribution,
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  void _showUrl(String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sign-up link copied: $url')),
    );
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.label,
    required this.description,
    required this.onChanged,
  });

  final String title;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String label;
  final String description;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(label,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: label,
            onChanged: onChanged,
          ),
          Text(description,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ],
      ),
    );
  }
}
