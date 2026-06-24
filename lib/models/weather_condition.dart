import 'package:flutter/material.dart';

/// High level visual category used to drive animations and icons.
enum WeatherCategory {
  clear,
  partlyCloudy,
  cloudy,
  fog,
  drizzle,
  rain,
  snow,
  thunderstorm,
  unknown,
}

/// A resolved, source-agnostic description of the weather conditions.
///
/// Different sources encode conditions differently (Open-Meteo / Met.no use
/// WMO codes, OpenWeatherMap uses its own ids). Each source maps into this
/// common representation so the UI can stay source independent.
class WeatherCondition {
  const WeatherCondition({
    required this.category,
    required this.description,
    this.isDay = true,
  });

  final WeatherCategory category;
  final String description;
  final bool isDay;

  WeatherCondition copyWith({bool? isDay}) => WeatherCondition(
        category: category,
        description: description,
        isDay: isDay ?? this.isDay,
      );

  /// A representative emoji for compact displays.
  String get emoji {
    switch (category) {
      case WeatherCategory.clear:
        return isDay ? '☀️' : '🌙';
      case WeatherCategory.partlyCloudy:
        return isDay ? '⛅' : '☁️';
      case WeatherCategory.cloudy:
        return '☁️';
      case WeatherCategory.fog:
        return '🌫️';
      case WeatherCategory.drizzle:
        return '🌦️';
      case WeatherCategory.rain:
        return '🌧️';
      case WeatherCategory.snow:
        return '❄️';
      case WeatherCategory.thunderstorm:
        return '⛈️';
      case WeatherCategory.unknown:
        return '🌡️';
    }
  }

  /// A Material icon fallback.
  IconData get icon {
    switch (category) {
      case WeatherCategory.clear:
        return isDay ? Icons.wb_sunny : Icons.nightlight_round;
      case WeatherCategory.partlyCloudy:
        return isDay ? Icons.wb_cloudy : Icons.cloud;
      case WeatherCategory.cloudy:
        return Icons.cloud;
      case WeatherCategory.fog:
        return Icons.foggy;
      case WeatherCategory.drizzle:
        return Icons.grain;
      case WeatherCategory.rain:
        return Icons.water_drop;
      case WeatherCategory.snow:
        return Icons.ac_unit;
      case WeatherCategory.thunderstorm:
        return Icons.thunderstorm;
      case WeatherCategory.unknown:
        return Icons.thermostat;
    }
  }

  /// Maps a WMO weather interpretation code (used by Open-Meteo and Met.no's
  /// symbol translation) into a [WeatherCondition].
  static WeatherCondition fromWmoCode(int code, {bool isDay = true}) {
    WeatherCategory category;
    String description;
    switch (code) {
      case 0:
        category = WeatherCategory.clear;
        description = 'Clear sky';
        break;
      case 1:
        category = WeatherCategory.clear;
        description = 'Mainly clear';
        break;
      case 2:
        category = WeatherCategory.partlyCloudy;
        description = 'Partly cloudy';
        break;
      case 3:
        category = WeatherCategory.cloudy;
        description = 'Overcast';
        break;
      case 45:
        category = WeatherCategory.fog;
        description = 'Fog';
        break;
      case 48:
        category = WeatherCategory.fog;
        description = 'Depositing rime fog';
        break;
      case 51:
        category = WeatherCategory.drizzle;
        description = 'Light drizzle';
        break;
      case 53:
        category = WeatherCategory.drizzle;
        description = 'Moderate drizzle';
        break;
      case 55:
        category = WeatherCategory.drizzle;
        description = 'Dense drizzle';
        break;
      case 56:
        category = WeatherCategory.drizzle;
        description = 'Light freezing drizzle';
        break;
      case 57:
        category = WeatherCategory.drizzle;
        description = 'Dense freezing drizzle';
        break;
      case 61:
        category = WeatherCategory.rain;
        description = 'Slight rain';
        break;
      case 63:
        category = WeatherCategory.rain;
        description = 'Moderate rain';
        break;
      case 65:
        category = WeatherCategory.rain;
        description = 'Heavy rain';
        break;
      case 66:
        category = WeatherCategory.rain;
        description = 'Light freezing rain';
        break;
      case 67:
        category = WeatherCategory.rain;
        description = 'Heavy freezing rain';
        break;
      case 71:
        category = WeatherCategory.snow;
        description = 'Slight snow fall';
        break;
      case 73:
        category = WeatherCategory.snow;
        description = 'Moderate snow fall';
        break;
      case 75:
        category = WeatherCategory.snow;
        description = 'Heavy snow fall';
        break;
      case 77:
        category = WeatherCategory.snow;
        description = 'Snow grains';
        break;
      case 80:
        category = WeatherCategory.rain;
        description = 'Slight rain showers';
        break;
      case 81:
        category = WeatherCategory.rain;
        description = 'Moderate rain showers';
        break;
      case 82:
        category = WeatherCategory.rain;
        description = 'Violent rain showers';
        break;
      case 85:
        category = WeatherCategory.snow;
        description = 'Slight snow showers';
        break;
      case 86:
        category = WeatherCategory.snow;
        description = 'Heavy snow showers';
        break;
      case 95:
        category = WeatherCategory.thunderstorm;
        description = 'Thunderstorm';
        break;
      case 96:
        category = WeatherCategory.thunderstorm;
        description = 'Thunderstorm with slight hail';
        break;
      case 99:
        category = WeatherCategory.thunderstorm;
        description = 'Thunderstorm with heavy hail';
        break;
      default:
        category = WeatherCategory.unknown;
        description = 'Unknown';
    }
    return WeatherCondition(
      category: category,
      description: description,
      isDay: isDay,
    );
  }

  /// Maps an OpenWeatherMap condition id into a [WeatherCondition].
  /// See https://openweathermap.org/weather-conditions
  static WeatherCondition fromOwmCode(
    int code,
    String description, {
    bool isDay = true,
  }) {
    WeatherCategory category;
    if (code >= 200 && code < 300) {
      category = WeatherCategory.thunderstorm;
    } else if (code >= 300 && code < 400) {
      category = WeatherCategory.drizzle;
    } else if (code >= 500 && code < 600) {
      category = WeatherCategory.rain;
    } else if (code >= 600 && code < 700) {
      category = WeatherCategory.snow;
    } else if (code >= 700 && code < 800) {
      category = WeatherCategory.fog;
    } else if (code == 800) {
      category = WeatherCategory.clear;
    } else if (code == 801 || code == 802) {
      category = WeatherCategory.partlyCloudy;
    } else if (code == 803 || code == 804) {
      category = WeatherCategory.cloudy;
    } else {
      category = WeatherCategory.unknown;
    }
    return WeatherCondition(
      category: category,
      description: description.isEmpty ? 'Unknown' : description,
      isDay: isDay,
    );
  }
}
