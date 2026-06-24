import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/units.dart';
import '../../models/weather_data.dart';
import '../../utils/formatting.dart';

/// A temperature line chart over the next hours, with hour labels.
class HourlyChart extends StatelessWidget {
  const HourlyChart({
    super.key,
    required this.points,
    required this.tempUnit,
    required this.formatting,
    required this.color,
  });

  final List<HourlyPoint> points;
  final TemperatureUnit tempUnit;
  final Formatting formatting;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('No hourly data')),
      );
    }

    final display = points.take(24).toList();
    final spots = <FlSpot>[];
    for (var i = 0; i < display.length; i++) {
      spots.add(FlSpot(i.toDouble(), tempUnit.fromCelsius(display[i].temperature)));
    }

    final temps = spots.map((s) => s.y).toList();
    final minY = temps.reduce((a, b) => a < b ? a : b);
    final maxY = temps.reduce((a, b) => a > b ? a : b);
    final pad = ((maxY - minY).abs() < 4) ? 4.0 : (maxY - minY) * 0.2;

    final labelStyle = TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11);

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minY: minY - pad,
          maxY: maxY + pad,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: ((maxY - minY).abs() / 3).clamp(1, 1000),
            getDrawingHorizontalLine: (v) => FlLine(
              color: color.withValues(alpha: 0.12),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: ((maxY - minY).abs() / 3).clamp(1, 1000),
                getTitlesWidget: (value, meta) => Text(
                  '${value.round()}°',
                  style: labelStyle,
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 3,
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if (i < 0 || i >= display.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(formatting.hour(display[i].time),
                        style: labelStyle),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => Colors.black.withValues(alpha: 0.75),
              getTooltipItems: (spots) => spots.map((s) {
                final i = s.x.round();
                final p = display[i];
                return LineTooltipItem(
                  '${tempUnit.format(p.temperature)}\n${formatting.hour(p.time)}',
                  const TextStyle(color: Colors.white, fontSize: 12),
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: 0.35),
                    color.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small bar chart of precipitation probability per hour.
class PrecipChart extends StatelessWidget {
  const PrecipChart({
    super.key,
    required this.points,
    required this.formatting,
    required this.color,
  });

  final List<HourlyPoint> points;
  final Formatting formatting;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final display = points
        .take(24)
        .where((p) => p.precipitationProbability != null)
        .toList();
    if (display.isEmpty) {
      return const SizedBox.shrink();
    }

    final labelStyle = TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11);

    return SizedBox(
      height: 140,
      child: BarChart(
        BarChartData(
          maxY: 100,
          alignment: BarChartAlignment.spaceBetween,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: 50,
                getTitlesWidget: (v, m) =>
                    Text('${v.round()}%', style: labelStyle),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 3,
                reservedSize: 26,
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if (i < 0 || i >= display.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(formatting.hour(display[i].time),
                        style: labelStyle),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < display.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: display[i].precipitationProbability ?? 0,
                  color: color.withValues(alpha: 0.7),
                  width: 6,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(3),
                  ),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}
