import 'package:http/http.dart' as http;

import 'sources/met_no_source.dart';
import 'sources/open_meteo_source.dart';
import 'sources/openweathermap_source.dart';
import 'sources/weatherapi_source.dart';
import 'weather_source.dart';

/// Builds the list of all available weather sources.
///
/// Order here defines the default UI ordering; runtime selection of the primary
/// source is driven by per-source priority in settings.
List<WeatherSource> buildSources({http.Client? client}) {
  final c = client ?? http.Client();
  return [
    OpenMeteoSource(client: c),
    MetNoSource(client: c),
    OpenWeatherMapSource(client: c),
    WeatherApiSource(client: c),
  ];
}
