/// A pin to point out when Explore opens, e.g. a post just shared from Album
/// (A10 → E01). Shown only until [expiresAt].
class ExploreHighlight {
  const ExploreHighlight({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
    required this.expiresAt,
  });

  final String id;
  final String title;
  final String subtitle;
  final double latitude;
  final double longitude;
  final DateTime expiresAt;

  bool isActive(DateTime now) => now.isBefore(expiresAt);
}
