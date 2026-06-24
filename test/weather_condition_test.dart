import 'package:flutter_test/flutter_test.dart';
import 'package:myweather/models/weather_condition.dart';

void main() {
  group('WMO code mapping', () {
    test('clear sky', () {
      final c = WeatherCondition.fromWmoCode(0);
      expect(c.category, WeatherCategory.clear);
      expect(c.description, 'Clear sky');
    });
    test('rain codes', () {
      expect(WeatherCondition.fromWmoCode(61).category, WeatherCategory.rain);
      expect(WeatherCondition.fromWmoCode(65).category, WeatherCategory.rain);
      expect(WeatherCondition.fromWmoCode(80).category, WeatherCategory.rain);
    });
    test('snow codes', () {
      expect(WeatherCondition.fromWmoCode(71).category, WeatherCategory.snow);
      expect(WeatherCondition.fromWmoCode(86).category, WeatherCategory.snow);
    });
    test('thunderstorm codes', () {
      expect(WeatherCondition.fromWmoCode(95).category,
          WeatherCategory.thunderstorm);
      expect(WeatherCondition.fromWmoCode(99).category,
          WeatherCategory.thunderstorm);
    });
    test('unknown code', () {
      expect(WeatherCondition.fromWmoCode(1234).category,
          WeatherCategory.unknown);
    });
    test('day flag affects emoji for clear', () {
      expect(WeatherCondition.fromWmoCode(0, isDay: true).emoji, '☀️');
      expect(WeatherCondition.fromWmoCode(0, isDay: false).emoji, '🌙');
    });
  });

  group('OpenWeatherMap code mapping', () {
    test('thunderstorm range', () {
      expect(WeatherCondition.fromOwmCode(210, 'thunder').category,
          WeatherCategory.thunderstorm);
    });
    test('clear', () {
      expect(WeatherCondition.fromOwmCode(800, 'clear sky').category,
          WeatherCategory.clear);
    });
    test('few clouds is partly cloudy', () {
      expect(WeatherCondition.fromOwmCode(801, 'few clouds').category,
          WeatherCategory.partlyCloudy);
    });
    test('overcast is cloudy', () {
      expect(WeatherCondition.fromOwmCode(804, 'overcast').category,
          WeatherCategory.cloudy);
    });
    test('snow range', () {
      expect(WeatherCondition.fromOwmCode(601, 'snow').category,
          WeatherCategory.snow);
    });
  });
}
