import 'dart:convert';

import 'package:ai_diary/core/network/api_client.dart';
import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/explore/data/place_lookup.dart';
import 'package:ai_diary/features/explore/data/remote_saved_places_repository.dart';
import 'package:ai_diary/features/explore/presentation/explore_screen.dart';
import 'package:ai_diary/features/explore/presentation/place_picker_screen.dart';
import 'package:ai_diary/features/explore/presentation/widgets/place_pick_overlay.dart';
import 'package:ai_diary/features/explore/presentation/widgets/place_sheets.dart';
import 'package:ai_diary/features/onboarding/data/onboarding_scope.dart';
import 'package:ai_diary/features/onboarding/data/onboarding_store.dart';
import 'package:ai_diary/features/profile/profile_screen.dart';
import 'package:ai_diary/features/study/data/study_progress.dart';
import 'package:ai_diary/features/study/presentation/study_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The session (AuthGate) provides each user's own stores through scopes.
// These screens must read them: a merge that drops a read breaks here.

class _Progress extends InMemoryStudyProgressStore {
  var loads = 0;

  @override
  Future<StudyProgress?> load() {
    loads++;
    return super.load();
  }
}

class _Lookup implements PlaceLookup {
  final queries = <String>[];

  @override
  Future<List<PlaceCandidate>> search(String query) async {
    queries.add(query);
    return const [];
  }

  @override
  Future<PlaceCandidate?> nameAt(double latitude, double longitude) async =>
      null;
}

http.Response _reply(Object value, [int status = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode(value)),
      status,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Study keeps progress in the session user\'s store',
      (tester) async {
    final progress = _Progress();
    await tester.pumpWidget(StudyProgressScope(
      repository: progress,
      child: MaterialApp(theme: AppTheme.light, home: const StudyScreen()),
    ));
    await tester.pumpAndSettle();
    expect(progress.loads, 1);
  });

  testWidgets('Hồ sơ shows the session user\'s nickname, not the device\'s',
      (tester) async {
    await (await OnboardingStore.open()).saveNickname('Máy chung');
    final mine = await OnboardingStore.open(userId: 'user-1');
    await mine.saveNickname('Vy');
    await tester.pumpWidget(OnboardingScope(
      store: mine,
      child: MaterialApp(theme: AppTheme.light, home: const ProfileScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Vy'), findsWidgets);
    expect(find.text('Máy chung'), findsNothing);
  });

  testWidgets('Place search uses the session\'s real lookup', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final real = _Lookup();
    final fallback = _Lookup();
    await tester.pumpWidget(PlaceLookupScope(
      lookup: real,
      child: MaterialApp(
        theme: AppTheme.light,
        home: PlacePickerScreen(lookup: fallback),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, PlacePickerScreen.searchHint), 'cafe');
    await tester.pump(PlacePickerScreen.debounce);
    await tester.pumpAndSettle();
    expect(real.queries, ['cafe']);
    expect(fallback.queries, isEmpty);
  });

  group('Explore with account places', () {
    late List<http.Request> requests;
    late RemoteSavedPlacesRepository cloud;

    setUp(() {
      requests = [];
      var nextId = 7;
      cloud = RemoteSavedPlacesRepository(ApiClient(
        accessTokenProvider: () async => 'jwt',
        client: MockClient((request) async {
          requests.add(request);
          final path = request.url.path;
          if (request.method == 'POST' && path.endsWith('/places')) {
            return _reply({
              'id': ++nextId,
              'label': 'Quán mới',
              'latitude': 10.81,
              'longitude': 106.71,
            }, 201);
          }
          if (request.method == 'POST' && path.endsWith('/notes')) {
            return _reply({'id': 1, 'content': 'x'}, 201);
          }
          if (path.endsWith('/notes')) {
            return _reply({'items': [], 'next_cursor': null});
          }
          return _reply({
            'items': [
              {
                'id': 7,
                'label': 'Quán của tài khoản',
                'latitude': 10.77,
                'longitude': 106.69,
              }
            ],
            'next_cursor': null,
          });
        }),
      ));
    });

    Future<void> search(WidgetTester tester, String query) async {
      await tester.enterText(find.byType(TextField).first, query);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
    }

    testWidgets('Shows the account\'s places, never the samples',
        (tester) async {
      final device = InMemorySavedPlacesStore();
      await tester.pumpWidget(SavedPlacesScope(
        repository: cloud,
        child: MaterialApp(home: ExploreScreen(savedPlacesStore: device)),
      ));
      await tester.pumpAndSettle();
      expect(requests.where((r) => r.url.path.endsWith('/places')),
          isNotEmpty);
      await search(tester, 'tai khoan');
      expect(find.text('Quán của tài khoản'), findsOneWidget);
      await search(tester, 'ven song');
      expect(find.text('Góc đọc sách ven sông'), findsNothing);
    });

    testWidgets('A new place goes to the account, not the device',
        (tester) async {
      final device = InMemorySavedPlacesStore();
      await tester.pumpWidget(SavedPlacesScope(
        repository: cloud,
        child: MaterialApp(home: ExploreScreen(savedPlacesStore: device)),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(ExploreScreen.saveLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(PlacePickText.confirm));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), 'Quán mới');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      final save = find.text(PlaceSheetText.saveLabel);
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(
          requests.where(
              (r) => r.method == 'POST' && r.url.path.endsWith('/places')),
          hasLength(1));
      expect(find.text(ExploreScreen.cloudSaved), findsOneWidget);
      expect(device.kept, isNull, reason: 'account places stay off the device');
    });
  });
}
