import 'package:flutter/material.dart';

import 'app_destinations.dart';

/// The app shell's bottom bar on screens pushed above the shell (J01, the
/// streak): same tabs, icons and style ([appDestinations]); choosing a tab
/// is up to the screen.
class CustomBottomNavigation extends StatelessWidget {
  const CustomBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) => NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: appDestinations,
      );
}
