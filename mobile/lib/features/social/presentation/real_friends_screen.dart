import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../auth/data/auth_service.dart';

/// Real Supabase-account friendship, never mock Facebook friends.
class RealFriendsScreen extends StatefulWidget {
  const RealFriendsScreen({super.key, required this.auth});
  final SupabaseAuthService auth;

  @override
  State<RealFriendsScreen> createState() => _RealFriendsScreenState();
}

class _RealFriendsScreenState extends State<RealFriendsScreen> {
  late final ApiClient _api = ApiClient(
    accessTokenProvider: () async =>
        widget.auth.client.auth.currentSession?.accessToken,
    accessTokenRefresher: () async =>
        (await widget.auth.client.auth.refreshSession()).session?.accessToken,
  );
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _search = TextEditingController();
  Timer? _debounce;
  int _searchVersion = 0;
  bool _loading = true;
  bool _busy = false;
  bool _searching = false;
  bool _discoverable = false;
  bool _savedProfileHasName = false;
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _name.dispose();
    _username.dispose();
    _search.dispose();
    _api.close();
    super.dispose();
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  String _label(Map<String, dynamic> item) {
    final name = item['display_name'];
    final username = item['username'];
    if (name is String && name.trim().isNotEmpty) return name;
    if (username is String && username.isNotEmpty) return '@$username';
    return 'Người dùng AI-Journal';
  }

  String _secondary(Map<String, dynamic> item) {
    final handle = item['username'];
    return handle is String && handle.isNotEmpty ? '@$handle' : '';
  }

  Future<void> _reload() async {
    try {
      final profile = await _api.getJson('/me', requireAuth: true);
      final friends = await _api.getList('/friends', requireAuth: true);
      if (!mounted) return;
      setState(() {
        _discoverable = profile['discoverable'] == true;
        _savedProfileHasName =
            (profile['display_name'] is String &&
                (profile['display_name'] as String).trim().isNotEmpty) ||
            (profile['username'] is String &&
                (profile['username'] as String).trim().isNotEmpty);
        _name.text = (profile['display_name'] as String?) ?? '';
        _username.text = (profile['username'] as String?) ?? '';
        _friends = friends.whereType<Map<String, dynamic>>().toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
      _message('Không tải được hồ sơ và bạn bè. Kiểm tra kết nối backend.');
    }
  }

  Future<void> _mutate(Future<void> Function() action,
      {String success = 'Đã cập nhật'}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      _message(success);
      await _reload();
      await _find();
    } on ApiException catch (error) {
      _message(error.statusCode == 409
          ? 'Username đã được dùng hoặc lời mời đã tồn tại.'
          : 'Không thể thực hiện (HTTP ' + error.statusCode.toString() + ').');
    } on FormatException {
      _message('Tên hoặc username chưa hợp lệ. Username: 3–24 ký tự a-z, 0-9, _.');
    } catch (_) {
      _message('Không kết nối được. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveProfile() => _mutate(() async {
        final name = _name.text.trim();
        final handle = _username.text.trim()
            .replaceFirst(RegExp(r'^@'), '').toLowerCase();
        if (handle.isNotEmpty &&
            !RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(handle)) {
          throw const FormatException('Invalid username');
        }
        await _api.patchJson('/me', {
          'display_name': name.isEmpty ? null : name,
          'username': handle.isEmpty ? null : handle,
        }, requireAuth: true);
      }, success: 'Đã lưu tên và username');

  Future<void> _toggleDiscoverable(bool value) => _mutate(() async {
        if (value && !_savedProfileHasName) {
          throw const FormatException('Choose name first');
        }
        await _api.patchJson('/me', {'discoverable': value},
            requireAuth: true);
      }, success: value
          ? 'Đã bật cho phép người khác tìm thấy bạn'
          : 'Đã ẩn hồ sơ khỏi tìm kiếm');

  void _queueSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _find);
    if (text.trim().length < 3) {
      setState(() => _results = []);
    }
  }

