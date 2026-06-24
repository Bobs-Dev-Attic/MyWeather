import 'package:flutter_test/flutter_test.dart';
import 'package:myweather/models/units.dart';

void main() {
  group('TemperatureUnit', () {
    test('celsius is identity', () {
      expect(TemperatureUnit.celsius.fromCelsius(20), 20);
    });
    test('fahrenheit conversion', () {
      expect(TemperatureUnit.fahrenheit.fromCelsius(0), 32);
      expect(TemperatureUnit.fahrenheit.fromCelsius(100), 212);
    });
    test('format includes symbol', () {
      expect(TemperatureUnit.celsius.format(21.4), '21°C');
      expect(TemperatureUnit.fahrenheit.format(0), '32°F');
    });
  });

  group('WindSpeedUnit', () {
    test('km/h is identity', () {
      expect(WindSpeedUnit.kmh.fromKmh(36), 36);
    });
    test('m/s conversion', () {
      expect(WindSpeedUnit.ms.fromKmh(36), closeTo(10, 1e-9));
    });
    test('mph conversion', () {
      expect(WindSpeedUnit.mph.fromKmh(100), closeTo(62.1371, 1e-3));
    });
  });

  group('PrecipitationUnit', () {
    test('inch conversion', () {
      expect(PrecipitationUnit.inch.fromMm(25.4), closeTo(1.0, 1e-3));
    });
  });

  group('PressureUnit', () {
    test('inHg conversion', () {
      expect(PressureUnit.inhg.fromHpa(1013.25), closeTo(29.92, 1e-1));
    });
  });

  group('windDirectionLabel', () {
    test('cardinal directions', () {
      expect(windDirectionLabel(0), 'N');
      expect(windDirectionLabel(90), 'E');
      expect(windDirectionLabel(180), 'S');
      expect(windDirectionLabel(270), 'W');
      expect(windDirectionLabel(360), 'N');
    });
  });
}
