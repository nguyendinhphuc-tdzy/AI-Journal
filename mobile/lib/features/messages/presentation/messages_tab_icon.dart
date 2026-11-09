import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../messages_scope.dart';

/// The "Tin nhắn" tab's icon, with the unread count when there is one. A
/// new count pops in (none with reduced motion).
class MessagesTabIcon extends StatelessWidget {
  const MessagesTabIcon({super.key, this.selected = false});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final unread = MessagesScope.maybeOf(context)?.unread ?? 0;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final icon = Icon(selected
        ? Icons.chat_bubble_rounded
        : Icons.chat_bubble_outline_rounded);
    if (unread == 0) return icon;
    final label = Text(unread > 99 ? '99+' : '$unread',
        key: ValueKey(unread),
        style: const TextStyle(fontWeight: FontWeight.w700));
    return Badge(
      backgroundColor: AppColors.primaryAction,
      textColor: AppColors.surface,
      label: reduced
          ? label
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutBack,
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: label,
            ),
      child: icon,
    );
  }
}