  Future<void> _find() async {
    final q = _search.text.trim();
    final version = ++_searchVersion;
    if (q.length < 3) {
      if (mounted) setState(() { _results = []; _searching = false; });
      return;
    }
    setState(() => _searching = true);
    try {
      final items = await _api.getList(
          '/friends/discover?q=' + Uri.encodeQueryComponent(q),
          requireAuth: true);
      if (!mounted || version != _searchVersion) return;
      setState(() {
        _results = items.whereType<Map<String, dynamic>>().toList();
        _searching = false;
      });
    } catch (_) {
      if (!mounted || version != _searchVersion) return;
      setState(() { _results = []; _searching = false; });
      _message('Tìm kiếm thất bại, thử lại sau.');
    }
  }

  Future<void> _request(String userId) => _mutate(() async {
        await _api.postJson('/friends/requests', {'user_id': userId},
            requireAuth: true);
      }, success: 'Đã gửi lời mời kết bạn');

  Future<void> _accept(String userId) => _mutate(() async {
        await _api.postJson('/friends/$userId/accept', {},
            requireAuth: true);
      }, success: 'Đã chấp nhận lời mời');

  Future<void> _remove(String userId) => _mutate(() async {
        await _api.deleteNoContent('/friends/$userId', requireAuth: true);
      }, success: 'Đã cập nhật danh sách bạn bè');

  Widget _person(Map<String, dynamic> person,
      {required String label, required VoidCallback? onTap}) => ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person_outline)),
        title: Text(_label(person), maxLines: 1,
            overflow: TextOverflow.ellipsis),
        subtitle: _secondary(person).isNotEmpty
            ? Text(_secondary(person)) : null,
        trailing: TextButton(onPressed: _busy ? null : onTap,
            child: Text(label)),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Bạn bè AI-Journal')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text('Hồ sơ của bạn',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    const Text('Tên từ bước “Nên gọi là gì?” được lưu vào '
                        'tài khoản. Chỉ khi bật tìm kiếm người khác mới thấy bạn.'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _name,
                      maxLength: 30,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(), labelText: 'Tên hiển thị',
                      ),
                    ),
                    TextField(
                      controller: _username,
                      maxLength: 24,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixText: '@',
                        labelText: 'Username duy nhất (a-z, 0-9, _)',
                      ),
                    ),
                    FilledButton(
                      onPressed: _busy ? null : _saveProfile,
                      child: const Text('Lưu hồ sơ'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Cho phép tìm thấy tôi'),
                      subtitle: const Text('Mặc định tắt. Không công khai nhật ký, album hay vị trí.'),
                      value: _discoverable,
                      onChanged: _busy ? null : _toggleDiscoverable,
                    ),
                    const Divider(height: 32),
                    const Text('Tìm bạn bè',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _search,
                      onChanged: _queueSearch,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Nhập @username hoặc tên (ít nhất 3 ký tự)',
                      ),
                    ),
                    if (_searching) const LinearProgressIndicator(),
                    if (_results.isNotEmpty)
                      ..._results.where((person) => !_friends.any(
                          (friend) => friend['user_id'] == person['user_id']
                      )).map((person) => _person(person,
                        label: 'Kết bạn',
                        onTap: () => _request(person['user_id'] as String))),
                    const Divider(height: 32),
                    const Text('Lời mời và bạn bè',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                    if (_friends.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('Chưa có lời mời hoặc bạn bè.'),
                      ),
                    ..._friends.map((person) {
                      final status = person['status'];
                      final direction = person['direction'];
                      final userId = person['user_id'] as String;
                      if (status == 'pending' && direction == 'incoming') {
                        return _person(person,
                            label: 'Chấp nhận',
                            onTap: () => _accept(userId));
                      }
                      return _person(person,
                          label: status == 'pending' ? 'Hủy lời mời' : 'Hủy kết bạn',
                          onTap: () => _remove(userId));
                    }),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
      );
}
