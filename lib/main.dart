import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'services/geocoding_service.dart';
import 'services/location_service.dart';
import 'services/rate_limiter.dart';
import 'services/source_registry.dart';
import 'services/storage_service.dart';
import 'services/weather_repository.dart';
import 'state/locations_controller.dart';
import 'state/settings_controller.dart';
import 'state/weather_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final storage = StorageService(prefs);
  final rateLimiter = RateLimiter(prefs);

  final sources = buildSources();
  final repository = WeatherRepository(
    sources: sources,
    rateLimiter: rateLimiter,
  );

  final geocoding = GeocodingService();
  final locationService = LocationService(geocoding: geocoding);

  runApp(
    MultiProvider(
      providers: [
        Provider<GeocodingService>.value(value: geocoding),
        Provider<WeatherRepository>.value(value: repository),
        ChangeNotifierProvider(
          create: (_) => SettingsController(storage: storage, sources: sources),
        ),
        ChangeNotifierProvider(
          create: (_) => LocationsController(
            storage: storage,
            locationService: locationService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => WeatherController(repository: repository),
        ),
      ],
      child: const MyWeatherApp(),
    ),
  );
}
