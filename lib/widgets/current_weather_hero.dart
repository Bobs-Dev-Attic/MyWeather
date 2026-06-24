import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/geo_location.dart';
import '../models/units.dart';
import '../models/weather_data.dart';

/// The large headline block: location, current temperature, condition and
/// today's high/low.
class CurrentWeatherHero extends StatelessWidget {
  const CurrentWeatherHero({
    super.key,
    required this.location,
    required this.current,
    required this.today,
    required this.settings,
    required this.foreground,
  });

  final GeoLocation location;
  final CurrentWeather current;
  final DailyPoint? today;
  final AppSettings settings;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final unit = settings.temperatureUnit;
    final muted = foreground.withValues(alpha: 0.8);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (location.isCurrent)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(Icons.my_location, size: 18, color: muted),
              ),
            Flexible(
              child: Text(
                location.name,
                style: TextStyle(
                  color: foreground,
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (location.subtitle.isNotEmpty)
          Text(location.subtitle,
              style: TextStyle(color: muted, fontSize: 14)),
        const SizedBox(height: 12),
        Text(current.condition.emoji, style: const TextStyle(fontSize: 64)),
        Text(
          unit.format(current.temperature),
          style: TextStyle(
            color: foreground,
            fontSize: 84,
            fontWeight: FontWeight.w200,
            height: 1.0,
          ),
        ),
        Text(
          current.condition.description,
          style: TextStyle(color: foreground, fontSize: 18),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (current.apparentTemperature != null)
              Text(
                'Feels like ${unit.format(current.apparentTemperature!)}',
                style: TextStyle(color: muted, fontSize: 14),
              ),
            if (today != null) ...[
              if (current.apparentTemperature != null)
                Text('   ·   ', style: TextStyle(color: muted)),
              Icon(Icons.arrow_upward, size: 14, color: muted),
              Text(unit.format(today!.tempMax),
                  style: TextStyle(color: muted, fontSize: 14)),
              const SizedBox(width: 8),
              Icon(Icons.arrow_downward, size: 14, color: muted),
              Text(unit.format(today!.tempMin),
                  style: TextStyle(color: muted, fontSize: 14)),
            ],
          ],
        ),
      ],
    );
  }
}
