import 'package:flutter/material.dart';

import '../features/album/presentation/album_screen.dart';
import '../features/explore/presentation/explore_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/study/presentation/study_screen.dart';
import 'custom_bottom_navigation.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialIndex = 0})
      : assert(initialIndex >= 0 && initialIndex < 4);

  final int initialIndex;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _index = widget.initialIndex;

  static const _screens = [
    HomeScreen(),
    StudyScreen(),
    AlbumScreen(),
    ExploreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: CustomBottomNavigation(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
      ),
    );
  }
}
