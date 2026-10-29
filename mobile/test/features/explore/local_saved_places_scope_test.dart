import 'package:ai_diary/features/explore/data/saved_places.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('saved place keys never cross signed-in account boundaries', () async {
    SharedPreferences.setMockInitialValues({});
    const a = LocalSavedPlacesStore(userId: 'account-a');
    const b = LocalSavedPlacesStore(userId: 'account-b');
    const demo = LocalSavedPlacesStore();
    const pin = SavedPlace(
      id: 'saved:100', name: 'Only A', category: 'Study', note: '',
      latitude: 10.7, longitude: 106.7,
    );
    await a.keepPlaces([pin]);
    expect((await a.places())!.single.name, 'Only A');
    expect(await b.places(), isNull);
    expect(await demo.places(), isNull);
    await b.keepPlaces([]);
    expect(await a.places(), hasLength(1));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('users.account-a.explore.savedPlaces'), isTrue);
    expect(prefs.containsKey('users.account-b.explore.savedPlaces'), isTrue);
    expect(prefs.containsKey('explore.savedPlaces'), isFalse);
  });
}
