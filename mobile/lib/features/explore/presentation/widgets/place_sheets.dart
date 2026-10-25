import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class PlaceDraft {
  const PlaceDraft({
    required this.name,
    required this.category,
    required this.moodTag,
    required this.note,
    required this.moodAsset,
    required this.moodLabel,
    required this.isAnonymousShare,
  });

  final String name;
  final String category;
  final String moodTag;
  final String note;
  final String moodAsset;
  final String moodLabel;
  final bool isAnonymousShare;
}

const moodOptions = [
  ('Reading', 'assets/images/docsach.gif'),
  ('On the road', 'assets/images/laixe.gif'),
  ('Loved it', 'assets/images/like.gif'),
  ('Taking a breath', 'assets/images/loading.gif'),
];

const moodTags = ['Yên tĩnh', 'Cần chữa lành', 'Vui vẻ', 'Xả stress'];

Future<PlaceDraft?> showAddPlaceSheet(BuildContext context) =>
    showModalBottomSheet<PlaceDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddPlaceSheet(),
    );

class _AddPlaceSheet extends StatefulWidget {
  const _AddPlaceSheet();

  @override
  State<_AddPlaceSheet> createState() => _AddPlaceSheetState();
}

class _AddPlaceSheetState extends State<_AddPlaceSheet> {
  final _name = TextEditingController();
  final _note = TextEditingController();
  String _category = 'Food';
  String _moodTag = moodTags.first;
  var _mood = moodOptions.first;
  bool _isAnonymousShare = false;

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hãy nhập tên địa điểm.')));
      return;
    }
    Navigator.pop(
        context,
        PlaceDraft(
          name: name,
          category: _category,
          moodTag: _moodTag,
          note: _note.text.trim(),
          moodLabel: _mood.$1,
          moodAsset: _mood.$2,
          isAnonymousShare: _isAnonymousShare,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(8))),
              const SizedBox(height: 16),
              Text('Save a new place',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Tên địa điểm',
                  hintText: 'Tiệm bánh cô Hai...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(spacing: 8, children: [
                  for (final category in ['Food', 'Study', 'Chill'])
                    ChoiceChip(
                      label: Text(category),
                      selected: _category == category,
                      onSelected: (_) => setState(() => _category = category),
                    ),
                ]),
              ),
              const SizedBox(height: 16),
              const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Cảm xúc tại địa điểm này')),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final moodTag in moodTags)
                    ChoiceChip(
                      label: Text(moodTag),
                      selected: _moodTag == moodTag,
                      onSelected: (_) => setState(() => _moodTag = moodTag),
                    ),
                ]),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _note,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Bạn cảm thấy thế nào ở đây?',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Chọn Nudaeng Mood')),
              const SizedBox(height: 8),
              SizedBox(
                height: 84,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: moodOptions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, index) {
                    final mood = moodOptions[index];
                    final selected = mood == _mood;
                    return Semantics(
                      selected: selected,
                      label: 'Mood ${mood.$1}',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => setState(() => _mood = mood),
                        child: Container(
                          width: 76,
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: selected
                                    ? AppColors.primaryDark
                                    : Colors.transparent,
                                width: 2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Image.asset(mood.$2, fit: BoxFit.contain),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _isAnonymousShare,
                onChanged: (value) => setState(() => _isAnonymousShare = value),
                title: const Text('Chia sẻ ẩn danh cho cộng đồng'),
                subtitle: const Text(
                  'Người khác sẽ thấy địa điểm này nhưng không biết ai là người gửi.',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: const Text('Lưu & Ghim lên bản đồ'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

Future<void> showSavedPlaceSheet(BuildContext context, SavedPlace place,
        {Future<void> Function()? onShare}) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        top: false,
        child: Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 42, height: 4, color: Colors.grey),
              const SizedBox(height: 20),
              Image.asset(place.moodAsset, height: 72),
              Text(place.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('${place.category} · ${place.moodTag} · ${place.moodLabel}'),
              if (place.note.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(place.note, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    if (onShare != null) {
                      await onShare();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Share is a mock in this version.')));
                    }
                  },
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Share'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      foregroundColor: Colors.white),
                ),
              )
            ]),
          ),
        ),
      ),
    );

const _friends = [
  ('Tường Vy', 'TV'),
  ('Huy Nhật', 'HN'),
  ('Đình Phúc', 'ĐP'),
];

Future<List<String>?> showShareFriendsSheet(BuildContext context,
        {required String placeName}) =>
    showModalBottomSheet<List<String>>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShareFriendsSheet(placeName: placeName),
    );

class _ShareFriendsSheet extends StatefulWidget {
  const _ShareFriendsSheet({required this.placeName});
  final String placeName;

  @override
  State<_ShareFriendsSheet> createState() => _ShareFriendsSheetState();
}

class _ShareFriendsSheetState extends State<_ShareFriendsSheet> {
  final _recipients = <String>{};

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(8))),
                const SizedBox(height: 16),
                Text('Gửi qua Nudaeng Post',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(widget.placeName,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700)),
                const SizedBox(height: 12),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _friends.length,
                  itemBuilder: (_, index) {
                    final friend = _friends[index];
                    final checked = _recipients.contains(friend.$1);
                    return CheckboxListTile(
                      value: checked,
                      onChanged: (value) => setState(() {
                        value == true
                            ? _recipients.add(friend.$1)
                            : _recipients.remove(friend.$1);
                      }),
                      secondary: CircleAvatar(child: Text(friend.$2)),
                      title: Text(friend.$1),
                      controlAffinity: ListTileControlAffinity.trailing,
                    );
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _recipients.isEmpty
                        ? null
                        : () => Navigator.pop(context, _recipients.toList()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: const Text('Gửi thư'),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
}

Future<bool?> showInboxSheet(BuildContext context) =>
    showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        top: false,
        child: Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(8))),
                const SizedBox(height: 16),
                Text('Hòm thư của bạn',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const ListTile(
                  leading: CircleAvatar(child: Icon(Icons.card_giftcard)),
                  title: Text('Tường Vy vừa gửi cho bạn một địa điểm bí mật!'),
                  subtitle: Text('Nudaeng Post · vừa xong'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52)),
                    child: const Text('Mở & Lưu vào bản đồ'),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );

class SavedPlace {
  const SavedPlace({
    required this.id,
    required this.name,
    required this.category,
    required this.moodTag,
    required this.note,
    required this.latitude,
    required this.longitude,
    required this.moodAsset,
    required this.moodLabel,
  });

  final String id;
  final String name;
  final String category;
  final String moodTag;
  final String note;
  final double latitude;
  final double longitude;
  final String moodAsset;
  final String moodLabel;
}
