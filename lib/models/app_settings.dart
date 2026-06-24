import 'package:flutter/material.dart';

import 'source_config.dart';
import 'units.dart';

/// Global, app-wide preferences plus the per-source configuration map.
class AppSettings {
  const AppSettings({
    this.temperatureUnit = TemperatureUnit.celsius,
    this.windSpeedUnit = WindSpeedUnit.kmh,
    this.precipitationUnit = PrecipitationUnit.mm,
    this.pressureUnit = PressureUnit.hpa,
    this.themeMode = ThemeMode.system,
    this.animationsEnabled = true,
    this.reducedMotion = false,
    this.primarySourceId,
    this.historicalDays = 30,
    this.use24HourClock = true,
    this.autoRefresh = true,
    this.sourceConfigs = const {},
  });

  final TemperatureUnit temperatureUnit;
  final WindSpeedUnit windSpeedUnit;
  final PrecipitationUnit precipitationUnit;
  final PressureUnit pressureUnit;
  final ThemeMode themeMode;

  /// Master switch for animated weather backgrounds.
  final bool animationsEnabled;

  /// When true, animations are slowed/quieted for motion sensitivity.
  final bool reducedMotion;

  /// Preferred source for the "primary" headline values. Null = automatic
  /// (lowest priority number among enabled sources).
  final String? primarySourceId;

  /// Default number of days of history to chart.
  final int historicalDays;

  final bool use24HourClock;

  /// Whether the app refreshes automatically based on per-source intervals.
  final bool autoRefresh;

  /// Per-source configuration keyed by source id.
  final Map<String, SourceConfig> sourceConfigs;

  SourceConfig configFor(String sourceId) =>
      sourceConfigs[sourceId] ?? SourceConfig(sourceId: sourceId);

  AppSettings copyWith({
    TemperatureUnit? temperatureUnit,
    WindSpeedUnit? windSpeedUnit,
    PrecipitationUnit? precipitationUnit,
    PressureUnit? pressureUnit,
    ThemeMode? themeMode,
    bool? animationsEnabled,
    bool? reducedMotion,
    String? primarySourceId,
    bool clearPrimarySource = false,
    int? historicalDays,
    bool? use24HourClock,
    bool? autoRefresh,
    Map<String, SourceConfig>? sourceConfigs,
  }) {
    return AppSettings(
      temperatureUnit: temperatureUnit ?? this.temperatureUnit,
      windSpeedUnit: windSpeedUnit ?? this.windSpeedUnit,
      precipitationUnit: precipitationUnit ?? this.precipitationUnit,
      pressureUnit: pressureUnit ?? this.pressureUnit,
      themeMode: themeMode ?? this.themeMode,
      animationsEnabled: animationsEnabled ?? this.animationsEnabled,
      reducedMotion: reducedMotion ?? this.reducedMotion,
      primarySourceId:
          clearPrimarySource ? null : (primarySourceId ?? this.primarySourceId),
      historicalDays: historicalDays ?? this.historicalDays,
      use24HourClock: use24HourClock ?? this.use24HourClock,
      autoRefresh: autoRefresh ?? this.autoRefresh,
      sourceConfigs: sourceConfigs ?? this.sourceConfigs,
    );
  }

  Map<String, dynamic> toJson() => {
        'temperatureUnit': temperatureUnit.index,
        'windSpeedUnit': windSpeedUnit.index,
        'precipitationUnit': precipitationUnit.index,
        'pressureUnit': pressureUnit.index,
        'themeMode': themeMode.index,
        'animationsEnabled': animationsEnabled,
        'reducedMotion': reducedMotion,
        'primarySourceId': primarySourceId,
        'historicalDays': historicalDays,
        'use24HourClock': use24HourClock,
        'autoRefresh': autoRefresh,
        'sourceConfigs':
            sourceConfigs.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final rawConfigs =
        (json['sourceConfigs'] as Map?)?.cast<String, dynamic>() ?? {};
    return AppSettings(
      temperatureUnit:
          TemperatureUnit.values[json['temperatureUnit'] as int? ?? 0],
      windSpeedUnit: WindSpeedUnit.values[json['windSpeedUnit'] as int? ?? 0],
      precipitationUnit:
          PrecipitationUnit.values[json['precipitationUnit'] as int? ?? 0],
      pressureUnit: PressureUnit.values[json['pressureUnit'] as int? ?? 0],
      themeMode: ThemeMode.values[json['themeMode'] as int? ?? 0],
      animationsEnabled: json['animationsEnabled'] as bool? ?? true,
      reducedMotion: json['reducedMotion'] as bool? ?? false,
      primarySourceId: json['primarySourceId'] as String?,
      historicalDays: json['historicalDays'] as int? ?? 30,
      use24HourClock: json['use24HourClock'] as bool? ?? true,
      autoRefresh: json['autoRefresh'] as bool? ?? true,
      sourceConfigs: rawConfigs.map(
        (k, v) =>
            MapEntry(k, SourceConfig.fromJson((v as Map).cast<String, dynamic>())),
      ),
    );
  }
}
