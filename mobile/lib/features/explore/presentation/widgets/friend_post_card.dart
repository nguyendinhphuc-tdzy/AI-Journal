import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text.dart';
import '../../../album/presentation/share_memory_sheet.dart';
import '../../../social/data/friends_sharing.dart';

abstract final class FriendPostText {
  static String sharedBy(FriendPost post) => post.username == null
      ? '${post.senderName} chia sẻ'
      : '${post.senderName} (@${post.username}) chia sẻ';
  static const mine = 'Bài chia sẻ của bạn';
  static const closeTooltip = 'Đóng bài chia sẻ';
  static const openPhoto = 'Xem ảnh lớn';
  static const closePhoto = 'Đóng ảnh';
}

/// A friend's 24-hour post on the map ([PostCard]): who shared it, the
/// description, category, place, when it ends, and its photo small.
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
  Widget build(BuildContext context) => PostCard(
        title: post.title ?? post.placeLabel,
        byline: post.senderName == 'Bạn'
            ? FriendPostText.mine
            : FriendPostText.sharedBy(post),
        text: post.text,
        meta: [
          if (post.category != null) post.category!,
          post.placeLabel,
        ].join(' · '),
        footnote: ShareMemorySheet.expiresLabel(post.expiresAt),
        photo: photo,
        onClose: onClose,
      );
}

/// A 24-hour post's card over the map, kept short so the map stays in
/// view: the photo as a thumbnail on the left (a tap shows all of it, full
/// screen), then title, who, text and details. No photo (or it could not
/// load): the text takes the width.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.title,
    required this.onClose,
    this.byline,
    this.text,
    this.meta,
    this.footnote,
    this.photo,
  });

  final String title;
  final String? byline;
  final String? text;
  final String? meta;

  /// One line always shown in full (when the post ends).
  final String? footnote;
  final Future<Uint8List>? photo;
  final VoidCallback onClose;

  static const thumb = 88.0;

  @override
  Widget build(BuildContext context) {
    final photo = this.photo;
    return Material(
      color: AppColors.surface,
      elevation: 3,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, AppSpacing.xs, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (photo != null)
              FutureBuilder<Uint8List>(
                future: photo,
                builder: (context, snapshot) {
                  if (snapshot.hasError) return const SizedBox.shrink();
                  final bytes = snapshot.data;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: bytes == null
                        ? Container(
                            width: thumb,
                            height: thumb,
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Center(
                              child: SizedBox.square(
                                  dimension: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.4)),
                            ),
                          )
                        : _Thumb(bytes: bytes, title: title),
                  );
                },
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.label),
                  if (byline != null)
                    Text(byline!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.meta.copyWith(
                            fontSize: 13, color: AppColors.primaryAction)),
                  if (text != null) ...[
                    const SizedBox(height: 4),
                    Text(text!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body.copyWith(fontSize: 15)),
                  ],
                  if (meta != null) ...[
                    const SizedBox(height: 4),
                    Text(meta!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.meta.copyWith(fontSize: 12.5)),
                  ],
                  if (footnote != null)
                    Text(footnote!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.meta.copyWith(
                            fontSize: 12.5, color: AppColors.textPrimary)),
                ],
              ),
            ),
            IconButton(
              tooltip: FriendPostText.closeTooltip,
              visualDensity: VisualDensity.compact,
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

/// The photo small and square, with a sign that it opens larger.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.bytes, required this.title});

  final Uint8List bytes;
  final String title;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: FriendPostText.openPhoto,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: () => showFriendPhoto(context, bytes, title: title),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(children: [
              Image.memory(bytes,
                  width: PostCard.thumb,
                  height: PostCard.thumb,
                  fit: BoxFit.cover,
                  gaplessPlayback: true),
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .45),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.open_in_full_rounded,
                      size: 14, color: Colors.white),
                ),
              ),
            ]),
          ),
        ),
      );
}

/// The whole photo on black, never cropped; pinch to zoom, Close or Back
/// to leave.
Future<void> showFriendPhoto(BuildContext context, Uint8List bytes,
        {required String title}) =>
    Navigator.of(context, rootNavigator: true).push(PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 260),
      pageBuilder: (context, _, __) => Scaffold(
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
            child:
                Image.memory(bytes, fit: BoxFit.contain, semanticLabel: title),
          ),
        ),
      ),
      transitionsBuilder: (context, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ));
