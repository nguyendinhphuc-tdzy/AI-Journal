import 'package:flutter/material.dart';

import '../features/album/presentation/album_screen.dart';
import '../features/explore/presentation/explore_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/study/presentation/study_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _screens = [
    HomeScreen(),
    StudyScreen(),
    AlbumScreen(),
    ExploreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: [
            for (var index = 0; index < _screens.length; index++)
              TickerMode(enabled: index == _index, child: _screens[index]),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.school_outlined), label: 'Study'),
          NavigationDestination(icon: Icon(Icons.photo_album_outlined), label: 'Album'),
          NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Explore'),
        ],
      ),
    );
  }
}
