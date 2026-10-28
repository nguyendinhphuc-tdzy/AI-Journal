import 'package:flutter/widgets.dart';
import '../../../core/network/api_client.dart';

class FriendRow {
  FriendRow(Map<String, dynamic> data)
      : id = data['user_id'] as String,
        status = data['status'] as String,
        direction = data['direction'] as String;
  final String id;
  final String status;
  final String direction;
}

class FriendSuggestion {
  FriendSuggestion(Map<String, dynamic> data)
      : id = data['user_id'] as String,
        name = data['display_name'] as String;
  final String id;
  final String name;
}

class FriendsRepository {
  const FriendsRepository(this.api);
  final ApiClient api;

  Future<List<FriendRow>> list() async =>
      (await api.getList('/friends', requireAuth: true))
          .map((item) => FriendRow(item as Map<String, dynamic>))
          .toList();

  Future<List<FriendSuggestion>> search(String query) async {
    if (query.trim().length < 3) return const [];
    final items = await api.getList(
      '/friends/discover?q=${Uri.encodeQueryComponent(query.trim())}',
      requireAuth: true,
    );
    return items.map((item) =>
      FriendSuggestion(item as Map<String, dynamic>)).toList();
  }

  Future<void> request(String userId) async {
    await api.postJson('/friends/requests', {'user_id': userId}, requireAuth: true);
  }
  Future<void> accept(String userId) async {
    await api.postJson('/friends/$userId/accept', {}, requireAuth: true);
  }
  Future<void> remove(String userId) =>
      api.deleteNoContent('/friends/$userId', requireAuth: true);
  Future<void> block(String userId) async {
    await api.postJson('/friends/blocks', {'user_id': userId}, requireAuth: true);
  }
}

class FriendsScope extends InheritedWidget {
  const FriendsScope({super.key, required this.repository, required super.child});
  final FriendsRepository repository;

  static FriendsRepository? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FriendsScope>()?.repository;

  @override
  bool updateShouldNotify(FriendsScope oldWidget) =>
      repository != oldWidget.repository;
}
