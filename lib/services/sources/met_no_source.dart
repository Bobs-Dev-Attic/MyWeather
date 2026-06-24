import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/geo_location.dart';
import '../../models/source_config.dart';
import '../../models/weather_condition.dart';
import '../../models/weather_data.dart';
import '../weather_source.dart';

/// MET Norway (met.no) Locationforecast 2.0. Free, no API key, but requires a
/// descriptive User-Agent per their terms of service. No historical endpoint.
class MetNoSource implements WeatherSource {
  MetNoSource({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Identifies this app to met.no as required by their ToS.
  static const _userAgent =
      'MyWeatherApp/1.0 github.com/bobs-dev-attic/myweather';

  @override
  String get id => 'met_no';

  @override
  String get displayName => 'MET Norway';

  @override
  String get description =>
      'Free, no API key. High quality global forecast from met.no.';

  @override
  bool get requiresApiKey => false;

  @override
  String get attribution => 'Forecast from MET Norway (met.no), CC BY 4.0';

  @override
  String? get apiKeySignupUrl => null;

  @override
  bool get supportsHistorical => false;

  @override
  SourceConfig get defaultConfig => SourceConfig(
        sourceId: id,
        priority: 10,
        updateIntervalMinutes: 30,
        maxCallsPerHour: 60,
        maxCallsPerDay: 1000,
      );

  static const _base =
      'https://api.met.no/weatherapi/locationforecast/2.0/compact';

  @override
  Future<WeatherBundle> fetchWeather(
    GeoLocation location,
    SourceConfig config,
  ) async {
    final uri = Uri.parse(_base).replace(queryParameters: {
      'lat': location.latitude.toStringAsFixed(4),
      'lon': location.longitude.toStringAsFixed(4),
    });

    final http.Response resp;
    try {
      resp = await _client.get(uri, headers: {
        'User-Agent': _userAgent,
        'Accept': 'application/json',
      }).timeout(Duration(seconds: config.timeoutSeconds));
    } catch (e) {
      throw WeatherSourceException(id, 'Network error: $e');
    }
    if (resp.statusCode != 200) {
      throw WeatherSourceException(id, 'HTTP ${resp.statusCode}');
    }

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final series = ((body['properties'] as Map?)?['timeseries'] as List?) ??
        const [];
    if (series.isEmpty) {
      throw WeatherSourceException(id, 'Empty forecast.');
    }

    final current = _parseCurrent(series.first as Map<String, dynamic>);
    final hourly = _parseHourly(series);
    final daily = _parseDaily(series);

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

  CurrentWeather _parseCurrent(Map<String, dynamic> entry) {
    final time = DateTime.tryParse(entry['time'] as String? ?? '')?.toLocal() ??
        DateTime.now();
    final data = entry['data'] as Map<String, dynamic>;
    final instant =
        (data['instant'] as Map?)?['details'] as Map<String, dynamic>? ?? {};
    final symbol = _symbolOf(data);
    final precip = _precipOf(data);

    return CurrentWeather(
      time: time,
      temperature: _toD(instant['air_temperature']) ?? 0,
      condition: _conditionFromSymbol(symbol, isDay: _isDaytime(time)),
      humidity: _toD(instant['relative_humidity']),
      windSpeed: _msToKmh(_toD(instant['wind_speed'])),
      windDirection: _toD(instant['wind_from_direction']),
      windGust: _msToKmh(_toD(instant['wind_speed_of_gust'])),
      pressure: _toD(instant['air_pressure_at_sea_level']),
      precipitation: precip,
      cloudCover: _toD(instant['cloud_area_fraction']),
    );
  }

  List<HourlyPoint> _parseHourly(List series) {
    final now = DateTime.now();
    final out = <HourlyPoint>[];
    for (final raw in series) {
      final entry = raw as Map<String, dynamic>;
      final time =
          DateTime.tryParse(entry['time'] as String? ?? '')?.toLocal();
      if (time == null) continue;
      if (time.isBefore(now.subtract(const Duration(hours: 1)))) continue;
      if (time.isAfter(now.add(const Duration(hours: 48)))) break;
      final data = entry['data'] as Map<String, dynamic>;
      final instant =
          (data['instant'] as Map?)?['details'] as Map<String, dynamic>? ?? {};
      out.add(HourlyPoint(
        time: time,
        temperature: _toD(instant['air_temperature']) ?? 0,
        condition:
            _conditionFromSymbol(_symbolOf(data), isDay: _isDaytime(time)),
        precipitation: _precipOf(data),
        windSpeed: _msToKmh(_toD(instant['wind_speed'])),
        humidity: _toD(instant['relative_humidity']),
      ));
    }
    return out;
  }

  List<DailyPoint> _parseDaily(List series) {
    // Group timeseries entries by calendar date to derive daily aggregates.
    final byDate = <String, List<Map<String, dynamic>>>{};
    for (final raw in series) {
      final entry = raw as Map<String, dynamic>;
      final time =
          DateTime.tryParse(entry['time'] as String? ?? '')?.toLocal();
      if (time == null) continue;
      final key = '${time.year}-${time.month}-${time.day}';
      byDate.putIfAbsent(key, () => []).add(entry);
    }

    final out = <DailyPoint>[];
    final sortedKeys = byDate.keys.toList()..sort();
    for (final key in sortedKeys.take(7)) {
      final entries = byDate[key]!;
      double? tmax, tmin, precipSum;
      String? noonSymbol;
      DateTime? date;
      for (final entry in entries) {
        final time =
            DateTime.tryParse(entry['time'] as String? ?? '')?.toLocal();
        if (time == null) continue;
        date ??= DateTime(time.year, time.month, time.day);
        final data = entry['data'] as Map<String, dynamic>;
        final instant =
            (data['instant'] as Map?)?['details'] as Map<String, dynamic>? ??
                {};
        final temp = _toD(instant['air_temperature']);
        if (temp != null) {
          tmax = tmax == null ? temp : (temp > tmax ? temp : tmax);
          tmin = tmin == null ? temp : (temp < tmin ? temp : tmin);
        }
        final p = _precipOf(data);
        if (p != null) precipSum = (precipSum ?? 0) + p;
        // Prefer the symbol nearest local noon as the day's representative.
        if (noonSymbol == null || (time.hour - 12).abs() <= 1) {
          final s = _symbolOf(data);
          if (s != null) noonSymbol = s;
        }
      }
      if (date == null) continue;
      out.add(DailyPoint(
        date: date,
        tempMax: tmax ?? 0,
        tempMin: tmin ?? 0,
        condition: _conditionFromSymbol(noonSymbol, isDay: true),
        precipitationSum: precipSum,
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
        id, 'MET Norway does not provide historical data.');
  }

  // --- helpers ---

  static String? _symbolOf(Map<String, dynamic> data) {
    for (final key in ['next_1_hours', 'next_6_hours', 'next_12_hours']) {
      final summary = (data[key] as Map?)?['summary'] as Map?;
      final code = summary?['symbol_code'] as String?;
      if (code != null) return code;
    }
    return null;
  }

  static double? _precipOf(Map<String, dynamic> data) {
    for (final key in ['next_1_hours', 'next_6_hours']) {
      final details = (data[key] as Map?)?['details'] as Map?;
      final amount = details?['precipitation_amount'];
      if (amount is num) return amount.toDouble();
    }
    return null;
  }

  /// Maps a met.no symbol_code (e.g. "partlycloudy_day") to a condition.
  static WeatherCondition _conditionFromSymbol(String? symbol,
      {required bool isDay}) {
    if (symbol == null) {
      return WeatherCondition(
        category: WeatherCategory.unknown,
        description: 'Unknown',
        isDay: isDay,
      );
    }
    final base = symbol
        .replaceAll('_day', '')
        .replaceAll('_night', '')
        .replaceAll('_polartwilight', '');
    final daySuffix = symbol.contains('_night') ? false : isDay;

    WeatherCategory category;
    if (base.contains('thunder')) {
      category = WeatherCategory.thunderstorm;
    } else if (base.contains('snow') || base.contains('sleet')) {
      category = WeatherCategory.snow;
    } else if (base.contains('rain') || base.contains('showers')) {
      category = WeatherCategory.rain;
    } else if (base.contains('fog')) {
      category = WeatherCategory.fog;
    } else if (base == 'cloudy') {
      category = WeatherCategory.cloudy;
    } else if (base == 'partlycloudy') {
      category = WeatherCategory.partlyCloudy;
    } else if (base == 'fair') {
      category = WeatherCategory.partlyCloudy;
    } else if (base == 'clearsky') {
      category = WeatherCategory.clear;
    } else {
      category = WeatherCategory.unknown;
    }

    return WeatherCondition(
      category: category,
      description: _prettifySymbol(base),
      isDay: daySuffix,
    );
  }

  static String _prettifySymbol(String base) {
    switch (base) {
      case 'clearsky':
        return 'Clear sky';
      case 'fair':
        return 'Fair';
      case 'partlycloudy':
        return 'Partly cloudy';
      case 'cloudy':
        return 'Cloudy';
      case 'fog':
        return 'Fog';
      case 'rain':
        return 'Rain';
      case 'lightrain':
        return 'Light rain';
      case 'heavyrain':
        return 'Heavy rain';
      case 'rainshowers':
        return 'Rain showers';
      case 'snow':
        return 'Snow';
      case 'sleet':
        return 'Sleet';
      default:
        return base.isEmpty ? 'Unknown' : base;
    }
  }

  static double? _toD(dynamic v) => v is num ? v.toDouble() : null;

  static double? _msToKmh(double? ms) => ms == null ? null : ms * 3.6;

  static bool _isDaytime(DateTime t) => t.hour >= 6 && t.hour < 20;
}
