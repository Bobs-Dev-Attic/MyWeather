/// A geographic place the user can view weather for.
class GeoLocation {
  const GeoLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.country,
    this.admin1,
    this.timezone,
    this.id,
    this.isCurrent = false,
  });

  final String name;
  final double latitude;
  final double longitude;
  final String? country;

  /// State / region / province.
  final String? admin1;
  final String? timezone;

  /// Source-specific id (e.g. Open-Meteo geocoding id), if any.
  final int? id;

  /// True when this entry represents the device's current GPS position.
  final bool isCurrent;

  String get subtitle {
    final parts = <String>[];
    if (admin1 != null && admin1!.isNotEmpty) parts.add(admin1!);
    if (country != null && country!.isNotEmpty) parts.add(country!);
    return parts.join(', ');
  }

  /// A stable key used for de-duplication and persistence.
  String get key =>
      '${latitude.toStringAsFixed(3)},${longitude.toStringAsFixed(3)}';

  GeoLocation copyWith({String? name, bool? isCurrent}) => GeoLocation(
        name: name ?? this.name,
        latitude: latitude,
        longitude: longitude,
        country: country,
        admin1: admin1,
        timezone: timezone,
        id: id,
        isCurrent: isCurrent ?? this.isCurrent,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'country': country,
        'admin1': admin1,
        'timezone': timezone,
        'id': id,
        'isCurrent': isCurrent,
      };

  factory GeoLocation.fromJson(Map<String, dynamic> json) => GeoLocation(
        name: json['name'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        country: json['country'] as String?,
        admin1: json['admin1'] as String?,
        timezone: json['timezone'] as String?,
        id: json['id'] as int?,
        isCurrent: json['isCurrent'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      other is GeoLocation && other.key == key && other.isCurrent == isCurrent;

  @override
  int get hashCode => Object.hash(key, isCurrent);
}
