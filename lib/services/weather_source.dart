import '../models/geo_location.dart';
import '../models/source_config.dart';
import '../models/weather_data.dart';

/// Thrown when a source cannot fulfil a request.
class WeatherSourceException implements Exception {
  WeatherSourceException(this.sourceId, this.message);
  final String sourceId;
  final String message;
  @override
  String toString() => '[$sourceId] $message';
}

/// Thrown specifically when a source needs an API key that is missing.
class MissingApiKeyException extends WeatherSourceException {
  MissingApiKeyException(String sourceId)
      : super(sourceId, 'An API key is required for this source.');
}

/// Common interface implemented by every weather provider.
abstract class WeatherSource {
  /// Stable identifier used as a config/persistence key.
  String get id;

  /// Human readable name shown in the UI.
  String get displayName;

  /// Short description shown in settings.
  String get description;

  /// Whether the provider requires a user-supplied API key.
  bool get requiresApiKey;

  /// Attribution string required by the provider's terms.
  String get attribution;

  /// URL where users can obtain an API key (null if not applicable).
  String? get apiKeySignupUrl;

  /// Whether this source can serve historical data.
  bool get supportsHistorical;

  /// Default per-source configuration tuned to the provider's free tier.
  SourceConfig get defaultConfig;

  /// Fetches current conditions + forecast for [location].
  Future<WeatherBundle> fetchWeather(GeoLocation location, SourceConfig config);

  /// Fetches historical daily data for [location] between [start] and [end].
  Future<HistoricalData> fetchHistorical(
    GeoLocation location,
    DateTime start,
    DateTime end,
    SourceConfig config,
  );
}
