import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../services/weather_repository.dart';
import '../utils/formatting.dart';

/// A horizontal strip comparing the current temperature reported by each
/// active source, so the user can see agreement/disagreement at a glance.
class SourceComparison extends StatelessWidget {
  const SourceComparison({
    super.key,
    required this.results,
    required this.settings,
    required this.foreground,
    this.primarySourceId,
  });

  final List<SourceResult> results;
  final AppSettings settings;
  final Color foreground;
  final String? primarySourceId;

  @override
  Widget build(BuildContext context) {
    final unit = settings.temperatureUnit;
    final muted = foreground.withValues(alpha: 0.7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sources',
            style: TextStyle(
                color: foreground, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: results.map((r) {
              final isPrimary = r.sourceId == primarySourceId;
              final temp = r.bundle?.current.temperature;
              final hasData = temp != null;
              return Container(
                margin: const EdgeInsets.only(right: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white
                      .withValues(alpha: isPrimary ? 0.22 : 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isPrimary
                        ? Colors.white.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          r.sourceName,
                          style: TextStyle(
                              color: foreground,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                        if (isPrimary)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(Icons.star,
                                size: 12, color: Colors.amber.shade200),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (hasData)
                      Text(
                        unit.format(temp),
                        style: TextStyle(
                            color: foreground,
                            fontSize: 22,
                            fontWeight: FontWeight.w300),
                      )
                    else
                      Text(
                        r.skippedReason ?? 'No data',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                    if (hasData)
                      Text(
                        r.bundle!.current.condition.description,
                        style: TextStyle(color: muted, fontSize: 11),
                      ),
                    if (r.fromCache)
                      Text('cached',
                          style: TextStyle(color: muted, fontSize: 10)),
                    if (r.bundle != null && !r.fromCache)
                      Text(Formatting.ago(r.bundle!.fetchedAt),
                          style: TextStyle(color: muted, fontSize: 10)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
