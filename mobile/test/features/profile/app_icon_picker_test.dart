import 'dart:io';

import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/onboarding/data/onboarding_scope.dart';
import 'package:ai_diary/features/onboarding/data/onboarding_store.dart';
import 'package:ai_diary/features/profile/data/app_icon.dart';
import 'package:ai_diary/features/profile/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Android's launcher, as Hồ sơ sees it.
class _Launcher implements AppIconSwitcher {
  _Launcher({this.icon = AppIcon.standard, this.supported = true});

  AppIcon icon;
  @override
  final bool supported;
  bool fail = false;
  final sets = <AppIcon>[];

  @override
  Future<AppIcon> current() async => icon;

  @override
  Future<void> set(AppIcon next) async {
    sets.add(next);
    if (fail) throw Exception('launcher said no');
    icon = next;
  }
}

Finder _tile(AppIcon icon) => find.byKey(ValueKey('app-icon-${icon.id}'));

Future<void> _pump(WidgetTester tester, _Launcher launcher) async {
  SharedPreferences.setMockInitialValues({});
  final store = await OnboardingStore.open(userId: 'u1');
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(412, 915);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(OnboardingScope(
    store: store,
    child: MaterialApp(
        theme: AppTheme.light, home: ProfileScreen(appIcons: launcher)),
  ));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(_tile(AppIcon.repair), 200,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

/// Taps [icon]; on a phone that can change it, answers the sheet that says
/// the app will close ([confirm], else Hủy).
Future<void> _pick(WidgetTester tester, AppIcon icon,
    {bool confirm = true}) async {
  await tester.ensureVisible(_tile(icon));
  await tester.pumpAndSettle();
  await tester.tap(_tile(icon));
  await tester.pumpAndSettle();
  final sheet = find.text(ProfileScreen.iconConfirmTitle(icon));
  if (sheet.evaluate().isEmpty) return;
  expect(find.text(ProfileScreen.iconConfirmBody), findsOneWidget);
  await tester.tap(
      find.text(confirm ? ProfileScreen.iconConfirmLabel : 'Hủy'));
  await tester.pumpAndSettle();
}

bool _selected(WidgetTester tester, AppIcon icon) =>
    tester
        .widget<Semantics>(find.byWidgetPredicate((widget) =>
            widget is Semantics && widget.properties.label == icon.label))
        .properties
        .selected ==
    true;

void main() {
  testWidgets('Shows the icon on the home screen now, among all eight',
      (tester) async {
    await _pump(tester, _Launcher(icon: AppIcon.nurse));
    expect(find.text(ProfileScreen.iconNote), findsOneWidget);
    for (final icon in AppIcon.values) {
      expect(_tile(icon), findsOneWidget, reason: icon.id);
      expect(find.text(icon.label), findsOneWidget, reason: icon.id);
    }
    expect(_selected(tester, AppIcon.nurse), isTrue);
    expect(_selected(tester, AppIcon.standard), isFalse);
  });

  testWidgets('A tap puts it on the home screen and says so', (tester) async {
    final launcher = _Launcher();
    await _pump(tester, launcher);
    await _pick(tester, AppIcon.restaurant);
    expect(launcher.sets, [AppIcon.restaurant]);
    expect(find.text(ProfileScreen.iconChanged(AppIcon.restaurant)),
        findsOneWidget);
    expect(_selected(tester, AppIcon.restaurant), isTrue);

    // The same again changes nothing.
    await _pick(tester, AppIcon.restaurant);
    expect(launcher.sets, hasLength(1));
  });

  testWidgets('Says first that the app will close; Hủy changes nothing',
      (tester) async {
    final launcher = _Launcher();
    await _pump(tester, launcher);
    await _pick(tester, AppIcon.security, confirm: false);
    expect(launcher.sets, isEmpty);
    expect(_selected(tester, AppIcon.standard), isTrue);
    expect(_selected(tester, AppIcon.security), isFalse);
  });

  testWidgets('When the launcher refuses, the old icon stays chosen',
      (tester) async {
    final launcher = _Launcher(icon: AppIcon.office)..fail = true;
    await _pump(tester, launcher);
    await _pick(tester, AppIcon.student);
    expect(launcher.sets, [AppIcon.student]);
    expect(find.text(ProfileScreen.iconFailed), findsOneWidget);
    expect(_selected(tester, AppIcon.office), isTrue);
    expect(_selected(tester, AppIcon.student), isFalse);
  });

  testWidgets('A phone that cannot change it only previews, and says so',
      (tester) async {
    final launcher = _Launcher(supported: false);
    await _pump(tester, launcher);
    expect(find.text(ProfileScreen.iconPreviewOnly), findsOneWidget);
    await _pick(tester, AppIcon.guide);
    expect(find.text(ProfileScreen.iconConfirmTitle(AppIcon.guide)),
        findsNothing, reason: 'nothing closes on a preview');
    expect(launcher.sets, isEmpty);
    expect(_selected(tester, AppIcon.guide), isTrue);
  });

  group('Android launcher aliases (AndroidManifest.xml)', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final activity = RegExp(r'<activity\s[\s\S]*?</activity>')
        .firstMatch(manifest)!
        .group(0)!;
    final aliases = {
      for (final m in RegExp(r'<activity-alias\s[\s\S]*?</activity-alias>')
          .allMatches(manifest))
        RegExp(r'android:name="\.Launcher_(\w+)"')
            .firstMatch(m.group(0)!)!
            .group(1)!: m.group(0)!,
    };

    test('The sign-in deep link stays on MainActivity, not on an alias', () {
      // Google sign-in and the confirmation email come back through it.
      expect(activity, contains('android:name=".MainActivity"'));
      expect(activity,
          contains('android:scheme="aijournal" android:host="auth-callback"'));
      expect(activity, isNot(contains('android.intent.category.LAUNCHER')));
      for (final alias in aliases.values) {
        expect(alias, isNot(contains('aijournal')));
        expect(alias, contains('android:targetActivity=".MainActivity"'));
        expect(alias, contains('android.intent.category.LAUNCHER'));
      }
    });

    test('One alias per icon; only the default is on at install', () {
      expect(aliases.keys.toSet(), {for (final i in AppIcon.values) i.id});
      for (final MapEntry(key: id, value: alias) in aliases.entries) {
        expect(alias, contains('android:enabled="${id == 'default'}"'),
            reason: id);
      }
      final kotlin = File(
              'android/app/src/main/kotlin/com/example/ai_diary/MainActivity.kt')
          .readAsStringSync();
      for (final icon in AppIcon.values) {
        expect(kotlin, contains('"${icon.id}"'), reason: icon.id);
      }
    });

    test('Every icon has its launcher art and picker picture', () {
      const res = 'android/app/src/main/res';
      for (final icon in AppIcon.values) {
        expect(File('assets/images/app-icon-${icon.id}.png').existsSync(),
            isTrue, reason: icon.asset);
        if (icon == AppIcon.standard) continue;
        expect(aliases[icon.id],
            contains('android:icon="@mipmap/ic_launcher_${icon.id}"'));
        expect(File('$res/mipmap-anydpi-v26/ic_launcher_${icon.id}.xml')
            .existsSync(), isTrue);
        for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
          for (final file in [
            'ic_launcher_${icon.id}.png',
            'ic_launcher_${icon.id}_foreground.png',
          ]) {
            expect(File('$res/mipmap-$density/$file').existsSync(), isTrue,
                reason: '$density/$file');
          }
        }
      }
    });

    test('No brand name in an icon name or label', () {
      for (final icon in AppIcon.values) {
        expect('${icon.id} ${icon.label}'.toLowerCase(),
            isNot(contains('haidilao')));
      }
      expect(manifest.toLowerCase(), isNot(contains('haidilao')));
    });
  });
}
