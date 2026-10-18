import 'dart:math' as math;

import 'package:ai_diary/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + .05) / (math.min(la, lb) + .05);
}

void main() {
  test('Primary button label reaches WCAG AA (4.5:1)', () {
    expect(_contrast(AppColors.primaryAction, AppColors.surface),
        greaterThanOrEqualTo(4.5));
  });

  test('Outlined button border reaches 3:1 on the background', () {
    expect(_contrast(AppColors.primaryAction, AppColors.background),
        greaterThanOrEqualTo(3));
  });
}
