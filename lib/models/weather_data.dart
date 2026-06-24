import 'geo_location.dart';
import 'weather_condition.dart';

/// Snapshot of current conditions.
class CurrentWeather {
  const CurrentWeather({
    required this.time,
    required this.temperature,
    required this.condition,
    this.apparentTemperature,
    this.humidity,
    this.windSpeed,
    this.windDirection,
    this.windGust,
    this.pressure,
    this.precipitation,
    this.cloudCover,
    this.uvIndex,
    this.visibility,
  });

  final DateTime time;

  /// Celsius (canonical internal unit; converted for display).
  final double temperature;
  final WeatherCondition condition;
  final double? apparentTemperature;

  /// Percent 0-100.
  final double? humidity;

  /// km/h.
  final double? windSpeed;

  /// Degrees.
  final double? windDirection;
  final double? windGust;

  /// hPa.
  final double? pressure;

  /// mm.
  final double? precipitation;

  /// Percent 0-100.
  final double? cloudCover;
  final double? uvIndex;

  /// metres.
  final double? visibility;
}

/// One hour of an hourly forecast.
class HourlyPoint {
  const HourlyPoint({
    required this.time,
    required this.temperature,
    required this.condition,
    this.precipitation,
    this.precipitationProbability,
    this.windSpeed,
    this.humidity,
    this.apparentTemperature,
  });

  final DateTime time;
  final double temperature;
  final WeatherCondition condition;
  final double? precipitation;
  final double? precipitationProbability;
  final double? windSpeed;
  final double? humidity;
  final double? apparentTemperature;
}

/// One day of a daily forecast.
class DailyPoint {
  const DailyPoint({
    required this.date,
    required this.tempMax,
    required this.tempMin,
    required this.condition,
    this.precipitationSum,
    this.precipitationProbabilityMax,
    this.windSpeedMax,
    this.uvIndexMax,
    this.sunrise,
    this.sunset,
  });

  final DateTime date;
  final double tempMax;
  final double tempMin;
  final WeatherCondition condition;
  final double? precipitationSum;
  final double? precipitationProbabilityMax;
  final double? windSpeedMax;
  final double? uvIndexMax;
  final DateTime? sunrise;
  final DateTime? sunset;
}

/// A complete forecast bundle from a single source.
class WeatherBundle {
  const WeatherBundle({
    required this.location,
    required this.sourceId,
    required this.sourceName,
    required this.fetchedAt,
    required this.current,
    this.hourly = const [],
    this.daily = const [],
    this.attribution,
  });

  final GeoLocation location;
  final String sourceId;
  final String sourceName;
  final DateTime fetchedAt;
  final CurrentWeather current;
  final List<HourlyPoint> hourly;
  final List<DailyPoint> daily;
  final String? attribution;
}

/// One day of historical (observed/reanalysis) data.
class HistoricalDay {
  const HistoricalDay({
    required this.date,
    this.tempMax,
    this.tempMin,
    this.tempMean,
    this.precipitationSum,
    this.windSpeedMax,
  });

  final DateTime date;
  final double? tempMax;
  final double? tempMin;
  final double? tempMean;
  final double? precipitationSum;
  final double? windSpeedMax;
}

/// A historical data series for a location and date range.
class HistoricalData {
  const HistoricalData({
    required this.location,
    required this.sourceId,
    required this.start,
    required this.end,
    required this.days,
  });

  final GeoLocation location;
  final String sourceId;
  final DateTime start;
  final DateTime end;
  final List<HistoricalDay> days;
}
