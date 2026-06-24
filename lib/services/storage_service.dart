import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/geo_location.dart';

/// Persists user settings and saved locations using SharedPreferences.
class StorageService {
  StorageService(this._prefs);

  final SharedPreferences _prefs;

  static const _settingsKey = 'app_settings';
  static const _locationsKey = 'saved_locations';
  static const _selectedKey = 'selected_location_key';

  AppSettings loadSettings() {
    final raw = _prefs.getString(_settingsKey);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  List<GeoLocation> loadLocations() {
    final raw = _prefs.getString(_locationsKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => GeoLocation.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveLocations(List<GeoLocation> locations) async {
    await _prefs.setString(
      _locationsKey,
      jsonEncode(locations.map((e) => e.toJson()).toList()),
    );
  }

  String? loadSelectedKey() => _prefs.getString(_selectedKey);

  Future<void> saveSelectedKey(String? key) async {
    if (key == null) {
      await _prefs.remove(_selectedKey);
    } else {
      await _prefs.setString(_selectedKey, key);
    }
  }
}
