import 'package:geolocator/geolocator.dart';

import '../models/geo_location.dart';
import 'geocoding_service.dart';

/// Wraps device location access (permissions + GPS) and resolves the position
/// into a named [GeoLocation] via reverse geocoding.
class LocationService {
  LocationService({GeocodingService? geocoding})
      : _geocoding = geocoding ?? GeocodingService();

  final GeocodingService _geocoding;

  /// Ensures location services are enabled and permission is granted.
  /// Throws a descriptive [Exception] otherwise.
  Future<void> ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled on this device.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw Exception('Location permission was denied.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission is permanently denied. Enable it in settings.',
      );
    }
  }

  /// Gets the current device position as a named location.
  Future<GeoLocation> currentLocation() async {
    await ensurePermission();
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
      ),
    );
    return _geocoding.reverse(position.latitude, position.longitude);
  }
}
