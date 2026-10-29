/// Phase A samples only. No user identity, persistence or backend calls.
class ExplorePlace {
  const ExplorePlace(
      this.id, this.label, this.category, this.latitude, this.longitude,
      {this.sample = true});

  final String id;
  final String label;
  final String category;
  final double latitude;
  final double longitude;
  final bool sample;
}

/// Replace with a JWT-authenticated FastAPI adapter only after deployment/Auth.
abstract class ExplorePlacesRepository {
  Future<List<ExplorePlace>> search(String query, String? category);
}

class MockExplorePlacesRepository implements ExplorePlacesRepository {
  const MockExplorePlacesRepository();

  static const places = [
    ExplorePlace('food', 'Bếp cô Ba ân', 'Food', 10.7740, 106.7000),
    ExplorePlace('cafe', 'Quiet corner', 'Study Cafe', 10.7790, 106.6960),
    ExplorePlace('park', 'Riverside park', 'Entertainment', 10.7760, 106.7060),
  ];

  @override
  Future<List<ExplorePlace>> search(String query, String? category) async =>
      places
          .where((place) =>
              (category == null || place.category == category) &&
              place.label.toLowerCase().contains(query.toLowerCase().trim()))
          .toList();
}
