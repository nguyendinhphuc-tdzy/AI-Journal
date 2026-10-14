import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Local typography keeps the Study refresh independent of the other tabs.
class StudyTheme extends StatelessWidget {
  const StudyTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    const body = TextStyle(
      fontFamily: 'BeVietnamPro',
      fontSize: 16,
      height: 1.5,
      color: AppColors.textPrimary,
    );
    const heading = TextStyle(
      fontFamily: 'Nunito',
      fontWeight: FontWeight.w600,
      height: 1.25,
      color: AppColors.textPrimary,
    );
    final text = base.textTheme.copyWith(
      headlineMedium: heading.copyWith(fontSize: 28),
      headlineSmall: heading.copyWith(fontSize: 24),
      titleLarge: heading.copyWith(fontSize: 22),
      titleMedium: heading.copyWith(fontSize: 20),
      titleSmall: body.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      bodyLarge: body,
      bodyMedium: body,
      bodySmall: body.copyWith(fontSize: 14, height: 20 / 14),
      labelLarge: body.copyWith(fontWeight: FontWeight.w600),
      labelMedium: body.copyWith(fontSize: 14, height: 20 / 14),
      labelSmall: body.copyWith(fontSize: 12, height: 16 / 12),
    );
    final button = OutlinedButton.styleFrom(
      foregroundColor: AppColors.textPrimary,
      minimumSize: const Size(0, 56),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      textStyle: text.labelLarge,
      side: const BorderSide(color: AppColors.primary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    );
    return Theme(
      data: base.copyWith(
        textTheme: text,
        appBarTheme: base.appBarTheme.copyWith(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: text.titleLarge,
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(style: button),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            minimumSize: const Size(48, 48),
            textStyle: text.labelLarge,
          ),
        ),
      ),
      child: child,
    );
  }
}
