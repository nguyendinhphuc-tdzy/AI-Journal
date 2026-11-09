import 'dart:convert';

import 'package:ai_diary/features/auth/presentation/auth_gate.dart';
import 'package:ai_diary/features/explore/data/saved_places.dart';
import 'package:ai_diary/features/explore/presentation/explore_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _places(String name) => jsonEncode([
      SavedPlace(
        id: 'saved:$name',
        name: name,
        category: 'Ăn uống',
        note: '',
        latitude: 10.8,
        longitude: 106.7,
      ).toJson(),
    ]);

void main() {
  testWidgets(
      'A guest\'s Explore reads the guest\'s own pins, never the old '
      'shared key left by a past guest', (tester) async {
    SharedPreferences.setMockInitialValues({
      'explore.savedPlaces': _places('Ghim khách cũ'),
      'users.local-guest.explore.savedPlaces': _places('Ghim của khách này'),
    });
    await tester.pumpWidget(GuestScope(
      onLeaveGuest: () async {},
      child: const MaterialApp(home: ExploreScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Ghim của khách này', skipOffstage: false), findsWidgets);
    expect(find.text('Ghim khách cũ', skipOffstage: false), findsNothing);
  });
}
