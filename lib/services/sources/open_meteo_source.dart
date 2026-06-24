import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/geo_location.dart';
import '../../models/source_config.dart';
import '../../models/weather_condition.dart';
import '../../models/weather_data.dart';
import '../weather_source.dart';

/// Open-Meteo: a free, no-key weather API with excellent forecast and a
/// dedicated historical (reanalysis) archive endpoint.
class OpenMeteoSource implements WeatherSource {
  OpenMeteoSource({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  String get id => 'open_meteo';

  @override
  String get displayName => 'Open-Meteo';

  @override
  String get description =>
      'Free, no API key. Global forecast plus a historical archive.';

  @override
  bool get requiresApiKey => false;

  @override
  String get attribution => 'Weather data by Open-Meteo.com (CC BY 4.0)';

  @override
  String? get apiKeySignupUrl => null;

  @override
  bool get supportsHistorical => true;

  @override
  SourceConfig get defaultConfig => SourceConfig(
        sourceId: id,
        priority: 0,
        updateIntervalMinutes: 15,
        maxCallsPerHour: 200,
        maxCallsPerDay: 5000,
      );

  static const _forecastBase = 'https://api.open-meteo.com/v1/forecast';
  static const _archiveBase = 'https://archive-api.open-meteo.com/v1/archive';

  @override
  Future<WeatherBundle> fetchWeather(
    GeoLocation location,
    SourceConfig config,
  ) async {
    final uri = Uri.parse(_forecastBase).replace(queryParameters: {
      'latitude': '${location.latitude}',
      'longitude': '${location.longitude}',
      'current': [
        'temperature_2m',
        'relative_humidity_2m',
        'apparent_temperature',
        'is_day',
        'precipitation',
        'weather_code',
        'cloud_cover',
        'pressure_msl',
        'wind_speed_10m',
        'wind_direction_10m',
        'wind_gusts_10m',
      ].join(','),
      'hourly': [
        'temperature_2m',
        'relative_humidity_2m',
        'apparent_temperature',
        'precipitation_probability',
        'precipitation',
        'weather_code',
        'wind_speed_10m',
      ].join(','),
      'daily': [
        'weather_code',
        'temperature_2m_max',
        'temperature_2m_min',
        'precipitation_sum',
        'precipitation_probability_max',
        'wind_speed_10m_max',
        'uv_index_max',
        'sunrise',
        'sunset',
      ].join(','),
      'timezone': 'auto',
      'forecast_days': '7',
    });

    final body = await _getJson(uri, config);

    final current = _parseCurrent(body['current'] as Map<String, dynamic>);
    final hourly = _parseHourly(body['hourly'] as Map<String, dynamic>?);
    final daily = _parseDaily(body['daily'] as Map<String, dynamic>?);

    return WeatherBundle(
      location: location,
      sourceId: id,
      sourceName: displayName,
      fetchedAt: DateTime.now(),
      current: current,
      hourly: hourly,
      daily: daily,
      attribution: attribution,
    );
  }

  CurrentWeather _parseCurrent(Map<String, dynamic> c) {
    final isDay = (c['is_day'] as num?)?.toInt() == 1;
    final code = (c['weather_code'] as num?)?.toInt() ?? -1;
    return CurrentWeather(
      time: _parseTime(c['time']) ?? DateTime.now(),
      temperature: _toD(c['temperature_2m']) ?? 0,
      condition: WeatherCondition.fromWmoCode(code, isDay: isDay),
      apparentTemperature: _toD(c['apparent_temperature']),
      humidity: _toD(c['relative_humidity_2m']),
      windSpeed: _toD(c['wind_speed_10m']),
      windDirection: _toD(c['wind_direction_10m']),
      windGust: _toD(c['wind_gusts_10m']),
      pressure: _toD(c['pressure_msl']),
      precipitation: _toD(c['precipitation']),
      cloudCover: _toD(c['cloud_cover']),
    );
  }

  List<HourlyPoint> _parseHourly(Map<String, dynamic>? h) {
    if (h == null) return const [];
    final times = (h['time'] as List?) ?? const [];
    final temps = (h['temperature_2m'] as List?) ?? const [];
    final codes = (h['weather_code'] as List?) ?? const [];
    final precip = (h['precipitation'] as List?) ?? const [];
    final precipProb = (h['precipitation_probability'] as List?) ?? const [];
    final wind = (h['wind_speed_10m'] as List?) ?? const [];
    final humidity = (h['relative_humidity_2m'] as List?) ?? const [];
    final apparent = (h['apparent_temperature'] as List?) ?? const [];

    final out = <HourlyPoint>[];
    final now = DateTime.now();
    for (var i = 0; i < times.length; i++) {
      final time = _parseTime(times[i]);
      if (time == null) continue;
      // Keep only the next 48 hours from now for a focused view.
      if (time.isBefore(now.subtract(const Duration(hours: 1)))) continue;
      if (time.isAfter(now.add(const Duration(hours: 48)))) break;
      final code = i < codes.length ? (codes[i] as num).toInt() : -1;
      out.add(HourlyPoint(
        time: time,
        temperature: _at(temps, i) ?? 0,
        condition: WeatherCondition.fromWmoCode(code, isDay: _isDaytime(time)),
        precipitation: _at(precip, i),
        precipitationProbability: _at(precipProb, i),
        windSpeed: _at(wind, i),
        humidity: _at(humidity, i),
        apparentTemperature: _at(apparent, i),
      ));
    }
    return out;
  }

  List<DailyPoint> _parseDaily(Map<String, dynamic>? d) {
    if (d == null) return const [];
    final dates = (d['time'] as List?) ?? const [];
    final codes = (d['weather_code'] as List?) ?? const [];
    final tmax = (d['temperature_2m_max'] as List?) ?? const [];
    final tmin = (d['temperature_2m_min'] as List?) ?? const [];
    final psum = (d['precipitation_sum'] as List?) ?? const [];
    final pprob = (d['precipitation_probability_max'] as List?) ?? const [];
    final wmax = (d['wind_speed_10m_max'] as List?) ?? const [];
    final uv = (d['uv_index_max'] as List?) ?? const [];
    final sunrise = (d['sunrise'] as List?) ?? const [];
    final sunset = (d['sunset'] as List?) ?? const [];

    final out = <DailyPoint>[];
    for (var i = 0; i < dates.length; i++) {
      final date = _parseTime(dates[i]);
      if (date == null) continue;
      final code = i < codes.length ? (codes[i] as num).toInt() : -1;
      out.add(DailyPoint(
        date: date,
        tempMax: _at(tmax, i) ?? 0,
        tempMin: _at(tmin, i) ?? 0,
        condition: WeatherCondition.fromWmoCode(code),
        precipitationSum: _at(psum, i),
        precipitationProbabilityMax: _at(pprob, i),
        windSpeedMax: _at(wmax, i),
        uvIndexMax: _at(uv, i),
        sunrise: i < sunrise.length ? _parseTime(sunrise[i]) : null,
        sunset: i < sunset.length ? _parseTime(sunset[i]) : null,
      ));
    }
    return out;
  }

  @override
  Future<HistoricalData> fetchHistorical(
    GeoLocation location,
    DateTime start,
    DateTime end,
    SourceConfig config,
  ) async {
    final uri = Uri.parse(_archiveBase).replace(queryParameters: {
      'latitude': '${location.latitude}',
      'longitude': '${location.longitude}',
      'start_date': _fmtDate(start),
      'end_date': _fmtDate(end),
      'daily': [
        'temperature_2m_max',
        'temperature_2m_min',
        'temperature_2m_mean',
        'precipitation_sum',
        'wind_speed_10m_max',
      ].join(','),
      'timezone': 'auto',
    });

    final body = await _getJson(uri, config);
    final d = body['daily'] as Map<String, dynamic>?;
    final days = <HistoricalDay>[];
    if (d != null) {
      final dates = (d['time'] as List?) ?? const [];
      final tmax = (d['temperature_2m_max'] as List?) ?? const [];
      final tmin = (d['temperature_2m_min'] as List?) ?? const [];
      final tmean = (d['temperature_2m_mean'] as List?) ?? const [];
      final psum = (d['precipitation_sum'] as List?) ?? const [];
      final wmax = (d['wind_speed_10m_max'] as List?) ?? const [];
      for (var i = 0; i < dates.length; i++) {
        final date = _parseTime(dates[i]);
        if (date == null) continue;
        days.add(HistoricalDay(
          date: date,
          tempMax: _at(tmax, i),
          tempMin: _at(tmin, i),
          tempMean: _at(tmean, i),
          precipitationSum: _at(psum, i),
          windSpeedMax: _at(wmax, i),
        ));
      }
    }

    return HistoricalData(
      location: location,
      sourceId: id,
      start: start,
      end: end,
      days: days,
    );
  }

  Future<Map<String, dynamic>> _getJson(Uri uri, SourceConfig config) async {
    final http.Response resp;
    try {
      resp = await _client
          .get(uri)
          .timeout(Duration(seconds: config.timeoutSeconds));
    } catch (e) {
      throw WeatherSourceException(id, 'Network error: $e');
    }
    if (resp.statusCode != 200) {
      throw WeatherSourceException(
          id, 'HTTP ${resp.statusCode}: ${resp.reasonPhrase ?? ''}');
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map<String, dynamic>) {
      throw WeatherSourceException(id, 'Unexpected response shape.');
    }
    if (decoded['error'] == true) {
      throw WeatherSourceException(id, '${decoded['reason']}');
    }
    return decoded;
  }

  // --- helpers ---

  static double? _toD(dynamic v) => v is num ? v.toDouble() : null;

  static double? _at(List list, int i) =>
      i < list.length && list[i] is num ? (list[i] as num).toDouble() : null;

  static DateTime? _parseTime(dynamic v) {
    if (v is! String) return null;
    return DateTime.tryParse(v);
  }

  static bool _isDaytime(DateTime t) => t.hour >= 6 && t.hour < 20;

  static String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
