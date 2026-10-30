import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/presentation/auth_gate.dart';
import 'real_friends_screen.dart';

abstract final class FriendSpaceText {
  static const title = 'Bạn bè AI-Journal';
  static const needsAccountTitle = 'Kết bạn cần tài khoản';
  static const needsAccountBody =
      'Bạn bè trên app tìm nhau bằng username và chỉ bạn bè mới thấy bài chia '
      'sẻ 24 giờ của bạn. Đăng nhập tài khoản để kết bạn: ở chế độ khách, vào '
      'Hồ sơ, chọn Đăng xuất rồi đăng nhập.';
}

/// Friends on the app, over Explore: the account's real friendships
/// (search by @username, requests, accept). Without an account (guest or
/// the local demo) there are none, and the screen says how to get them.
Future<void> openFriendSpace(BuildContext context) {
  final auth = AuthScope.maybeOf(context);
  return Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => auth is SupabaseAuthService
        ? RealFriendsScreen(auth: auth)
        : const FriendsNeedAccountScreen(),
  ));
}

/// No account, no friends on the app: no sample friends either.
class FriendsNeedAccountScreen extends StatelessWidget {
  const FriendsNeedAccountScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text(FriendSpaceText.title)),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: const [
            Icon(Icons.group_outlined, size: 48, color: AppColors.textSecondary),
            SizedBox(height: AppSpacing.md),
            Text(FriendSpaceText.needsAccountTitle,
                textAlign: TextAlign.center, style: AppText.sectionTitle),
            SizedBox(height: AppSpacing.sm),
            Text(FriendSpaceText.needsAccountBody,
                textAlign: TextAlign.center, style: AppText.bodySecondary),
          ],
        ),
      );
}
