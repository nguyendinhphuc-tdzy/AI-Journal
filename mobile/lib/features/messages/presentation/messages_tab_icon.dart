import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../messages_scope.dart';

/// The "Tin nhắn" tab's icon, with the unread count when there is one.
class MessagesTabIcon extends StatelessWidget {
  const MessagesTabIcon({super.key, this.selected = false});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final unread = MessagesScope.maybeOf(context)?.unread ?? 0;
    final icon = Icon(selected
        ? Icons.chat_bubble_rounded
        : Icons.chat_bubble_outline_rounded);
    return unread == 0
        ? icon
        : Badge(
            label: Text(unread > 99 ? '99+' : '$unread'),
            backgroundColor: AppColors.primaryAction,
            child: icon,
          );
  }
}
