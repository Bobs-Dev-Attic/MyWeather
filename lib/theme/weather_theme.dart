import 'package:flutter/material.dart';

import '../models/weather_condition.dart';

/// Maps weather conditions to background gradients so the whole screen reflects
/// the current sky.
class WeatherTheme {
  const WeatherTheme._();

  static List<Color> gradientFor(WeatherCondition condition) {
    final day = condition.isDay;
    switch (condition.category) {
      case WeatherCategory.clear:
        return day
            ? const [Color(0xFF2196F3), Color(0xFF64B5F6), Color(0xFF90CAF9)]
            : const [Color(0xFF0D1B3E), Color(0xFF1A237E), Color(0xFF283593)];
      case WeatherCategory.partlyCloudy:
        return day
            ? const [Color(0xFF4A90D9), Color(0xFF7FB2E5), Color(0xFFB0C4DE)]
            : const [Color(0xFF1A2138), Color(0xFF2C3E5C), Color(0xFF3E4E6E)];
      case WeatherCategory.cloudy:
        return day
            ? const [Color(0xFF607D8B), Color(0xFF90A4AE), Color(0xFFB0BEC5)]
            : const [Color(0xFF263238), Color(0xFF37474F), Color(0xFF455A64)];
      case WeatherCategory.fog:
        return day
            ? const [Color(0xFF9E9E9E), Color(0xFFBDBDBD), Color(0xFFE0E0E0)]
            : const [Color(0xFF37474F), Color(0xFF546E7A), Color(0xFF78909C)];
      case WeatherCategory.drizzle:
      case WeatherCategory.rain:
        return day
            ? const [Color(0xFF455A64), Color(0xFF546E7A), Color(0xFF78909C)]
            : const [Color(0xFF1C2833), Color(0xFF2C3E50), Color(0xFF34495E)];
      case WeatherCategory.snow:
        return day
            ? const [Color(0xFF78909C), Color(0xFFB0BEC5), Color(0xFFECEFF1)]
            : const [Color(0xFF2C3E50), Color(0xFF455A64), Color(0xFF607D8B)];
      case WeatherCategory.thunderstorm:
        return day
            ? const [Color(0xFF37474F), Color(0xFF455A64), Color(0xFF546E7A)]
            : const [Color(0xFF0F1419), Color(0xFF1C2331), Color(0xFF2C3E50)];
      case WeatherCategory.unknown:
        return day
            ? const [Color(0xFF5C6BC0), Color(0xFF7986CB), Color(0xFF9FA8DA)]
            : const [Color(0xFF1A237E), Color(0xFF283593), Color(0xFF303F9F)];
    }
  }

  /// A foreground color (text/icons) that contrasts with the gradient.
  static Color onGradient(WeatherCondition condition) {
    // Bright daytime fog/snow gradients need dark text.
    final bright = condition.isDay &&
        (condition.category == WeatherCategory.fog ||
            condition.category == WeatherCategory.snow);
    return bright ? const Color(0xDD000000) : Colors.white;
  }

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2196F3),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
      ),
    );
  }
}
