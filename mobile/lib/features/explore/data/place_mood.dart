/// How the user felt at a saved place, shown as Nudaeng. Optional: a place
/// can be saved without one. None of these is a mood to fix; they are only
/// what it was like.
enum PlaceMood {
  peaceful('Bình yên'),
  happy('Vui vẻ'),
  excited('Háo hức'),
  reflective('Trầm lắng'),
  anxious('Lo lắng'),
  tired('Mệt mỏi');

  const PlaceMood(this.label);

  final String label;

  /// Transparent PNG, the same square frame for every mood.
  String get asset => 'assets/images/map-moods/nudaeng-$name.png';

  /// The map marker image registered for this mood.
  String get marker => 'mood-$name';
}
