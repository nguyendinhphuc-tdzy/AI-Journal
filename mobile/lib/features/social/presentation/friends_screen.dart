import 'package:flutter/material.dart';
import '../data/friends_repository.dart';

/// Standalone Friends screen. Never shows non-opted-in user profiles.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _search = TextEditingController();
  List<FriendRow> _friends = const [];
  List<FriendSuggestion> _suggestions = const [];
  bool _loading = false;
  String? _error;
  int _searchVersion = 0;

  FriendsRepository get _repo => FriendsScope.maybeOf(context)!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final items = await _repo.list();
      if (mounted) setState(() => _friends = items);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được danh sách bạn bè.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _find(String query) async {
    final version = ++_searchVersion;
    if (query.trim().length < 3) {
      setState(() => _suggestions = const []);
      return;
    }
    try {
      final results = await _repo.search(query);
      if (mounted && version == _searchVersion) {
        setState(() { _suggestions = results; _error = null; });
      }
    } catch (_) {
      if (mounted && version == _searchVersion) {
        setState(() => _error = 'Không tìm kiếm được lúc này.');
      }
    }
  }

  Future<void> _action(Future<void> Function() act) async {
    try {
      await act();
      if (!mounted) return;
      await _refresh();
      if (mounted && _search.text.trim().length >= 3) {
        await _find(_search.text);
      }
    } catch (_) {
      if (mounted) setState(() =>
        _error = 'Không thực hiện được. Vui lòng thử lại.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Bạn bè')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Chỉ hồ sơ đồng ý cho tìm kiếm mới xuất hiện.'),
      const SizedBox(height: 12),
      TextField(
        controller: _search,
        onChanged: _find,
        decoration: const InputDecoration(
          labelText: 'Tìm tên hiển thị (ít nhất 3 ký tự)',
          prefixIcon: Icon(Icons.search),
        ),
      ),
      if (_error != null) Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(_error!, style: const TextStyle(color: Colors.red)),
      ),
      if (_loading) const LinearProgressIndicator(),
      for (final item in _suggestions)
        ListTile(
          title: Text(item.name),
          trailing: TextButton(
            onPressed: () => _action(() => _repo.request(item.id)),
            child: const Text('Kết bạn'),
          ),
        ),
      const Divider(),
      const Text('Bạn bè và lời mời', style: TextStyle(fontWeight: FontWeight.bold)),
      for (final item in _friends)
        ListTile(
          title: Text(item.userIdLabel),
          subtitle: Text(item.status == 'accepted' ? 'Bạn bè'
              : item.direction == 'incoming' ? 'Đã nhận lời mời' : 'Đã gửi lời mời'),
          trailing: Wrap(spacing: 4, children: [
            if (item.status == 'pending' && item.direction == 'incoming')
              IconButton(
                tooltip: 'Chấp nhận',
                icon: const Icon(Icons.check),
                onPressed: () => _action(() => _repo.accept(item.id)),
              ),
            IconButton(
              tooltip: 'Hủy hoặc xóa',
              icon: const Icon(Icons.person_remove_outlined),
              onPressed: () => _action(() => _repo.remove(item.id)),
            ),
            IconButton(
              tooltip: 'Chặn',
              icon: const Icon(Icons.block),
              onPressed: () => _action(() => _repo.block(item.id)),
            ),
          ]),
        ),
    ]),
  );
}

extension on FriendRow {
  String get userIdLabel => 'Người dùng ${id.substring(0, 8)}';
}
