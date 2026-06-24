import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/geo_location.dart';

/// Forward and reverse geocoding using free, key-less services:
///  * Open-Meteo Geocoding API for name/address search.
///  * BigDataCloud client reverse-geocode for coordinates -> place name.
class GeocodingService {
  GeocodingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _searchBase = 'https://geocoding-api.open-meteo.com/v1/search';
  static const _reverseBase =
      'https://api.bigdatacloud.net/data/reverse-geocode-client';

  /// Searches for places matching [query] (a name or partial address).
  Future<List<GeoLocation>> search(String query, {int count = 10}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final uri = Uri.parse(_searchBase).replace(queryParameters: {
      'name': trimmed,
      'count': '$count',
      'language': 'en',
      'format': 'json',
    });

    final resp = await _client
        .get(uri)
        .timeout(const Duration(seconds: 12));
    if (resp.statusCode != 200) {
      throw Exception('Geocoding failed (${resp.statusCode}).');
    }

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final results = (body['results'] as List?) ?? const [];
    return results.map((r) {
      final m = r as Map<String, dynamic>;
      return GeoLocation(
        name: m['name'] as String,
        latitude: (m['latitude'] as num).toDouble(),
        longitude: (m['longitude'] as num).toDouble(),
        country: m['country'] as String?,
        admin1: m['admin1'] as String?,
        timezone: m['timezone'] as String?,
        id: m['id'] as int?,
      );
    }).toList();
  }

  /// Resolves a human-friendly place name for raw coordinates.
  Future<GeoLocation> reverse(double latitude, double longitude) async {
    final uri = Uri.parse(_reverseBase).replace(queryParameters: {
      'latitude': '$latitude',
      'longitude': '$longitude',
      'localityLanguage': 'en',
    });

    try {
      final resp =
          await _client.get(uri).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final m = jsonDecode(resp.body) as Map<String, dynamic>;
        final city = (m['city'] as String?)?.trim();
        final locality = (m['locality'] as String?)?.trim();
        final principal =
            (m['principalSubdivision'] as String?)?.trim();
        final country = (m['countryName'] as String?)?.trim();
        final name = [city, locality].firstWhere(
          (e) => e != null && e.isNotEmpty,
          orElse: () => null,
        );
        return GeoLocation(
          name: (name == null || name.isEmpty) ? 'Current location' : name,
          latitude: latitude,
          longitude: longitude,
          country: country,
          admin1: principal,
          isCurrent: true,
        );
      }
    } catch (_) {
      // Fall through to a coordinate-only location.
    }

    return GeoLocation(
      name: 'Current location',
      latitude: latitude,
      longitude: longitude,
      isCurrent: true,
    );
  }

  void dispose() => _client.close();
}
