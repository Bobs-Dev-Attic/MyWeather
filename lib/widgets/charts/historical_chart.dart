import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/units.dart';
import '../../models/weather_data.dart';
import '../../utils/formatting.dart';

/// Line chart of historical max/min/mean temperature over a date range.
class HistoricalTempChart extends StatelessWidget {
  const HistoricalTempChart({
    super.key,
    required this.data,
    required this.tempUnit,
    required this.formatting,
    required this.color,
  });

  final HistoricalData data;
  final TemperatureUnit tempUnit;
  final Formatting formatting;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final days = data.days;
    if (days.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No historical data')),
      );
    }

    final maxSpots = <FlSpot>[];
    final minSpots = <FlSpot>[];
    final meanSpots = <FlSpot>[];
    for (var i = 0; i < days.length; i++) {
      final d = days[i];
      if (d.tempMax != null) {
        maxSpots.add(FlSpot(i.toDouble(), tempUnit.fromCelsius(d.tempMax!)));
      }
      if (d.tempMin != null) {
        minSpots.add(FlSpot(i.toDouble(), tempUnit.fromCelsius(d.tempMin!)));
      }
      if (d.tempMean != null) {
        meanSpots.add(FlSpot(i.toDouble(), tempUnit.fromCelsius(d.tempMean!)));
      }
    }

    final all = [...maxSpots, ...minSpots].map((s) => s.y).toList();
    final minY = all.reduce((a, b) => a < b ? a : b);
    final maxY = all.reduce((a, b) => a > b ? a : b);
    final pad = (maxY - minY) * 0.15 + 1;
    final labelStyle =
        TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11);
    final labelInterval = (days.length / 5).ceilToDouble().clamp(1.0, 1000.0);

    return SizedBox(
      height: 240,
      child: LineChart(
        LineChartData(
          minY: minY - pad,
          maxY: maxY + pad,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (v) =>
                FlLine(color: color.withValues(alpha: 0.1), strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 38,
                getTitlesWidget: (v, m) =>
                    Text('${v.round()}°', style: labelStyle),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: labelInterval,
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if (i < 0 || i >= days.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(formatting.monthDay(days[i].date),
                        style: labelStyle),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            _line(maxSpots, Colors.orangeAccent),
            _line(minSpots, Colors.lightBlueAccent),
            if (meanSpots.isNotEmpty)
              _line(meanSpots, color.withValues(alpha: 0.6), dashed: true),
          ],
        ),
      ),
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color c, {bool dashed = false}) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: c,
      barWidth: 2.5,
      dashArray: dashed ? [6, 4] : null,
      dotData: const FlDotData(show: false),
    );
  }
}

/// Bar chart of historical daily precipitation totals.
class HistoricalPrecipChart extends StatelessWidget {
  const HistoricalPrecipChart({
    super.key,
    required this.data,
    required this.precipUnit,
    required this.formatting,
    required this.color,
  });

  final HistoricalData data;
  final PrecipitationUnit precipUnit;
  final Formatting formatting;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final days = data.days.where((d) => d.precipitationSum != null).toList();
    if (days.isEmpty) return const SizedBox.shrink();

    final maxV = days
        .map((d) => precipUnit.fromMm(d.precipitationSum!))
        .fold<double>(0, (a, b) => a > b ? a : b);
    final labelStyle =
        TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11);
    final labelInterval = (days.length / 5).ceil();

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          maxY: maxV <= 0 ? 1 : maxV * 1.2,
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
                reservedSize: 38,
                getTitlesWidget: (v, m) => Text(
                  v.toStringAsFixed(maxV < 5 ? 1 : 0),
                  style: labelStyle,
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if (i < 0 || i >= days.length) {
                    return const SizedBox.shrink();
                  }
                  if (i % labelInterval != 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(formatting.monthDay(days[i].date),
                        style: labelStyle),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < days.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: precipUnit.fromMm(days[i].precipitationSum!),
                  color: Colors.lightBlueAccent.withValues(alpha: 0.8),
                  width: 5,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(2),
                  ),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}
