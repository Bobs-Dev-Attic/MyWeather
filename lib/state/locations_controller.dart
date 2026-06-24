import 'package:flutter/foundation.dart';

import '../models/geo_location.dart';
import '../services/location_service.dart';
import '../services/storage_service.dart';

/// Manages the user's saved locations and the currently selected one.
class LocationsController extends ChangeNotifier {
  LocationsController({
    required StorageService storage,
    required LocationService locationService,
  })  : _storage = storage,
        _locationService = locationService {
    _locations = _storage.loadLocations();
    final savedKey = _storage.loadSelectedKey();
    if (savedKey != null) {
      final idx = _locations.indexWhere((l) => l.key == savedKey);
      if (idx >= 0) _selectedIndex = idx;
    }
  }

  final StorageService _storage;
  final LocationService _locationService;

  List<GeoLocation> _locations = [];
  int _selectedIndex = 0;
  bool _locating = false;
  String? _locationError;

  List<GeoLocation> get locations => List.unmodifiable(_locations);
  bool get isLocating => _locating;
  String? get locationError => _locationError;

  bool get hasSelection =>
      _locations.isNotEmpty && _selectedIndex < _locations.length;

  GeoLocation? get selected =>
      hasSelection ? _locations[_selectedIndex] : null;

  int get selectedIndex => _selectedIndex;

  Future<void> _persist() async {
    await _storage.saveLocations(_locations);
    await _storage.saveSelectedKey(selected?.key);
    notifyListeners();
  }

  void select(int index) {
    if (index < 0 || index >= _locations.length) return;
    _selectedIndex = index;
    _persist();
  }

  void selectLocation(GeoLocation location) {
    final idx = _locations.indexWhere((l) => l.key == location.key);
    if (idx >= 0) select(idx);
  }

  /// Adds a location if not already present and selects it.
  Future<void> addLocation(GeoLocation location) async {
    final existing = _locations.indexWhere((l) => l.key == location.key);
    if (existing >= 0) {
      _selectedIndex = existing;
    } else {
      _locations.add(location);
      _selectedIndex = _locations.length - 1;
    }
    await _persist();
  }

  Future<void> removeLocation(GeoLocation location) async {
    final wasSelected = selected?.key == location.key;
    _locations.removeWhere((l) => l.key == location.key);
    if (wasSelected || _selectedIndex >= _locations.length) {
      _selectedIndex = 0;
    }
    await _persist();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final selectedKey = selected?.key;
    final item = _locations.removeAt(oldIndex);
    _locations.insert(newIndex, item);
    if (selectedKey != null) {
      _selectedIndex = _locations.indexWhere((l) => l.key == selectedKey);
      if (_selectedIndex < 0) _selectedIndex = 0;
    }
    await _persist();
  }

  /// Detects the device location, adds it (replacing any prior current-location
  /// entry) and selects it.
  Future<void> useCurrentLocation() async {
    _locating = true;
    _locationError = null;
    notifyListeners();
    try {
      final loc = await _locationService.currentLocation();
      _locations.removeWhere((l) => l.isCurrent);
      _locations.insert(0, loc);
      _selectedIndex = 0;
      await _persist();
    } catch (e) {
      _locationError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _locating = false;
      notifyListeners();
    }
  }
}
