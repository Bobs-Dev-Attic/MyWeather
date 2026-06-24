import '../models/app_settings.dart';
import '../models/geo_location.dart';
import '../models/weather_data.dart';
import 'rate_limiter.dart';
import 'weather_source.dart';

/// The result of fetching one source: either a bundle or an error message.
class SourceResult {
  SourceResult({
    required this.sourceId,
    required this.sourceName,
    this.bundle,
    this.error,
    this.skippedReason,
    this.fromCache = false,
  });

  final String sourceId;
  final String sourceName;
  final WeatherBundle? bundle;
  final String? error;

  /// Set when the source was intentionally not called (rate limit, disabled,
  /// missing key). Distinct from [error].
  final String? skippedReason;
  final bool fromCache;

  bool get hasData => bundle != null;
}

class _CacheEntry {
  _CacheEntry(this.bundle, this.fetchedAt);
  final WeatherBundle bundle;
  final DateTime fetchedAt;
}

/// Orchestrates all weather sources: applies per-source enable flags, update
/// intervals (via an in-memory cache) and rolling rate limits, then fetches in
/// parallel and merges the results.
class WeatherRepository {
  WeatherRepository({
    required List<WeatherSource> sources,
    required RateLimiter rateLimiter,
  })  : _sources = {for (final s in sources) s.id: s},
        _rateLimiter = rateLimiter;

  final Map<String, WeatherSource> _sources;
  final RateLimiter _rateLimiter;
  final Map<String, _CacheEntry> _cache = {};

  List<WeatherSource> get sources => _sources.values.toList();

  WeatherSource? sourceById(String id) => _sources[id];

  RateLimiter get rateLimiter => _rateLimiter;

  String _cacheKey(String sourceId, GeoLocation loc) =>
      '$sourceId@${loc.key}';

  /// Fetches all enabled sources for [location], honouring per-source caching
  /// and rate limits. [force] bypasses cache and rate-limit skipping.
  Future<List<SourceResult>> fetchAll(
    GeoLocation location,
    AppSettings settings, {
    bool force = false,
  }) async {
    final enabled = _sources.values
        .where((s) => settings.configFor(s.id).enabled)
        .toList()
      ..sort((a, b) => settings
          .configFor(a.id)
          .priority
          .compareTo(settings.configFor(b.id).priority));

    final futures = enabled.map((source) async {
      final config = settings.configFor(source.id);
      final ckey = _cacheKey(source.id, location);

      // 1. Serve from cache if fresh enough (unless forced).
      if (!force) {
        final cached = _cache[ckey];
        if (cached != null) {
          final age = DateTime.now().difference(cached.fetchedAt);
          if (age.inMinutes < config.updateIntervalMinutes) {
            return SourceResult(
              sourceId: source.id,
              sourceName: source.displayName,
              bundle: cached.bundle,
              fromCache: true,
            );
          }
        }
      }

      // 2. Respect missing API keys.
      if (source.requiresApiKey &&
          (config.apiKey == null || config.apiKey!.trim().isEmpty)) {
        return SourceResult(
          sourceId: source.id,
          sourceName: source.displayName,
          skippedReason: 'API key not set',
          bundle: _cache[ckey]?.bundle,
        );
      }

      // 3. Respect rate limits (unless forced and within day cap).
      final allowed = _rateLimiter.canCall(
        source.id,
        maxPerHour: config.maxCallsPerHour,
        maxPerDay: config.maxCallsPerDay,
      );
      if (!allowed && !force) {
        return SourceResult(
          sourceId: source.id,
          sourceName: source.displayName,
          skippedReason: 'Rate limit reached',
          bundle: _cache[ckey]?.bundle,
          fromCache: _cache[ckey] != null,
        );
      }

      // 4. Fetch live.
      try {
        await _rateLimiter.record(source.id);
        final bundle = await source.fetchWeather(location, config);
        _cache[ckey] = _CacheEntry(bundle, DateTime.now());
        return SourceResult(
          sourceId: source.id,
          sourceName: source.displayName,
          bundle: bundle,
        );
      } catch (e) {
        return SourceResult(
          sourceId: source.id,
          sourceName: source.displayName,
          error: e.toString(),
          bundle: _cache[ckey]?.bundle,
        );
      }
    });

    return Future.wait(futures);
  }

  /// Chooses the headline bundle from a set of results, preferring the user's
  /// configured primary source, then by priority.
  WeatherBundle? primaryBundle(
    List<SourceResult> results,
    AppSettings settings,
  ) {
    final withData = results.where((r) => r.hasData).toList();
    if (withData.isEmpty) return null;

    if (settings.primarySourceId != null) {
      for (final r in withData) {
        if (r.sourceId == settings.primarySourceId) return r.bundle;
      }
    }
    withData.sort((a, b) => settings
        .configFor(a.sourceId)
        .priority
        .compareTo(settings.configFor(b.sourceId).priority));
    return withData.first.bundle;
  }

  /// Fetches historical data from the best available source that supports it.
  Future<HistoricalData> fetchHistorical(
    GeoLocation location,
    DateTime start,
    DateTime end,
    AppSettings settings,
  ) async {
    final candidates = _sources.values
        .where((s) =>
            s.supportsHistorical && settings.configFor(s.id).enabled)
        .toList()
      ..sort((a, b) => settings
          .configFor(a.id)
          .priority
          .compareTo(settings.configFor(b.id).priority));

    if (candidates.isEmpty) {
      throw WeatherSourceException(
          'history', 'No enabled source provides historical data.');
    }

    WeatherSourceException? lastError;
    for (final source in candidates) {
      final config = settings.configFor(source.id);
      if (source.requiresApiKey &&
          (config.apiKey == null || config.apiKey!.trim().isEmpty)) {
        continue;
      }
      try {
        await _rateLimiter.record(source.id);
        final data = await source.fetchHistorical(location, start, end, config);
        if (data.days.isNotEmpty) return data;
      } on WeatherSourceException catch (e) {
        lastError = e;
      } catch (e) {
        lastError = WeatherSourceException(source.id, e.toString());
      }
    }
    throw lastError ??
        WeatherSourceException('history', 'No historical data available.');
  }
}
