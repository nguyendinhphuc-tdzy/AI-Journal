import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'navigation/app_shell.dart';

void main() {
  runApp(const AiDiaryApp());
}

class AiDiaryApp extends StatelessWidget {
  const AiDiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Diary',
      theme: AppTheme.light,
      home: const AppShell(),
    );
  }
}
