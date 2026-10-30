import 'package:ai_diary/features/explore/presentation/widgets/map_marker_art.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Pins on the same spot are set side by side; lone pins stay', () {
    final spread = spreadSameSpot({
      'mine:a': (lat: 10.78000, lon: 106.69000),
      'friend:b': (lat: 10.78001, lon: 106.69002),
      'friend:c': (lat: 10.80000, lon: 106.70000),
    }, gap: 40);
    expect(spread['mine:a'], -20);
    expect(spread['friend:b'], 20);
    expect(spread['friend:c'], 0);
  });

  test('Three on one spot: centred around it', () {
    final spread = spreadSameSpot({
      'a': (lat: 1.0, lon: 2.0),
      'b': (lat: 1.0, lon: 2.0),
      'c': (lat: 1.0, lon: 2.0),
    }, gap: 40);
    expect([spread['a'], spread['b'], spread['c']], [-40, 0, 40]);
  });
}
