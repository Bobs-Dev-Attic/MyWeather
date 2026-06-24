import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/weather_data.dart';
import '../utils/formatting.dart';

/// A horizontally scrolling strip of upcoming hours with icon and temperature.
class HourlyStrip extends StatelessWidget {
  const HourlyStrip({
    super.key,
    required this.points,
    required this.settings,
    required this.foreground,
  });

  final List<HourlyPoint> points;
  final AppSettings settings;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final fmt = Formatting(settings.use24HourClock);
    final unit = settings.temperatureUnit;
    final muted = foreground.withValues(alpha: 0.75);

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: points.length.clamp(0, 24),
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final p = points[i];
          final isNow = i == 0;
          return Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: isNow ? Colors.white.withValues(alpha: 0.15) : null,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(isNow ? 'Now' : fmt.hour(p.time),
                    style: TextStyle(color: muted, fontSize: 12)),
                Text(p.condition.emoji, style: const TextStyle(fontSize: 22)),
                if ((p.precipitationProbability ?? 0) > 5)
                  Text('${p.precipitationProbability!.round()}%',
                      style: TextStyle(
                          color: Colors.lightBlueAccent.shade100, fontSize: 10))
                else
                  const SizedBox(height: 12),
                Text(unit.format(p.temperature),
                    style: TextStyle(
                        color: foreground,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          );
        },
      ),
    );
  }
}
