import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text.dart';
import '../../../album/presentation/share_memory_sheet.dart';
import '../../../social/data/friends_sharing.dart';

abstract final class FriendPostText {
  static String sharedBy(FriendPost post) => post.username == null
      ? '${post.senderName} chia sẻ'
      : '${post.senderName} (@${post.username}) chia sẻ';
  static const closeTooltip = 'Đóng bài chia sẻ';
  static const openPhoto = 'Xem ảnh lớn';
  static const closePhoto = 'Đóng ảnh';
  static const photoFailed = 'Chưa tải được ảnh.';
}

/// A friend's 24-hour post on the map: the photo large at the top (a tap
/// opens it full screen), then who shared it, the description, category,
/// place and when it ends.
class FriendPostCard extends StatelessWidget {
  const FriendPostCard({
    super.key,
    required this.post,
    required this.photo,
    required this.onClose,
  });

  final FriendPost post;

  /// The photo's bytes when the post has one.
  final Future<Uint8List>? photo;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final photo = this.photo;
    final maxPhoto = MediaQuery.sizeOf(context).height * .26;
    return Material(
      color: AppColors.surface,
      elevation: 3,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (photo != null)
            FutureBuilder<Uint8List>(
              future: photo,
              builder: (context, snapshot) {
                final bytes = snapshot.data;
                if (snapshot.hasError) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Text(FriendPostText.photoFailed,
                        style: AppText.meta),
                  );
                }
                return SizedBox(
                  height: maxPhoto.clamp(120.0, 240.0),
                  child: bytes == null
                      ? const ColoredBox(
                          color: AppColors.background,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : Semantics(
                          button: true,
                          label: FriendPostText.openPhoto,
                          child: InkWell(
                            onTap: () => showFriendPhoto(context, bytes,
                                title: post.title ?? post.placeLabel),
                            child: Image.memory(bytes,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                                excludeFromSemantics: true),
                          ),
                        ),
                );
              },
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 12, AppSpacing.xs, AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.title ?? post.placeLabel,
                          style: AppText.cardTitle),
                      const SizedBox(height: 2),
                      Text(FriendPostText.sharedBy(post),
                          style: AppText.meta
                              .copyWith(color: AppColors.primaryAction)),
                      const SizedBox(height: 6),
                      Text(post.text,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body),
                      const SizedBox(height: 6),
                      Text(
                          [
                            if (post.category != null) post.category!,
                            post.placeLabel,
                            ShareMemorySheet.expiresLabel(post.expiresAt),
                          ].join(' · '),
                          style: AppText.meta),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: FriendPostText.closeTooltip,
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The photo full screen on black; pinch to zoom, Close or Back to leave.
Future<void> showFriendPhoto(BuildContext context, Uint8List bytes,
        {required String title}) =>
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          leading: IconButton(
            tooltip: FriendPostText.closePhoto,
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: InteractiveViewer(
          maxScale: 5,
          child: Center(
            child: Image.memory(bytes,
                fit: BoxFit.contain, semanticLabel: title),
          ),
        ),
      ),
    ));
