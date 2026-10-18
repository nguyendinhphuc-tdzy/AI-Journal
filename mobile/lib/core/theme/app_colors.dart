import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const primary = Color(0xFF5C9697);
  static const primaryDark = Color(0xFF3F8996);

  /// Fill for primary buttons with a light label: 5.1:1 against [surface]
  /// (WCAG AA). [primary] and [primaryDark] fall short of 4.5:1 there.
  static const primaryAction = Color(0xFF2E6E78);
  static const primaryLight = Color(0xFFDCEBE7);
  static const background = Color(0xFFEEF4F1);
  static const surface = Color(0xFFFAFBF8);
  static const textPrimary = Color(0xFF1F201C);
  static const textSecondary = Color(0xFF6F7467);
  static const warmAccent = Color(0xFF796F5B);
  static const positive = Color(0xFF566F46);
  static const border = Color(0xFFD8DEDA);
  static const softAccent = Color(0xFFA9C8BE);
}
