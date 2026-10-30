import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/app_ui.dart';
import '../../social/data/app_friend.dart';
import '../../social/presentation/friend_avatar.dart';
import '../data/chat_message.dart';
import '../data/messages_repository.dart';

abstract final class SendPlaceText {
  static String title(String place) => 'Gửi "$place" cho bạn bè';
  static const help =
      'Bạn bè nhận được địa điểm trong Tin nhắn và có thể trò chuyện tiếp. '
      'Ghi chú riêng của bạn về nơi này không được gửi.';
  static const noFriends =
      'Bạn chưa có bạn bè trên app. Kết bạn bằng username ở Khám phá, mục '
      'Bạn bè.';
  static const send = 'Gửi';
  static const failed = 'Chưa gửi được. Kiểm tra kết nối rồi thử lại.';
  static const unavailable =
      'Chưa gửi được: máy chủ chưa hỗ trợ tin nhắn. Địa điểm vẫn ở bản đồ '
      'của bạn.';
  static const loadFailed = 'Chưa tải được danh sách bạn bè.';
}

/// Why sending a place did not happen, said by the caller.
class SendPlaceFailed implements Exception {
  const SendPlaceFailed(this.message);
  final String message;
}

/// Picks friends and sends them [place] as a message each. The names it
/// went to; null when closed. Throws [SendPlaceFailed] with what to say.
Future<List<String>?> sendPlaceToFriends(BuildContext context,
    MessagesRepository repository, SharedPlace place) async {
  List<AppFriend> friends;
  try {
    friends = await repository.friends();
  } catch (_) {
    throw const SendPlaceFailed(SendPlaceText.loadFailed);
  }
  if (!context.mounted) return null;
  final picked = await showAppSheet<List<AppFriend>>(context,
      builder: (_) => _SendPlaceSheet(place: place, friends: friends));
  if (picked == null || picked.isEmpty) return null;
  try {
    await repository.sharePlace([for (final f in picked) f.id], place);
  } on MessagesUnavailable {
    throw const SendPlaceFailed(SendPlaceText.unavailable);
  } catch (_) {
    throw const SendPlaceFailed(SendPlaceText.failed);
  }
  return [for (final f in picked) f.name];
}

class _SendPlaceSheet extends StatefulWidget {
  const _SendPlaceSheet({required this.place, required this.friends});

  final SharedPlace place;
  final List<AppFriend> friends;

  @override
  State<_SendPlaceSheet> createState() => _SendPlaceSheetState();
}

class _SendPlaceSheetState extends State<_SendPlaceSheet> {
  final _picked = <String>{};

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(SendPlaceText.title(widget.place.name),
              style: AppText.sectionTitle),
          const SizedBox(height: AppSpacing.xs),
          const Text(SendPlaceText.help, style: AppText.meta),
          const SizedBox(height: AppSpacing.sm),
          if (widget.friends.isEmpty)
            const Text(SendPlaceText.noFriends, style: AppText.bodySecondary)
          else
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final friend in widget.friends)
                  CheckboxListTile(
                    key: ValueKey('send-place-to-${friend.id}'),
                    value: _picked.contains(friend.id),
                    onChanged: (on) => setState(() => on == true
                        ? _picked.add(friend.id)
                        : _picked.remove(friend.id)),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.trailing,
                    secondary: FriendAvatar(friend, size: 40),
                    title: Text(friend.name, style: AppText.body),
                  ),
              ]),
            ),
          const SizedBox(height: AppSpacing.md),
          AppPrimaryButton(
            label: SendPlaceText.send,
            icon: Icons.send_rounded,
            onPressed: _picked.isEmpty
                ? null
                : () => Navigator.pop(context, [
                      for (final f in widget.friends)
                        if (_picked.contains(f.id)) f
                    ]),
          ),
        ],
      );
}
