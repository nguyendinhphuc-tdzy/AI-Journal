import 'package:flutter/material.dart';

import '../features/album/data/memory_share.dart';
import '../features/album/presentation/album_screen.dart';
import '../features/album/presentation/share_memory_sheet.dart';
import '../features/explore/data/explore_highlight.dart';
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

  /// The post just shared from Album (A10), pointed out on the map.
  SharedMemoryPost? _post;
  ExploreHighlight? _shared;

  List<Widget> get _screens => [
        const HomeScreen(),
        const StudyScreen(),
        AlbumScreen(onShare: _shareToExplore, onUnshare: _unshare),
        ExploreScreen(highlight: _shared),
      ];

  /// A10 → E01: Explore with the new pin and its card open.
  void _shareToExplore(SharedMemoryPost post) {
    final payload = post.payload;
    final where =
        '${payload.place.label} · ${ShareMemorySheet.expiresLabel(post.expiresAt)}';
    setState(() {
      _index = 3;
      _post = post;
      _shared = ExploreHighlight(
        id: post.id,
        title: payload.title ?? payload.place.label,
        subtitle: payload.text == null ? where : '${payload.text}\n$where',
        latitude: payload.place.latitude,
        longitude: payload.place.longitude,
        expiresAt: post.expiresAt,
      );
    });
  }

  /// A11/A12 took the post off the map: E01 no longer points it out.
  void _unshare(ShareRemoval removal) {
    final post = _post;
    if (post == null || !removal.matches(post)) return;
    setState(() {
      _post = null;
      _shared = null;
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
              icon: Icon(Icons.menu_book_outlined), label: 'Trang chủ'),
          NavigationDestination(
              icon: Icon(Icons.school_outlined), label: 'Học tập'),
          NavigationDestination(
              icon: Icon(Icons.photo_album_outlined), label: 'Kỷ niệm'),
          NavigationDestination(
              icon: Icon(Icons.map_outlined), label: 'Khám phá'),
        ],
      ),
    );
  }
}
