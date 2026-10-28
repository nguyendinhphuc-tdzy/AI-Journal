import 'dart:convert';

/// Explore's own map styles, in the app's palette, on OpenFreeMap's tiles
/// and fonts (the same sources as its "liberty" style).
///
/// Only what helps find a place: land, parks, water, buildings, roads,
/// street and area names. No shops or icons, so Nudaeng's pins stand out.
/// One light style, mint on Background, for every map in the app (Explore,
/// the place picker) at any hour. A darker night style was dropped on
/// 28/10/2026: it was hard to read.
abstract final class ExploreMapStyle {
  static final day = _style(_Palette.day);

  /// Night from 18:00 to 05:00: only Explore's "Vibe ban đêm" greeting and
  /// its night markers change; the map stays light.
  static bool isNightAt(DateTime time) => time.hour >= 18 || time.hour < 5;

  static const _tiles = 'https://tiles.openfreemap.org/planet';
  static const _glyphs =
      'https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf';

  /// Vietnamese names first (OSM's `name` is the local one).
  static const _name = [
    'coalesce',
    ['get', 'name'],
    ['get', 'name:latin']
  ];

  static List<Object> _classes(List<String> classes) => [
        'match',
        ['get', 'class'],
        classes,
        true,
        false
      ];

  static List<Object> _width(double z8, double z20) => [
        'interpolate',
        ['exponential', 1.2],
        ['zoom'],
        8,
        z8,
        20,
        z20,
      ];

  static String _style(_Palette p) => jsonEncode({
        'version': 8,
        'name': 'AI Diary ${p.name}',
        'glyphs': _glyphs,
        'sources': {
          'openmaptiles': {'type': 'vector', 'url': _tiles},
        },
        'layers': [
          {
            'id': 'background',
            'type': 'background',
            'paint': {'background-color': p.land},
          },
          _fill('residential', 'landuse', p.residential, filter: [
            '==',
            ['get', 'class'],
            'residential'
          ]),
          _fill('park', 'park', p.park),
          _fill('green', 'landcover', p.park,
              filter: _classes(['grass', 'wood', 'wetland'])),
          _fill('water', 'water', p.water, filter: [
            '!=',
            ['get', 'brunnel'],
            'tunnel'
          ]),
          {
            'id': 'waterway',
            'type': 'line',
            'source': 'openmaptiles',
            'source-layer': 'waterway',
            'paint': {'line-color': p.water, 'line-width': _width(0.5, 6)},
          },
          {
            'id': 'aeroway',
            'type': 'line',
            'source': 'openmaptiles',
            'source-layer': 'aeroway',
            'minzoom': 11,
            'filter': _classes(['runway', 'taxiway']),
            'paint': {'line-color': p.aeroway, 'line-width': _width(1, 30)},
          },
          {
            'id': 'building',
            'type': 'fill',
            'source': 'openmaptiles',
            'source-layer': 'building',
            'minzoom': 14,
            'paint': {
              'fill-color': p.building,
              'fill-outline-color': p.buildingLine,
            },
          },
          ..._road('minor', ['minor', 'service', 'track'], p.minor,
              p.minorCasing, 0, 14,
              minzoom: 12.5),
          ..._road('secondary', ['secondary', 'tertiary'], p.major,
              p.majorCasing, 0.6, 16),
          ..._road(
              'primary', ['primary', 'trunk'], p.major, p.majorCasing, 1, 18),
          ..._road(
              'motorway', ['motorway'], p.motorway, p.motorwayCasing, 1.2, 20),
          {
            'id': 'water_name',
            'type': 'symbol',
            'source': 'openmaptiles',
            'source-layer': 'water_name',
            'layout': {
              'text-field': _name,
              'text-font': ['Noto Sans Italic'],
              'text-size': 12,
              'text-max-width': 6,
            },
            'paint': _halo(p.waterLabel, p),
          },
          {
            'id': 'road_name',
            'type': 'symbol',
            'source': 'openmaptiles',
            'source-layer': 'transportation_name',
            'minzoom': 13,
            'filter': _classes([
              'motorway',
              'trunk',
              'primary',
              'secondary',
              'tertiary',
              'minor',
            ]),
            'layout': {
              'symbol-placement': 'line',
              'text-field': _name,
              'text-font': ['Noto Sans Regular'],
              'text-size': 12,
              'text-rotation-alignment': 'map',
            },
            'paint': _halo(p.roadLabel, p),
          },
          {
            'id': 'place_name',
            'type': 'symbol',
            'source': 'openmaptiles',
            'source-layer': 'place',
            'minzoom': 9,
            'filter': _classes(
                ['suburb', 'quarter', 'neighbourhood', 'village', 'town']),
            'layout': {
              'text-field': _name,
              'text-font': ['Noto Sans Regular'],
              'text-size': [
                'interpolate',
                ['linear'],
                ['zoom'],
                10,
                11,
                15,
                14,
              ],
              'text-max-width': 8,
            },
            'paint': _halo(p.placeLabel, p),
          },
          {
            'id': 'city_name',
            'type': 'symbol',
            'source': 'openmaptiles',
            'source-layer': 'place',
            'maxzoom': 12,
            'filter': [
              '==',
              ['get', 'class'],
              'city'
            ],
            'layout': {
              'text-field': _name,
              'text-font': ['Noto Sans Bold'],
              'text-size': 15,
            },
            'paint': _halo(p.placeLabel, p),
          },
        ],
      });

