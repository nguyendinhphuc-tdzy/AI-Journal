import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../onboarding/presentation/frame_sequence.dart';
import '../data/album.dart';
import 'album_backdrop.dart';
import 'album_form_parts.dart';

/// How A06 opens from A05.
enum MemoryStartIntent {
  /// "Thêm kỷ niệm đầu tiên": the editor with its photo area first. The
  /// picker (A07) opens only when the user taps that area.
  photo,

  /// "Viết note trước": the editor with the note focused; no photo
  /// permission is asked.
  note,
}

/// A05: an album that exists but has no memory yet.
///
/// Back and the album name on top; one sheet of paper over the Album scene
/// with Nudaeng's bright-eyed hero, "Bắt đầu album kỷ niệm của bạn", two
/// ways in (photo first, note first) and a note that the scrapbook opens
/// after the first memory. Nothing asks for photo access here.
///
/// The hero (" Nudaeng long lanh.gif") wags its tail for a moment the first
/// time this album's empty page shows in the session, then holds still; it
/// never loops, and coming back (e.g. from the picker) shows it still. The
/// CTAs never wait for it. The hero takes at most about a third of the
/// screen (176 down to 128) and the page scrolls when space is short.
class AlbumStartScreen extends StatefulWidget {
  const AlbumStartScreen({
    super.key,
    required this.album,
    required this.onStart,
  });

  final Album album;

  /// Opens A06 the chosen way.
  final ValueChanged<MemoryStartIntent> onStart;

  static const title = 'Bắt đầu album kỷ niệm của bạn';
  static const body =
      'Thêm một bức ảnh hoặc vài dòng ghi chú. Album của bạn bắt đầu từ đây.';
  static const addFirstLabel = 'Thêm kỷ niệm đầu tiên';
  static const noteFirstLabel = 'Viết note trước';
  static const caption = 'Scrapbook sẽ mở sau kỷ niệm đầu tiên';

  static final heroFrames = [
    for (var i = 1; i <= 5; i++)
      'assets/Deimage/album-start-frame-${i.toString().padLeft(2, '0')}.png',
  ];

  /// ND01 with the supplied artwork: settles in (250 ms), wags its tail at
  /// the GIF's own pace for about a second, ends on the first pose by
  /// 1.8 s and holds it.
  static final heroDurations = [
    const Duration(milliseconds: 250),
    for (var wag = 0; wag < 7; wag++) ...const [
      Duration(milliseconds: 40),
      Duration(milliseconds: 40),
      Duration(milliseconds: 40),
      Duration(milliseconds: 40),
      Duration(milliseconds: 40),
    ],
    const Duration(milliseconds: 100),
  ];

  static List<String> get _heroSequence => [
        heroFrames[0],
        for (var wag = 0; wag < 7; wag++) ...heroFrames,
        heroFrames[0],
      ];

  /// Albums whose empty page already played in this session.
  static final _played = <String>{};

  @visibleForTesting
  static void resetPlayed() => _played.clear();

  @override
  State<AlbumStartScreen> createState() => _AlbumStartScreenState();
}

class _AlbumStartScreenState extends State<AlbumStartScreen> {
  /// Decided once: returning from A06/A07 rebuilds this page, still.
  late final bool _animate = AlbumStartScreen._played.add(widget.album.id);

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primaryLight,
          surfaceTintColor: Colors.transparent,
          title: Text(widget.album.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AlbumFormText.title),
        ),
        body: Stack(fit: StackFit.expand, children: [
          const AlbumBackdrop(),
          LayoutBuilder(builder: (context, box) {
            final bigText = MediaQuery.textScalerOf(context).scale(16) > 20;
            // At most about a third of the screen; 128 on short screens or
            // with large text.
            final hero = bigText
                ? 128.0
                : math.min(176.0, math.max(128.0, box.maxHeight / 3 - 48));
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    minHeight: box.maxHeight - AppSpacing.lg - AppSpacing.xl),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: _Paper(
                      hero: hero,
                      animate: _animate,
                      onStart: widget.onStart,
                    ),
                  ),
                ),
              ),
            );
          }),
        ]),
      );
}

class _Paper extends StatelessWidget {
  const _Paper(
      {required this.hero, required this.animate, required this.onStart});

  final double hero;
  final bool animate;
  final ValueChanged<MemoryStartIntent> onStart;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: .06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: _Hero(size: hero, animate: animate)),
            const SizedBox(height: AppSpacing.xl),
            Semantics(
              header: true,
              child: const Text(AlbumStartScreen.title,
                  textAlign: TextAlign.center, style: _Text.title),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(AlbumStartScreen.body,
                textAlign: TextAlign.center, style: _Text.body),
            const SizedBox(height: AppSpacing.md),
            AlbumPrimaryButton(
              label: AlbumStartScreen.addFirstLabel,
              onPressed: () => onStart(MemoryStartIntent.photo),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => onStart(MemoryStartIntent.note),
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text(AlbumStartScreen.noteFirstLabel),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.primary),
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
                textStyle: AlbumFormText.button,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_stories_outlined,
                    size: 16, color: AppColors.textPrimary),
                SizedBox(width: 6),
                Flexible(
                  child: Text(AlbumStartScreen.caption,
                      textAlign: TextAlign.center, style: AlbumFormText.note),
                ),
              ],
            ),
          ],
        ),
      );
}

/// The bright-eyed Nudaeng as a taped photo on the page.
class _Hero extends StatelessWidget {
  const _Hero({required this.size, required this.animate});

  final double size;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final still = !animate || MediaQuery.disableAnimationsOf(context);
    return Semantics(
      image: true,
      label: 'Nudaeng mắt long lanh chờ kỷ niệm đầu tiên',
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(
              child: Transform.rotate(
                angle: -.03,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.textPrimary.withValues(alpha: .1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: still
                        ? Image.asset(AlbumStartScreen.heroFrames[0],
                            fit: BoxFit.cover)
                        : FrameSequence(
                            frames: AlbumStartScreen._heroSequence,
                            durations: AlbumStartScreen.heroDurations,
                          ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: -6,
              left: size * .32,
              child: Transform.rotate(
                angle: .06,
                child: Container(
                  width: size * .36,
                  height: 14,
                  color: AppColors.softAccent.withValues(alpha: .7),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

abstract final class _Text {
  static const title = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppColors.textPrimary,
  );
  static const body = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 16,
    height: 1.5,
    color: AppColors.textPrimary,
  );
}
