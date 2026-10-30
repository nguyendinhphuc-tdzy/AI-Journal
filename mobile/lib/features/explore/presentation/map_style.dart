import 'dart:convert';

/// Explore's own map styles, in the app's palette, on OpenFreeMap's tiles
/// and fonts (the same sources as its "liberty" style).
///
/// OSM features: land, water, roads, rail, boundaries, buildings and named
/// amenities (cafe, shop, hospital, school, transport, attractions).
/// Labels honor MapLibre collision rules so Nudaeng pins remain visible.
/// One light style for every map in the app (Explore, the place picker) at
/// any hour: ivory land, light green parks, light blue water, major roads
/// clearly above minor ones, names dark enough to read; no texture over
/// the map. A darker night style was dropped on 28/10/2026: it was hard to
/// read.
abstract final class ExploreMapStyle {
  static final day = _style(_Palette.day);

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
              p.majorCasing, 0.8, 18),
          ..._road('primary', ['primary', 'trunk'], p.primary, p.primaryCasing,
              1.4, 22),
          ..._road(
              'motorway', ['motorway'], p.motorway, p.motorwayCasing, 1.6, 24),
          // Secondary network and transit routes were missing from the MVP.
          {
            'id': 'railway',
            'type': 'line',
            'source': 'openmaptiles',
            'source-layer': 'transportation',
            'minzoom': 12,
            'filter': _classes(['rail', 'transit']),
            'paint': {
              'line-color': '#9E938C',
              'line-width': _width(.4, 2.3),
              'line-opacity': .75,
            },
          },
          {
            'id': 'footways',
            'type': 'line',
            'source': 'openmaptiles',
            'source-layer': 'transportation',
            'minzoom': 15,
            'filter': _classes(['path', 'pedestrian', 'footway']),
            'paint': {
              'line-color': '#C8B9A9',
              'line-width': _width(.2, 1.8),
              'line-dasharray': [2, 2],
            },
          },
          {
            'id': 'administrative_boundaries',
            'type': 'line',
            'source': 'openmaptiles',
            'source-layer': 'boundary',
            'maxzoom': 13,
            'paint': {
              'line-color': '#B6AEA4',
              'line-width': .7,
              'line-opacity': .6,
              'line-dasharray': [3, 2],
            },
          },
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
              'text-size': 12.5,
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
          // Names come from OpenStreetMap's real poi layer (not demo pins).
          // Important amenities appear first; all named POIs appear at z17+.
          {
            'id': 'poi_highlight_dots',
            'type': 'circle',
            'source': 'openmaptiles',
            'source-layer': 'poi',
            'minzoom': 14,
            'filter': [
              'all',
              ['has', 'name'],
              _classes(['cafe', 'restaurant', 'fast_food', 'shop', 'grocery',
                'hospital', 'school', 'college', 'attraction', 'library',
                'bus', 'railway', 'lodging', 'park', 'fuel', 'pharmacy']),
            ],
            'paint': {
              'circle-color': '#477887',
              'circle-radius': 2.8,
              'circle-stroke-width': 1,
              'circle-stroke-color': '#FFFFFF',
              'circle-opacity': .82,
            },
          },
          {
            'id': 'poi_priority_labels',
            'type': 'symbol',
            'source': 'openmaptiles',
            'source-layer': 'poi',
            'minzoom': 14,
            'filter': [
              'all', ['has', 'name'],
              _classes(['cafe', 'restaurant', 'fast_food', 'shop', 'grocery',
                'hospital', 'school', 'college', 'attraction', 'library',
                'bus', 'railway', 'lodging', 'park', 'fuel', 'pharmacy']),
              ['<=', ['coalesce', ['get', 'rank'], 30], 14],
            ],
            'layout': {
              'text-field': _name,
              'text-font': ['Noto Sans Regular'],
              'text-size': 11.5,
              'text-anchor': 'top',
              'text-offset': [0, .6],
              'text-max-width': 9,
              'text-optional': true,
            },
            'paint': _halo('#53645B', p),
          },
          {
            'id': 'poi_other_labels',
            'type': 'symbol',
            'source': 'openmaptiles',
            'source-layer': 'poi',
            'minzoom': 17,
            'filter': ['has', 'name'],
            'layout': {
              'text-field': _name,
              'text-font': ['Noto Sans Regular'],
              'text-size': 11,
              'text-max-width': 8,
              'text-optional': true,
            },
            'paint': _halo('#5B665F', p),
          },
          {
            'id': 'house_numbers',
            'type': 'symbol',
            'source': 'openmaptiles',
            'source-layer': 'housenumber',
            'minzoom': 18,
            'layout': {
              'text-field': ['get', 'housenumber'],
              'text-font': ['Noto Sans Regular'],
              'text-size': 9.5,
            },
            'paint': _halo('#9C8B7C', p),
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
        'text-halo-width': 1.4,
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
    required this.primary,
    required this.primaryCasing,
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
  final String primary;
  final String primaryCasing;
  final String motorway;
  final String motorwayCasing;
  final String waterLabel;
  final String roadLabel;
  final String placeLabel;
  final String halo;

  static const day = _Palette(
    name: 'day',
    land: '#F7F4EC',
    residential: '#F2EEE4',
    park: '#D3E8CF',
    water: '#BCD9E8',
    aeroway: '#ECE8DF',
    building: '#ECE6DA',
    buildingLine: '#DED6C7',
    minor: '#FFFFFF',
    minorCasing: '#E4DED2',
    major: '#FFFFFF',
    majorCasing: '#CFC6B5',
    primary: '#FFF7E6',
    primaryCasing: '#D8C49C',
    motorway: '#F8E4B8',
    motorwayCasing: '#CFB27A',
    waterLabel: '#3A6C8C',
    roadLabel: '#4D5248',
    placeLabel: '#2E332D',
    halo: '#FFFFFF',
  );
}