  static Map<String, Object> _fill(String id, String layer, String colour,
          {List<Object>? filter}) =>
      {
        'id': id,
        'type': 'fill',
        'source': 'openmaptiles',
        'source-layer': layer,
        if (filter != null) 'filter': filter,
        'paint': {'fill-color': colour},
      };

  /// A road [z8] wide at zoom 8 and [z20] at 20, and its casing (drawn
  /// first, a little wider).
  static List<Map<String, Object>> _road(String id, List<String> classes,
      String colour, String casing, double z8, double z20,
      {double? minzoom}) {
    final filter = [
      'all',
      [
        '!=',
        ['get', 'brunnel'],
        'tunnel'
      ],
      _classes(classes),
    ];
    Map<String, Object> line(String suffix, String colour, List<Object> w) => {
          'id': 'road_$id$suffix',
          'type': 'line',
          'source': 'openmaptiles',
          'source-layer': 'transportation',
          if (minzoom != null) 'minzoom': minzoom,
          'filter': filter,
          'layout': {'line-cap': 'round', 'line-join': 'round'},
          'paint': {'line-color': colour, 'line-width': w},
        };
    return [
      line('_casing', casing, _width(z8 + 1, z20 + 3)),
      line('', colour, _width(z8, z20)),
    ];
  }

  static Map<String, Object> _halo(String colour, _Palette p) => {
        'text-color': colour,
        'text-halo-color': p.halo,
        'text-halo-width': 1.2,
      };
}

/// The colours of the style: the app's tokens (Background, Surface, Border,
/// Soft Accent, text colours).
class _Palette {
  const _Palette({
    required this.name,
    required this.land,
    required this.residential,
    required this.park,
    required this.water,
    required this.aeroway,
    required this.building,
    required this.buildingLine,
    required this.minor,
    required this.minorCasing,
    required this.major,
    required this.majorCasing,
    required this.motorway,
    required this.motorwayCasing,
    required this.waterLabel,
    required this.roadLabel,
    required this.placeLabel,
    required this.halo,
  });

  final String name;
  final String land;
  final String residential;
  final String park;
  final String water;
  final String aeroway;
  final String building;
  final String buildingLine;
  final String minor;
  final String minorCasing;
  final String major;
  final String majorCasing;
  final String motorway;
  final String motorwayCasing;
  final String waterLabel;
  final String roadLabel;
  final String placeLabel;
  final String halo;

  static const day = _Palette(
    name: 'day',
    land: '#EEF4F1',
    residential: '#E8EFEB',
    park: '#D5E7DD',
    water: '#B4D1C8',
    aeroway: '#E1E8E4',
    building: '#E2E9E5',
    buildingLine: '#D8DEDA',
    minor: '#FFFFFF',
    minorCasing: '#DCE3DF',
    major: '#FAFBF8',
    majorCasing: '#C8D4CE',
    motorway: '#F4EBDA',
    motorwayCasing: '#D8CBB2',
    waterLabel: '#3F7A7B',
    roadLabel: '#6F7467',
    placeLabel: '#4A5046',
    halo: '#FAFBF8',
  );
}
