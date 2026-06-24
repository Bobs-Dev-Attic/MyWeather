import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/source_config.dart';
import '../models/units.dart';
import '../services/storage_service.dart';
import '../services/weather_source.dart';

/// Holds [AppSettings] and persists every change. Source configs are seeded
/// from each source's [WeatherSource.defaultConfig] on first run.
class SettingsController extends ChangeNotifier {
  SettingsController({
    required StorageService storage,
    required List<WeatherSource> sources,
  })  : _storage = storage,
        _sources = sources {
    _settings = _withDefaults(storage.loadSettings());
  }

  final StorageService _storage;
  final List<WeatherSource> _sources;
  late AppSettings _settings;

  AppSettings get settings => _settings;

  /// Ensures every known source has a config entry, using its default config
  /// when none was previously saved.
  AppSettings _withDefaults(AppSettings loaded) {
    final merged = Map<String, SourceConfig>.from(loaded.sourceConfigs);
    for (final source in _sources) {
      merged.putIfAbsent(source.id, () => source.defaultConfig);
    }
    return loaded.copyWith(sourceConfigs: merged);
  }

  Future<void> _persist() async {
    await _storage.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> update(AppSettings settings) async {
    _settings = settings;
    await _persist();
  }

  Future<void> setTemperatureUnit(TemperatureUnit unit) =>
      update(_settings.copyWith(temperatureUnit: unit));

  Future<void> setWindSpeedUnit(WindSpeedUnit unit) =>
      update(_settings.copyWith(windSpeedUnit: unit));

  Future<void> setPrecipitationUnit(PrecipitationUnit unit) =>
      update(_settings.copyWith(precipitationUnit: unit));

  Future<void> setPressureUnit(PressureUnit unit) =>
      update(_settings.copyWith(pressureUnit: unit));

  Future<void> setThemeMode(ThemeMode mode) =>
      update(_settings.copyWith(themeMode: mode));

  Future<void> setAnimationsEnabled(bool value) =>
      update(_settings.copyWith(animationsEnabled: value));

  Future<void> setReducedMotion(bool value) =>
      update(_settings.copyWith(reducedMotion: value));

  Future<void> set24HourClock(bool value) =>
      update(_settings.copyWith(use24HourClock: value));

  Future<void> setAutoRefresh(bool value) =>
      update(_settings.copyWith(autoRefresh: value));

  Future<void> setHistoricalDays(int days) =>
      update(_settings.copyWith(historicalDays: days));

  Future<void> setPrimarySource(String? sourceId) => update(
        sourceId == null
            ? _settings.copyWith(clearPrimarySource: true)
            : _settings.copyWith(primarySourceId: sourceId),
      );

  /// Replaces the config for a single source.
  Future<void> updateSourceConfig(SourceConfig config) async {
    final map = Map<String, SourceConfig>.from(_settings.sourceConfigs);
    map[config.sourceId] = config;
    await update(_settings.copyWith(sourceConfigs: map));
  }

  SourceConfig configFor(String sourceId) => _settings.configFor(sourceId);
}
