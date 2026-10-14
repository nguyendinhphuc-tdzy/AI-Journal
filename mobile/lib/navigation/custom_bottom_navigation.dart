import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class CustomBottomNavigation extends StatelessWidget {
  const CustomBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  static const _tabs = [
    (label: 'Home', icon: Icons.home_outlined),
    (label: 'Study', icon: Icons.school_outlined),
    (label: 'Album', icon: Icons.photo_album_outlined),
    (label: 'Explore', icon: Icons.explore_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
              children: List.generate(_tabs.length, (index) {
            final tab = _tabs[index];
            final selected = selectedIndex == index;
            final color =
                selected ? AppColors.primaryDark : AppColors.textSecondary;
            return Expanded(
              child: Semantics(
                selected: selected,
                button: true,
                label: tab.label,
                excludeSemantics: true,
                child: InkWell(
                  onTap: () => onDestinationSelected(index),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(tab.icon, color: color),
                      const SizedBox(height: 6),
                      Text(tab.label,
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: color,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  )),
                    ]),
                  ),
                ),
              ),
            );
          })),
        ),
      ),
    );
  }
}
