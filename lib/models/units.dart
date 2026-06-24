/// Display unit preferences. All weather data is stored internally in metric
/// canonical units (Celsius, km/h, mm, hPa) and converted at display time.

enum TemperatureUnit { celsius, fahrenheit }

enum WindSpeedUnit { kmh, mph, ms, knots }

enum PrecipitationUnit { mm, inch }

enum PressureUnit { hpa, inhg, mmhg }

extension TemperatureUnitX on TemperatureUnit {
  String get label {
    switch (this) {
      case TemperatureUnit.celsius:
        return 'Celsius (°C)';
      case TemperatureUnit.fahrenheit:
        return 'Fahrenheit (°F)';
    }
  }

  String get symbol => this == TemperatureUnit.celsius ? '°C' : '°F';

  /// Converts a canonical Celsius value into this unit.
  double fromCelsius(double c) =>
      this == TemperatureUnit.celsius ? c : c * 9 / 5 + 32;

  String format(double celsius, {int digits = 0}) =>
      '${fromCelsius(celsius).toStringAsFixed(digits)}$symbol';
}

extension WindSpeedUnitX on WindSpeedUnit {
  String get label {
    switch (this) {
      case WindSpeedUnit.kmh:
        return 'Kilometres / hour';
      case WindSpeedUnit.mph:
        return 'Miles / hour';
      case WindSpeedUnit.ms:
        return 'Metres / second';
      case WindSpeedUnit.knots:
        return 'Knots';
    }
  }

  String get symbol {
    switch (this) {
      case WindSpeedUnit.kmh:
        return 'km/h';
      case WindSpeedUnit.mph:
        return 'mph';
      case WindSpeedUnit.ms:
        return 'm/s';
      case WindSpeedUnit.knots:
        return 'kn';
    }
  }

  /// Converts a canonical km/h value into this unit.
  double fromKmh(double kmh) {
    switch (this) {
      case WindSpeedUnit.kmh:
        return kmh;
      case WindSpeedUnit.mph:
        return kmh * 0.621371;
      case WindSpeedUnit.ms:
        return kmh / 3.6;
      case WindSpeedUnit.knots:
        return kmh * 0.539957;
    }
  }

  String format(double kmh, {int digits = 0}) =>
      '${fromKmh(kmh).toStringAsFixed(digits)} $symbol';
}

extension PrecipitationUnitX on PrecipitationUnit {
  String get label =>
      this == PrecipitationUnit.mm ? 'Millimetres' : 'Inches';

  String get symbol => this == PrecipitationUnit.mm ? 'mm' : 'in';

  double fromMm(double mm) =>
      this == PrecipitationUnit.mm ? mm : mm * 0.0393701;

  String format(double mm, {int? digits}) {
    final d = digits ?? (this == PrecipitationUnit.mm ? 1 : 2);
    return '${fromMm(mm).toStringAsFixed(d)} $symbol';
  }
}

extension PressureUnitX on PressureUnit {
  String get label {
    switch (this) {
      case PressureUnit.hpa:
        return 'Hectopascals';
      case PressureUnit.inhg:
        return 'Inches of mercury';
      case PressureUnit.mmhg:
        return 'Millimetres of mercury';
    }
  }

  String get symbol {
    switch (this) {
      case PressureUnit.hpa:
        return 'hPa';
      case PressureUnit.inhg:
        return 'inHg';
      case PressureUnit.mmhg:
        return 'mmHg';
    }
  }

  double fromHpa(double hpa) {
    switch (this) {
      case PressureUnit.hpa:
        return hpa;
      case PressureUnit.inhg:
        return hpa * 0.02953;
      case PressureUnit.mmhg:
        return hpa * 0.750062;
    }
  }

  String format(double hpa) {
    final d = this == PressureUnit.hpa ? 0 : 2;
    return '${fromHpa(hpa).toStringAsFixed(d)} $symbol';
  }
}

/// Converts a wind direction in degrees into a compass label.
String windDirectionLabel(double degrees) {
  const dirs = [
    'N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE',
    'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW',
  ];
  final idx = ((degrees % 360) / 22.5).round() % 16;
  return dirs[idx];
}
