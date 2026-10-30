import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_text.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData(useMaterial3: true, fontFamily: 'BeVietnamPro');
    final textTheme = base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(surface: AppColors.surface);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: scheme,
      textTheme: textTheme.copyWith(
        displayLarge: textTheme.displayLarge?.copyWith(fontFamily: 'Nunito'),
        displayMedium: textTheme.displayMedium?.copyWith(fontFamily: 'Nunito'),
        displaySmall: textTheme.displaySmall?.copyWith(fontFamily: 'Nunito'),
        headlineLarge: textTheme.headlineLarge?.copyWith(fontFamily: 'Nunito'),
        headlineMedium:
            textTheme.headlineMedium?.copyWith(fontFamily: 'Nunito'),
        headlineSmall: textTheme.headlineSmall?.copyWith(fontFamily: 'Nunito'),
        titleLarge: textTheme.titleLarge?.copyWith(fontFamily: 'Nunito'),
        titleMedium: textTheme.titleMedium?.copyWith(fontFamily: 'Nunito'),
        titleSmall: textTheme.titleSmall?.copyWith(fontFamily: 'Nunito'),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodyMedium,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primaryLight,
        height: 76,
      ),
      // Every snack bar in the app: a Surface card floating above the
      // navigation and above a screen's bottom button (56 + its 24 margin),
      // so it never covers the action; the action on the same line in the
      // action colour. Snack bars with an action pass `persist: false` so
      // they still leave (4 s by default).
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surface,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          side: const BorderSide(color: AppColors.border),
        ),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        contentTextStyle: AppText.body,
        actionTextColor: AppColors.primaryAction,
        actionOverflowThreshold: .5,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryAction,
          foregroundColor: AppColors.surface,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
      ),
    );
  }
}

/// How every list scrolls in the app: it stops at its ends, without the
/// stretch (Android 12+) or bounce (iOS) when pulled past them, so pages
/// never look like they are being pulled out of shape.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();
}
