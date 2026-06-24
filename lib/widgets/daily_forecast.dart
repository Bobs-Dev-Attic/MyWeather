import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/units.dart';
import '../models/weather_data.dart';
import '../utils/formatting.dart';

/// A vertical list of daily forecast rows with a visual temperature range bar.
class DailyForecastList extends StatelessWidget {
  const DailyForecastList({
    super.key,
    required this.days,
    required this.settings,
    required this.foreground,
  });

  final List<DailyPoint> days;
  final AppSettings settings;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();
    final fmt = Formatting(settings.use24HourClock);
    final unit = settings.temperatureUnit;

    // Compute the global min/max across the range for proportional bars.
    final globalMin =
        days.map((d) => d.tempMin).reduce((a, b) => a < b ? a : b);
    final globalMax =
        days.map((d) => d.tempMax).reduce((a, b) => a > b ? a : b);
    final span = (globalMax - globalMin).abs() < 0.5 ? 1.0 : globalMax - globalMin;

    return Column(
      children: days.map((d) {
        final lo = (d.tempMin - globalMin) / span;
        final hi = (d.tempMax - globalMin) / span;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 96,
                child: Text(
                  fmt.relativeDay(d.date),
                  style: TextStyle(color: foreground, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(d.condition.emoji, style: const TextStyle(fontSize: 20)),
              if (d.precipitationProbabilityMax != null &&
                  d.precipitationProbabilityMax! > 5)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    '${d.precipitationProbabilityMax!.round()}%',
                    style: TextStyle(
                      color: Colors.lightBlueAccent.shade100,
                      fontSize: 11,
                    ),
                  ),
                ),
              const Spacer(),
              SizedBox(
                width: 38,
                child: Text(
                  unit.format(d.tempMin),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: foreground.withValues(alpha: 0.7), fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              _RangeBar(low: lo, high: hi),
              const SizedBox(width: 8),
              SizedBox(
                width: 38,
                child: Text(
                  unit.format(d.tempMax),
                  style: TextStyle(color: foreground, fontSize: 14),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// A horizontal gradient bar showing the day's temperature span within the
/// week's overall range.
class _RangeBar extends StatelessWidget {
  const _RangeBar({required this.low, required this.high});

  final double low; // 0..1
  final double high; // 0..1

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 6,
      child: LayoutBuilder(builder: (context, c) {
        final left = low.clamp(0.0, 1.0) * c.maxWidth;
        final width = (high - low).clamp(0.05, 1.0) * c.maxWidth;
        return Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Positioned(
              left: left,
              child: Container(
                width: width,
                height: 6,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.lightBlueAccent, Colors.orangeAccent],
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
