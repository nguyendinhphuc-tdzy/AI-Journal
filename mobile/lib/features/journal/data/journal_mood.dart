/// Moods the user picks for an entry. Self-reported only: never inferred or
/// diagnosed by AI. Persisted by [name]; do not rename.
enum JournalMood {
  calm('Bình yên'),
  happy('Vui'),
  anxious('Lo lắng'),
  confused('Bối rối'),
  tired('Mệt'),
  unsure('Chưa rõ');

  const JournalMood(this.label);

  final String label;
}
