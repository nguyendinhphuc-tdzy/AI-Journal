import 'package:flutter/painting.dart';

import 'app_colors.dart';

/// The app's type scale, shared by every tab (it began as Study's): Nunito
/// for page, section and card titles, Be Vietnam Pro for everything read or
/// tapped. Use these instead of per-screen sizes so titles, body text and
/// buttons read the same everywhere.
abstract final class AppText {
  /// The one big title at the top of a tab or screen.
  static const pageTitle = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.25,
    color: AppColors.textPrimary,
  );

  /// A section inside a page ("Tuần này", "Khám phá cách viết").
  static const sectionTitle = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  /// The title of a card.
  static const cardTitle = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.35,
    color: AppColors.textPrimary,
  );

  static const body = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 16,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  static const bodySecondary = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 16,
    height: 1.5,
    color: AppColors.textSecondary,
  );

  /// Small supporting text: eyebrows, dates, counts, hints.
  static const meta = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 14,
    height: 20 / 14,
    color: AppColors.textSecondary,
  );

  /// Buttons, chips and emphasized short labels.
  static const label = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.5,
    color: AppColors.textPrimary,
  );
}
