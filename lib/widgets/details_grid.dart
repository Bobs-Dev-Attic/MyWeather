import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/units.dart';
import '../models/weather_data.dart';

/// A responsive grid of secondary metrics (wind, humidity, pressure, etc.).
class DetailsGrid extends StatelessWidget {
  const DetailsGrid({
    super.key,
    required this.current,
    required this.today,
    required this.settings,
    required this.foreground,
  });

  final CurrentWeather current;
  final DailyPoint? today;
  final AppSettings settings;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final tiles = <_Metric>[];

    if (current.windSpeed != null) {
      final dir = current.windDirection != null
          ? ' ${windDirectionLabel(current.windDirection!)}'
          : '';
      tiles.add(_Metric(Icons.air, 'Wind',
          '${settings.windSpeedUnit.format(current.windSpeed!)}$dir'));
    }
    if (current.windGust != null) {
      tiles.add(_Metric(Icons.storm, 'Gusts',
          settings.windSpeedUnit.format(current.windGust!)));
    }
    if (current.humidity != null) {
      tiles.add(_Metric(
          Icons.water_drop, 'Humidity', '${current.humidity!.round()}%'));
    }
    if (current.pressure != null) {
      tiles.add(_Metric(Icons.speed, 'Pressure',
          settings.pressureUnit.format(current.pressure!)));
    }
    if (current.cloudCover != null) {
      tiles.add(_Metric(
          Icons.cloud, 'Cloud cover', '${current.cloudCover!.round()}%'));
    }
    if (current.precipitation != null) {
      tiles.add(_Metric(Icons.grain, 'Precip',
          settings.precipitationUnit.format(current.precipitation!)));
    }
    if (today?.uvIndexMax != null) {
      tiles.add(_Metric(Icons.wb_sunny, 'UV index',
          today!.uvIndexMax!.toStringAsFixed(1)));
    }
    if (current.visibility != null) {
      tiles.add(_Metric(Icons.visibility, 'Visibility',
          '${(current.visibility! / 1000).toStringAsFixed(1)} km'));
    }
    if (today?.sunrise != null) {
      tiles.add(_Metric(Icons.wb_twilight, 'Sunrise',
          TimeOfDay.fromDateTime(today!.sunrise!).format(context)));
    }
    if (today?.sunset != null) {
      tiles.add(_Metric(Icons.nights_stay, 'Sunset',
          TimeOfDay.fromDateTime(today!.sunset!).format(context)));
    }

    if (tiles.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth > 500 ? 4 : 2;
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.6,
        children: tiles
            .map((m) => _MetricTile(metric: m, foreground: foreground))
            .toList(),
      );
    });
  }
}

class _Metric {
  const _Metric(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric, required this.foreground});

  final _Metric metric;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final muted = foreground.withValues(alpha: 0.75);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(metric.icon, size: 16, color: muted),
              const SizedBox(width: 6),
              Flexible(
                child: Text(metric.label,
                    style: TextStyle(color: muted, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          Text(
            metric.value,
            style: TextStyle(
              color: foreground,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
