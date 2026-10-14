/// Transparent cutouts of the exact supplied artwork (originals kept alongside).
/// Each pair follows the parenthesized artwork notes in App Mobile (1).pdf.
enum NudaengArtwork {
  // S01 banner: Study.jpg only, static. The head-tilt GIF was dropped because
  // swapping between two different drawings read as clutter.
  study('assets/Deimage/Study-transparent.png'),

  /// Hand-off from the S01 "Xem challenge" CTA to S04: the head tilt plays
  /// once and rests on its own first frame (its loop seam).
  challengeLoading(
    'assets/NudaenggifDe/Chú chó nghiêng đầu đọc sách-transparent.gif',
    animationAsset:
        'assets/NudaenggifDe/Chú chó nghiêng đầu đọc sách-transparent.gif',
  ),

  /// S02 hero: the page-turn plays on every open, settles on its own first
  /// frame (its loop seam), then fidgets: it turns a page again now and then.
  courseDetail(
    'assets/NudaenggifDe/Chó Nudaeng lật trang sách-transparent.gif',
    animationAsset:
        'assets/NudaenggifDe/Chó Nudaeng lật trang sách-transparent.gif',
    idleFidget: true,
  ),
  lesson('assets/Deimage/Chó Bài học đọc hoặc video-transparent.png'),
  challengeInvitation(
    'assets/Deimage/Mời-transparent.png',
    animationAsset:
        'assets/NudaenggifDe/Nudaeng_gio_bang_ra_truoc_1_5s-transparent.gif',
    maxDuration: Duration(milliseconds: 1500),
  ),
  challengeProgress(
    'assets/Deimage/Pose chờ challenges-transparent.png',
    animationAsset: 'assets/NudaenggifDe/ND05-check-notebook-transparent.gif',
    maxDuration: Duration(milliseconds: 1200),
  ),
  challengeCompletion(
    'assets/Deimage/Bạn đã hoàn thành challengs-transparent.png',
    animationAsset: 'assets/NudaenggifDe/Vẫy đuôi-transparent.gif',
    maxDuration: Duration(milliseconds: 1800),
  ),
  courseCompletion(
    'assets/NudaenggifDe/Chú chó ôm sách đầy yêu thương-transparent.gif',
    idleFrame: 4,
    animationAsset:
        'assets/NudaenggifDe/Chú chó ôm sách đầy yêu thương-transparent.gif',
    maxDuration: Duration(milliseconds: 1800),
  );

  const NudaengArtwork(
    this.idleAsset, {
    this.animationAsset,
    this.idleFrame = 0,
    this.maxDuration = const Duration(seconds: 2),
    this.idleFidget = false,
  });

  /// Select the actual resting pose from the supplied GIF, without replaying it.
  final String idleAsset;
  final int idleFrame;
  final String? animationAsset;
  final Duration maxDuration;

  /// Rive-style idle: after the one-shot, the hand-drawn motion replays after
  /// a varied 3-6 s rest, so the mascot seems to move on its own.
  final bool idleFidget;
}
