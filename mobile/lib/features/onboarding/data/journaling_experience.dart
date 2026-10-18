/// OB04: how familiar the user is with journaling. Persisted by [name]
/// (`beginner`, `occasional`, `regular`, `unknown`); do not rename.
///
/// Only shapes guidance, never access: every method and the same AI quality
/// stay open at every level. Suggested use (OB07 and later):
/// - [beginner]: clearer step-by-step hints in the guided first entry;
/// - [occasional]: point out that a draft can be picked up again;
/// - [regular]: the same form with fewer hints.
/// Without an edited prompt mapping, use the default edited prompt; never
/// claim "AI just personalised this" while loading.
enum JournalingExperience {
  beginner('Mình mới bắt đầu', 'Mình muốn có một chút hướng dẫn'),
  occasional('Mình viết tùy lúc', 'Mình muốn dễ quay lại hơn'),
  regular('Mình đã viết khá đều', 'Mình muốn thử cách viết sâu hơn'),

  /// Saved by "Để sau"; not offered as a card.
  unknown('', '');

  const JournalingExperience(this.label, this.description);

  final String label;
  final String description;

  /// The cards OB04 offers, in order.
  static const options = [beginner, occasional, regular];
}
