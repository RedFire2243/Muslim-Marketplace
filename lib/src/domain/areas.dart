import 'dart:math' as math;

/// A Central Jersey area with an approximate centroid.
///
/// Coordinates are rough town centers used only to estimate distance between
/// a member's preferred area and a listing. They are not addresses.
class Area {
  const Area(this.id, this.name, this.lat, this.lng, {this.aliases = const []});

  final String id;
  final String name;
  final double lat;
  final double lng;

  /// Lowercase spellings recognised by the text parser. Institutions (such as
  /// a university) are deliberately not aliases: studying somewhere does not
  /// establish where someone wants to find opportunities.
  final List<String> aliases;

  @override
  String toString() => name;
}

/// Supported areas for the Central Jersey launch.
abstract final class Areas {
  static const all = <Area>[
    Area(
      'new-brunswick',
      'New Brunswick',
      40.4862,
      -74.4518,
      aliases: ['new brunswick'],
    ),
    Area(
      'piscataway',
      'Piscataway',
      40.5549,
      -74.4643,
      aliases: ['piscataway'],
    ),
    Area('edison', 'Edison', 40.5187, -74.4121, aliases: ['edison']),
    Area(
      'highland-park',
      'Highland Park',
      40.4959,
      -74.4243,
      aliases: ['highland park'],
    ),
    Area(
      'east-brunswick',
      'East Brunswick',
      40.4279,
      -74.4160,
      aliases: ['east brunswick'],
    ),
    Area(
      'north-brunswick',
      'North Brunswick',
      40.4490,
      -74.4818,
      aliases: ['north brunswick'],
    ),
    Area(
      'south-brunswick',
      'South Brunswick',
      40.3820,
      -74.5310,
      aliases: ['south brunswick', 'kendall park', 'monmouth junction'],
    ),
    Area(
      'somerset',
      'Somerset',
      40.4976,
      -74.4885,
      aliases: ['somerset', 'franklin township', 'franklin twp'],
    ),
    Area('princeton', 'Princeton', 40.3573, -74.6672, aliases: ['princeton']),
    Area(
      'plainsboro',
      'Plainsboro',
      40.3332,
      -74.6007,
      aliases: ['plainsboro'],
    ),
    Area(
      'west-windsor',
      'West Windsor',
      40.2985,
      -74.6170,
      aliases: ['west windsor', 'princeton junction'],
    ),
    Area(
      'hamilton',
      'Hamilton',
      40.2290,
      -74.6550,
      aliases: ['hamilton', 'hamilton township'],
    ),
    Area('trenton', 'Trenton', 40.2206, -74.7597, aliases: ['trenton']),
    Area(
      'lawrenceville',
      'Lawrenceville',
      40.2968,
      -74.7296,
      aliases: ['lawrenceville', 'lawrence township'],
    ),
    Area('metuchen', 'Metuchen', 40.5432, -74.3632, aliases: ['metuchen']),
    Area(
      'woodbridge',
      'Woodbridge',
      40.5576,
      -74.2846,
      aliases: ['woodbridge', 'iselin'],
    ),
    Area(
      'sayreville',
      'Sayreville',
      40.4593,
      -74.3610,
      aliases: ['sayreville', 'parlin'],
    ),
    Area(
      'old-bridge',
      'Old Bridge',
      40.4146,
      -74.3654,
      aliases: ['old bridge'],
    ),
    Area(
      'monroe',
      'Monroe',
      40.3300,
      -74.4300,
      aliases: ['monroe', 'monroe township'],
    ),
    Area(
      'bridgewater',
      'Bridgewater',
      40.6007,
      -74.6482,
      aliases: ['bridgewater'],
    ),
  ];

  static final Map<String, Area> _byId = {for (final a in all) a.id: a};

  static Area? byId(String? id) => id == null ? null : _byId[id];

  /// Display name for an area id, falling back to the stored text.
  static String label(String? id) => byId(id)?.name ?? (id ?? '');

  /// Great-circle distance in miles between two areas.
  static double distanceMiles(Area a, Area b) {
    const earthRadiusMiles = 3958.8;
    final dLat = _rad(b.lat - a.lat);
    final dLng = _rad(b.lng - a.lng);
    final h =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(_rad(a.lat)) *
            math.cos(_rad(b.lat)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * earthRadiusMiles * math.asin(math.sqrt(h.toDouble()));
  }

  static double _rad(double deg) => deg * math.pi / 180;
}
