import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/geo_location.dart';
import '../../models/source_config.dart';
import '../../models/weather_condition.dart';
import '../../models/weather_data.dart';
import '../weather_source.dart';

/// WeatherAPI.com using the free plan (forecast + recent history). Requires a
/// free API key. History on the free plan is limited to the last 7 days.
class WeatherApiSource implements WeatherSource {
  WeatherApiSource({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  String get id => 'weatherapi';

  @override
  String get displayName => 'WeatherAPI.com';

  @override
  String get description =>
      'Free tier (1M calls/month) with a personal API key. 7-day history.';

  @override
  bool get requiresApiKey => true;

  @override
  String get attribution => 'Powered by WeatherAPI.com';

  @override
  String? get apiKeySignupUrl => 'https://www.weatherapi.com/signup.aspx';

  @override
  bool get supportsHistorical => true;

  @override
  SourceConfig get defaultConfig => SourceConfig(
        sourceId: id,
        enabled: false,
        priority: 30,
        updateIntervalMinutes: 30,
        maxCallsPerHour: 100,
        maxCallsPerDay: 5000,
      );

  static const _forecastBase = 'https://api.weatherapi.com/v1/forecast.json';
  static const _historyBase = 'https://api.weatherapi.com/v1/history.json';

  @override
  Future<WeatherBundle> fetchWeather(
    GeoLocation location,
    SourceConfig config,
  ) async {
    final key = config.apiKey?.trim();
    if (key == null || key.isEmpty) {
      throw MissingApiKeyException(id);
    }

    final uri = Uri.parse(_forecastBase).replace(queryParameters: {
      'key': key,
      'q': '${location.latitude},${location.longitude}',
      'days': '3',
      'aqi': 'no',
      'alerts': 'no',
    });

    final j = await _getJson(uri, config);
    final current = j['current'] as Map<String, dynamic>? ?? {};
    final forecastDays =
        ((j['forecast'] as Map?)?['forecastday'] as List?) ?? const [];

    return WeatherBundle(
      location: location,
      sourceId: id,
      sourceName: displayName,
      fetchedAt: DateTime.now(),
      current: _parseCurrent(current),
      hourly: _parseHourly(forecastDays),
      daily: _parseDaily(forecastDays),
      attribution: attribution,
    );
  }

  CurrentWeather _parseCurrent(Map<String, dynamic> c) {
    final cond = c['condition'] as Map<String, dynamic>? ?? {};
    final isDay = (c['is_day'] as num?)?.toInt() == 1;
    return CurrentWeather(
      time: _epoch(c['last_updated_epoch']) ?? DateTime.now(),
      temperature: _toD(c['temp_c']) ?? 0,
      condition: _mapCode(
        (cond['code'] as num?)?.toInt() ?? 1000,
        (cond['text'] as String?) ?? '',
        isDay: isDay,
      ),
      apparentTemperature: _toD(c['feelslike_c']),
      humidity: _toD(c['humidity']),
      windSpeed: _toD(c['wind_kph']),
      windDirection: _toD(c['wind_degree']),
      windGust: _toD(c['gust_kph']),
      pressure: _toD(c['pressure_mb']),
      precipitation: _toD(c['precip_mm']),
      cloudCover: _toD(c['cloud']),
      visibility: _toD(c['vis_km']) != null ? _toD(c['vis_km'])! * 1000 : null,
    );
  }

  List<HourlyPoint> _parseHourly(List forecastDays) {
    final out = <HourlyPoint>[];
    final now = DateTime.now();
    for (final raw in forecastDays) {
      final day = raw as Map<String, dynamic>;
      final hours = (day['hour'] as List?) ?? const [];
      for (final hraw in hours) {
        final h = hraw as Map<String, dynamic>;
        final t = _epoch(h['time_epoch']);
        if (t == null) continue;
        if (t.isBefore(now.subtract(const Duration(hours: 1)))) continue;
        if (t.isAfter(now.add(const Duration(hours: 48)))) return out;
        final cond = h['condition'] as Map<String, dynamic>? ?? {};
        out.add(HourlyPoint(
          time: t,
          temperature: _toD(h['temp_c']) ?? 0,
          condition: _mapCode(
            (cond['code'] as num?)?.toInt() ?? 1000,
            (cond['text'] as String?) ?? '',
            isDay: (h['is_day'] as num?)?.toInt() == 1,
          ),
          precipitation: _toD(h['precip_mm']),
          precipitationProbability: _toD(h['chance_of_rain']),
          windSpeed: _toD(h['wind_kph']),
          humidity: _toD(h['humidity']),
          apparentTemperature: _toD(h['feelslike_c']),
        ));
      }
    }
    return out;
  }

  List<DailyPoint> _parseDaily(List forecastDays) {
    final out = <DailyPoint>[];
    for (final raw in forecastDays) {
      final day = raw as Map<String, dynamic>;
      final date = _epoch(day['date_epoch']);
      if (date == null) continue;
      final d = day['day'] as Map<String, dynamic>? ?? {};
      final astro = day['astro'] as Map<String, dynamic>? ?? {};
      final cond = d['condition'] as Map<String, dynamic>? ?? {};
      out.add(DailyPoint(
        date: DateTime(date.year, date.month, date.day),
        tempMax: _toD(d['maxtemp_c']) ?? 0,
        tempMin: _toD(d['mintemp_c']) ?? 0,
        condition: _mapCode(
          (cond['code'] as num?)?.toInt() ?? 1000,
          (cond['text'] as String?) ?? '',
        ),
        precipitationSum: _toD(d['totalprecip_mm']),
        precipitationProbabilityMax: _toD(d['daily_chance_of_rain']),
        windSpeedMax: _toD(d['maxwind_kph']),
        uvIndexMax: _toD(d['uv']),
        sunrise: _parseAstroTime(date, astro['sunrise'] as String?),
        sunset: _parseAstroTime(date, astro['sunset'] as String?),
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
    final key = config.apiKey?.trim();
    if (key == null || key.isEmpty) {
      throw MissingApiKeyException(id);
    }

    // Free plan only exposes the last 7 days; clamp the request accordingly.
    final earliest = DateTime.now().subtract(const Duration(days: 7));
    var cursor = start.isBefore(earliest) ? earliest : start;
    final days = <HistoricalDay>[];
    var guard = 0;
    while (!cursor.isAfter(end) && guard < 8) {
      guard++;
      final uri = Uri.parse(_historyBase).replace(queryParameters: {
        'key': key,
        'q': '${location.latitude},${location.longitude}',
        'dt': _fmtDate(cursor),
      });
      try {
        final j = await _getJson(uri, config);
        final fd =
            ((j['forecast'] as Map?)?['forecastday'] as List?) ?? const [];
        for (final raw in fd) {
          final day = raw as Map<String, dynamic>;
          final date = _epoch(day['date_epoch']);
          final d = day['day'] as Map<String, dynamic>? ?? {};
          if (date == null) continue;
          days.add(HistoricalDay(
            date: DateTime(date.year, date.month, date.day),
            tempMax: _toD(d['maxtemp_c']),
            tempMin: _toD(d['mintemp_c']),
            tempMean: _toD(d['avgtemp_c']),
            precipitationSum: _toD(d['totalprecip_mm']),
            windSpeedMax: _toD(d['maxwind_kph']),
          ));
        }
      } catch (_) {
        // Skip days that fail; continue gathering the rest.
      }
      cursor = cursor.add(const Duration(days: 1));
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
    if (resp.statusCode == 401 || resp.statusCode == 403) {
      throw WeatherSourceException(id, 'Invalid API key (HTTP ${resp.statusCode}).');
    }
    if (resp.statusCode != 200) {
      throw WeatherSourceException(id, 'HTTP ${resp.statusCode}');
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    if (decoded['error'] != null) {
      final msg = (decoded['error'] as Map)['message'] ?? 'Unknown error';
      throw WeatherSourceException(id, '$msg');
    }
    return decoded;
  }

  /// Maps WeatherAPI.com condition codes to a [WeatherCondition].
  static WeatherCondition _mapCode(int code, String text, {bool isDay = true}) {
    WeatherCategory category;
    switch (code) {
      case 1000:
        category = WeatherCategory.clear;
        break;
      case 1003:
        category = WeatherCategory.partlyCloudy;
        break;
      case 1006:
      case 1009:
        category = WeatherCategory.cloudy;
        break;
      case 1030:
      case 1135:
      case 1147:
        category = WeatherCategory.fog;
        break;
      case 1063:
      case 1150:
      case 1153:
      case 1168:
      case 1171:
      case 1180:
      case 1183:
      case 1186:
      case 1189:
      case 1192:
      case 1195:
      case 1198:
      case 1201:
      case 1240:
      case 1243:
      case 1246:
        category = WeatherCategory.rain;
        break;
      case 1066:
      case 1069:
      case 1072:
      case 1114:
      case 1117:
      case 1204:
      case 1207:
      case 1210:
      case 1213:
      case 1216:
      case 1219:
      case 1222:
      case 1225:
      case 1237:
      case 1249:
      case 1252:
      case 1255:
      case 1258:
      case 1261:
      case 1264:
        category = WeatherCategory.snow;
        break;
      case 1087:
      case 1273:
      case 1276:
      case 1279:
      case 1282:
        category = WeatherCategory.thunderstorm;
        break;
      default:
        category = WeatherCategory.unknown;
    }
    return WeatherCondition(
      category: category,
      description: text.isEmpty ? 'Unknown' : text,
      isDay: isDay,
    );
  }

  static DateTime? _parseAstroTime(DateTime date, String? time) {
    if (time == null) return null;
    // Format e.g. "06:12 AM".
    final match = RegExp(r'(\d+):(\d+)\s*([AP]M)', caseSensitive: false)
        .firstMatch(time);
    if (match == null) return null;
    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final pm = match.group(3)!.toUpperCase() == 'PM';
    if (pm && hour != 12) hour += 12;
    if (!pm && hour == 12) hour = 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  static double? _toD(dynamic v) => v is num ? v.toDouble() : null;
  static DateTime? _epoch(dynamic v) => v is num
      ? DateTime.fromMillisecondsSinceEpoch(v.toInt() * 1000).toLocal()
      : null;
  static String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
