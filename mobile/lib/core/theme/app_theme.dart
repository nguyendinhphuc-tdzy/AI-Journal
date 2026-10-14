import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData(useMaterial3: true, fontFamily: 'Be Vietnam Pro');
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
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
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
