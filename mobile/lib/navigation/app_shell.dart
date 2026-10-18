import 'package:flutter/material.dart';

import '../features/album/presentation/album_screen.dart';
import '../features/explore/presentation/explore_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/study/presentation/study_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialIndex = 0})
      : assert(initialIndex >= 0 && initialIndex < 4);

  final int initialIndex;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _index = widget.initialIndex;

  late final _screens = [
    const HomeScreen(),
    const StudyScreen(),
    AlbumScreen(onShare: _shareToExplore),
    const ExploreScreen(),
  ];

  void _shareToExplore() {
    setState(() => _index = 3);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showShareDialog(context);
    });
  }

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
          NavigationDestination(
              icon: Icon(Icons.menu_book_outlined), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.school_outlined), label: 'Study'),
          NavigationDestination(
              icon: Icon(Icons.photo_album_outlined), label: 'Album'),
          NavigationDestination(
              icon: Icon(Icons.map_outlined), label: 'Explore'),
        ],
      ),
    );
  }
}
