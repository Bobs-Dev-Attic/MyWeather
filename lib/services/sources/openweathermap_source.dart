import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/geo_location.dart';
import '../../models/source_config.dart';
import '../../models/weather_condition.dart';
import '../../models/weather_data.dart';
import '../weather_source.dart';

/// OpenWeatherMap using the free Current Weather + 5-day/3-hour Forecast APIs.
/// Requires a free API key. Historical data needs a paid plan, so it is not
/// supported here.
class OpenWeatherMapSource implements WeatherSource {
  OpenWeatherMapSource({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  @override
  String get id => 'openweathermap';

  @override
  String get displayName => 'OpenWeatherMap';

  @override
  String get description =>
      'Free tier (1,000 calls/day) with a personal API key.';

  @override
  bool get requiresApiKey => true;

  @override
  String get attribution => 'Weather data © OpenWeatherMap';

  @override
  String? get apiKeySignupUrl => 'https://home.openweathermap.org/users/sign_up';

  @override
  bool get supportsHistorical => false;

  @override
  SourceConfig get defaultConfig => SourceConfig(
        sourceId: id,
        enabled: false,
        priority: 20,
        updateIntervalMinutes: 60,
        maxCallsPerHour: 40,
        maxCallsPerDay: 1000,
      );

  static const _weatherBase =
      'https://api.openweathermap.org/data/2.5/weather';
  static const _forecastBase =
      'https://api.openweathermap.org/data/2.5/forecast';

  @override
  Future<WeatherBundle> fetchWeather(
    GeoLocation location,
    SourceConfig config,
  ) async {
    final key = config.apiKey?.trim();
    if (key == null || key.isEmpty) {
      throw MissingApiKeyException(id);
    }

    final params = {
      'lat': '${location.latitude}',
      'lon': '${location.longitude}',
      'appid': key,
      'units': 'metric',
    };

    final current = await _getJson(
      Uri.parse(_weatherBase).replace(queryParameters: params),
      config,
    );
    final forecast = await _getJson(
      Uri.parse(_forecastBase).replace(queryParameters: params),
      config,
    );

    return WeatherBundle(
      location: location,
      sourceId: id,
      sourceName: displayName,
      fetchedAt: DateTime.now(),
      current: _parseCurrent(current),
      hourly: _parseHourly(forecast),
      daily: _parseDaily(forecast),
      attribution: attribution,
    );
  }

  CurrentWeather _parseCurrent(Map<String, dynamic> j) {
    final main = j['main'] as Map<String, dynamic>? ?? {};
    final wind = j['wind'] as Map<String, dynamic>? ?? {};
    final clouds = j['clouds'] as Map<String, dynamic>? ?? {};
    final weatherList = (j['weather'] as List?) ?? const [];
    final w = weatherList.isNotEmpty
        ? weatherList.first as Map<String, dynamic>
        : <String, dynamic>{};
    final dt = _epoch(j['dt']);
    final isDay = _isDayFromIcon(w['icon'] as String?);

    return CurrentWeather(
      time: dt ?? DateTime.now(),
      temperature: _toD(main['temp']) ?? 0,
      condition: WeatherCondition.fromOwmCode(
        (w['id'] as num?)?.toInt() ?? 0,
        (w['description'] as String?) ?? '',
        isDay: isDay,
      ),
      apparentTemperature: _toD(main['feels_like']),
      humidity: _toD(main['humidity']),
      windSpeed: _msToKmh(_toD(wind['speed'])),
      windDirection: _toD(wind['deg']),
      windGust: _msToKmh(_toD(wind['gust'])),
      pressure: _toD(main['pressure']),
      cloudCover: _toD(clouds['all']),
      visibility: _toD(j['visibility']),
    );
  }

  List<HourlyPoint> _parseHourly(Map<String, dynamic> forecast) {
    final list = (forecast['list'] as List?) ?? const [];
    final out = <HourlyPoint>[];
    for (final raw in list.take(16)) {
      final e = raw as Map<String, dynamic>;
      final dt = _epoch(e['dt']);
      if (dt == null) continue;
      final main = e['main'] as Map<String, dynamic>? ?? {};
      final wind = e['wind'] as Map<String, dynamic>? ?? {};
      final weatherList = (e['weather'] as List?) ?? const [];
      final w = weatherList.isNotEmpty
          ? weatherList.first as Map<String, dynamic>
          : <String, dynamic>{};
      out.add(HourlyPoint(
        time: dt,
        temperature: _toD(main['temp']) ?? 0,
        condition: WeatherCondition.fromOwmCode(
          (w['id'] as num?)?.toInt() ?? 0,
          (w['description'] as String?) ?? '',
          isDay: _isDayFromIcon(w['icon'] as String?),
        ),
        precipitation: _toD((e['rain'] as Map?)?['3h']),
        precipitationProbability:
            e['pop'] is num ? (e['pop'] as num).toDouble() * 100 : null,
        windSpeed: _msToKmh(_toD(wind['speed'])),
        humidity: _toD(main['humidity']),
        apparentTemperature: _toD(main['feels_like']),
      ));
    }
    return out;
  }

  List<DailyPoint> _parseDaily(Map<String, dynamic> forecast) {
    final list = (forecast['list'] as List?) ?? const [];
    final byDate = <String, List<Map<String, dynamic>>>{};
    for (final raw in list) {
      final e = raw as Map<String, dynamic>;
      final dt = _epoch(e['dt']);
      if (dt == null) continue;
      final key = '${dt.year}-${dt.month}-${dt.day}';
      byDate.putIfAbsent(key, () => []).add(e);
    }

    final out = <DailyPoint>[];
    final keys = byDate.keys.toList()..sort();
    for (final key in keys) {
      final entries = byDate[key]!;
      double? tmax, tmin, precip, popMax;
      Map<String, dynamic>? noon;
      DateTime? date;
      for (final e in entries) {
        final dt = _epoch(e['dt']);
        if (dt == null) continue;
        date ??= DateTime(dt.year, dt.month, dt.day);
        final main = e['main'] as Map<String, dynamic>? ?? {};
        final tMax = _toD(main['temp_max']) ?? _toD(main['temp']);
        final tMin = _toD(main['temp_min']) ?? _toD(main['temp']);
        if (tMax != null) tmax = tmax == null ? tMax : (tMax > tmax ? tMax : tmax);
        if (tMin != null) tmin = tmin == null ? tMin : (tMin < tmin ? tMin : tmin);
        final p = _toD((e['rain'] as Map?)?['3h']);
        if (p != null) precip = (precip ?? 0) + p;
        if (e['pop'] is num) {
          final pop = (e['pop'] as num).toDouble() * 100;
          popMax = popMax == null ? pop : (pop > popMax ? pop : popMax);
        }
        if (noon == null || (dt.hour - 12).abs() <= 1) noon = e;
      }
      if (date == null) continue;
      final wl = ((noon?['weather'] as List?) ?? const []);
      final w = wl.isNotEmpty ? wl.first as Map<String, dynamic> : {};
      out.add(DailyPoint(
        date: date,
        tempMax: tmax ?? 0,
        tempMin: tmin ?? 0,
        condition: WeatherCondition.fromOwmCode(
          (w['id'] as num?)?.toInt() ?? 0,
          (w['description'] as String?) ?? '',
        ),
        precipitationSum: precip,
        precipitationProbabilityMax: popMax,
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
    throw WeatherSourceException(
        id, 'Historical data requires a paid OpenWeatherMap plan.');
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
    if (resp.statusCode == 401) {
      throw WeatherSourceException(id, 'Invalid API key (HTTP 401).');
    }
    if (resp.statusCode != 200) {
      throw WeatherSourceException(id, 'HTTP ${resp.statusCode}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  static double? _toD(dynamic v) => v is num ? v.toDouble() : null;
  static double? _msToKmh(double? ms) => ms == null ? null : ms * 3.6;
  static DateTime? _epoch(dynamic v) => v is num
      ? DateTime.fromMillisecondsSinceEpoch(v.toInt() * 1000).toLocal()
      : null;
  static bool _isDayFromIcon(String? icon) =>
      icon == null ? true : icon.endsWith('d');
}
