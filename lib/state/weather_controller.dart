import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../models/geo_location.dart';
import '../models/weather_data.dart';
import '../services/weather_repository.dart';

enum LoadStatus { idle, loading, loaded, error }

/// Drives weather loading for the currently selected location and exposes the
/// per-source results plus the chosen primary bundle.
class WeatherController extends ChangeNotifier {
  WeatherController({required WeatherRepository repository})
      : _repository = repository;

  final WeatherRepository _repository;

  LoadStatus _status = LoadStatus.idle;
  List<SourceResult> _results = [];
  WeatherBundle? _primary;
  GeoLocation? _location;
  String? _error;
  DateTime? _lastUpdated;

  LoadStatus get status => _status;
  List<SourceResult> get results => _results;
  WeatherBundle? get primary => _primary;
  GeoLocation? get location => _location;
  String? get error => _error;
  DateTime? get lastUpdated => _lastUpdated;

  WeatherRepository get repository => _repository;

  List<SourceResult> get resultsWithData =>
      _results.where((r) => r.hasData).toList();

  /// Loads weather for [location]. Skips redundant network work via the
  /// repository's caching unless [force] is set.
  Future<void> load(
    GeoLocation location,
    AppSettings settings, {
    bool force = false,
  }) async {
    _location = location;
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();

    try {
      final results = await _repository.fetchAll(
        location,
        settings,
        force: force,
      );
      _results = results;
      _primary = _repository.primaryBundle(results, settings);
      _lastUpdated = DateTime.now();

      if (_primary == null) {
        _status = LoadStatus.error;
        final firstError = results
            .firstWhere(
              (r) => r.error != null || r.skippedReason != null,
              orElse: () => SourceResult(
                sourceId: '',
                sourceName: '',
                error: 'No weather data available.',
              ),
            );
        _error = firstError.error ??
            firstError.skippedReason ??
            'No weather data available.';
      } else {
        _status = LoadStatus.loaded;
      }
    } catch (e) {
      _status = LoadStatus.error;
      _error = e.toString();
    }
    notifyListeners();
  }

  /// Re-selects the primary bundle without re-fetching (e.g. after the user
  /// changes their preferred primary source).
  void recomputePrimary(AppSettings settings) {
    if (_results.isEmpty) return;
    _primary = _repository.primaryBundle(_results, settings);
    notifyListeners();
  }
}
