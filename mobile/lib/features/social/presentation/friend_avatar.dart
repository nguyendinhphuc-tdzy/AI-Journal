import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../data/app_friend.dart';

/// A friend's initials on a soft circle, the same colour for them each time.
class FriendAvatar extends StatelessWidget {
  const FriendAvatar(this.friend, {super.key, this.size = 44});

  final AppFriend friend;
  final double size;

  static const _tints = [
    Color(0xFFDCEBE7),
    Color(0xFFF1E4CE),
    Color(0xFFECDDE4),
    Color(0xFFE4E5F1),
    Color(0xFFDDE5D1),
  ];

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _tints[friend.id.hashCode.abs() % _tints.length],
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.surface, width: 2),
        ),
        alignment: Alignment.center,
        child: Text(friend.initials,
            style: AppText.label.copyWith(
                fontSize: size * .32, color: AppColors.textPrimary)),
      );
}
