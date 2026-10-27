import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/app_ui.dart';

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

/// Nudaeng's moods: the key (also the map marker's name) and its GIF.
const moodOptions = [
  ('Reading', 'assets/images/docsach.gif'),
  ('On the road', 'assets/images/laixe.gif'),
  ('Loved it', 'assets/images/like.gif'),
  ('Taking a breath', 'assets/images/loading.gif'),
];

const moodTags = ['Yên tĩnh', 'Cần chữa lành', 'Vui vẻ', 'Xả stress'];

/// What a place is for: the stored key and what it says.
const placeCategories = [
  ('Food', 'Ăn uống'),
  ('Study', 'Học tập'),
  ('Chill', 'Thư giãn'),
];

/// A mood key ([moodOptions]) as it reads.
String moodName(String key) => switch (key) {
      'Reading' => 'Đọc sách',
      'On the road' => 'Dạo phố',
      'Loved it' => 'Thích lắm',
      'Taking a breath' => 'Hít thở',
      _ => key,
    };

/// A category key ([placeCategories]) as it reads.
String categoryName(String key) {
  for (final (value, label) in placeCategories) {
    if (value == key) return label;
  }
  return key;
}

abstract final class PlaceSheetText {
  static const addTitle = 'Lưu một nơi mới';
  static const addHelp = 'Nơi này được ghim ở giữa bản đồ bạn đang xem.';
  static const nameLabel = 'Tên địa điểm';
  static const nameHint = 'Ví dụ: Tiệm bánh cô Hai';
  static const nameMissing = 'Bạn đặt tên cho nơi này nhé.';
  static const categoryLabel = 'Loại địa điểm';
  static const moodTagLabel = 'Cảm xúc ở đây';
  static const noteLabel = 'Bạn cảm thấy thế nào ở đây?';
  static const moodLabel = 'Nudaeng của nơi này';
  static const anonymousTitle = 'Chia sẻ ẩn danh cho cộng đồng';
  static const anonymousHelp =
      'Bản thử: trạm ẩn danh chỉ hiện trên máy này, chưa gửi cho cộng đồng.';
  static const saveLabel = 'Lưu và ghim lên bản đồ';
  static const shareLabel = 'Gửi cho bạn bè';
  static const shareMock = 'Tính năng gửi cho bạn bè đang được hoàn thiện.';
  static const postTitle = 'Gửi qua Nudaeng Post';
  static const sendLabel = 'Gửi thư';
  static const inboxTitle = 'Hòm thư của bạn';
  static const inboxLetter = 'Tường Vy vừa gửi cho bạn một địa điểm bí mật!';
  static const inboxMeta = 'Nudaeng Post · vừa xong';
  static const openLabel = 'Mở và lưu vào bản đồ';
}

Future<PlaceDraft?> showAddPlaceSheet(BuildContext context) =>
    showAppSheet<PlaceDraft>(context, builder: (_) => const _AddPlaceSheet());

class _AddPlaceSheet extends StatefulWidget {
  const _AddPlaceSheet();

  @override
  State<_AddPlaceSheet> createState() => _AddPlaceSheetState();
}

class _AddPlaceSheetState extends State<_AddPlaceSheet> {
  final _name = TextEditingController();
  final _note = TextEditingController();
  String _category = placeCategories.first.$1;
  String _moodTag = moodTags.first;
  var _mood = moodOptions.first;
  bool _isAnonymousShare = false;
  bool _nameMissing = false;

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameMissing = true);
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
  Widget build(BuildContext context) => Padding(
        // The keyboard pushes the form up; the sheet scrolls.
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(PlaceSheetText.addTitle, style: AppText.sectionTitle),
            const SizedBox(height: AppSpacing.xs),
            const Text(PlaceSheetText.addHelp, style: AppText.meta),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              style: AppText.body,
              onChanged: (_) {
                if (_nameMissing) setState(() => _nameMissing = false);
              },
              decoration: _field(
                label: PlaceSheetText.nameLabel,
                hint: PlaceSheetText.nameHint,
                error: _nameMissing ? PlaceSheetText.nameMissing : null,
              ),
            ),
            const _Section(PlaceSheetText.categoryLabel),
            Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
              for (final (value, label) in placeCategories)
                _Choice(
                  label: label,
                  selected: _category == value,
                  onTap: () => setState(() => _category = value),
                ),
            ]),
            const _Section(PlaceSheetText.moodTagLabel),
            Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
              for (final moodTag in moodTags)
                _Choice(
                  label: moodTag,
                  selected: _moodTag == moodTag,
                  onTap: () => setState(() => _moodTag = moodTag),
                ),
            ]),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _note,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              style: AppText.body,
              decoration: _field(label: PlaceSheetText.noteLabel),
            ),
            const _Section(PlaceSheetText.moodLabel),
            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: moodOptions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, index) {
                  final mood = moodOptions[index];
                  return _MoodTile(
                    asset: mood.$2,
                    label: moodName(mood.$1),
                    selected: mood == _mood,
                    onTap: () => setState(() => _mood = mood),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SwitchListTile.adaptive(
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              tileColor: AppColors.background,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.input)),
              value: _isAnonymousShare,
              onChanged: (value) => setState(() => _isAnonymousShare = value),
              activeTrackColor: AppColors.primaryAction,
              title: const Text(PlaceSheetText.anonymousTitle,
                  style: AppText.label),
              subtitle:
                  const Text(PlaceSheetText.anonymousHelp, style: AppText.meta),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppPrimaryButton(
              label: PlaceSheetText.saveLabel,
              icon: Icons.push_pin_outlined,
              onPressed: _save,
            ),
          ],
        ),
      );

  static InputDecoration _field(
          {required String label, String? hint, String? error}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: error,
        labelStyle: AppText.bodySecondary,
        hintStyle: AppText.bodySecondary,
        filled: true,
        fillColor: AppColors.surface,
        border: _border(AppColors.border),
        enabledBorder: _border(AppColors.border),
        focusedBorder: _border(AppColors.primaryAction, width: 1.5),
      );

  static OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.input)),
        borderSide: BorderSide(color: color, width: width),
      );
}

/// A small label over a group of choices.
class _Section extends StatelessWidget {
  const _Section(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding:
            const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
        child: Text(text,
            style: AppText.label.copyWith(color: AppColors.textSecondary)),
      );
}

/// One of a few: Primary Light with an outline when chosen, as Journal's
/// mood chips; 40 high.
class _Choice extends StatelessWidget {
  const _Choice(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? AppColors.primaryLight : AppColors.surface,
          shape: StadiumBorder(
              side: BorderSide(
                  color:
                      selected ? AppColors.primaryAction : AppColors.border)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Center(
                  widthFactor: 1,
                  child: Text(label,
                      style: AppText.meta.copyWith(
                          color: selected
                              ? AppColors.primaryAction
                              : AppColors.textPrimary,
                          fontWeight: selected ? FontWeight.w600 : null)),
                ),
              ),
            ),
          ),
        ),
      );
}

/// Nudaeng in one mood, with its name; Primary Light and an outline when
/// chosen.
class _MoodTile extends StatelessWidget {
  const _MoodTile({
    required this.asset,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String asset;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: 'Nudaeng $label',
        excludeSemantics: true,
        child: Material(
          color: selected ? AppColors.primaryLight : AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            side: BorderSide(
                color: selected ? AppColors.primaryAction : Colors.transparent,
                width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 84,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(children: [
                  Expanded(child: Image.asset(asset, fit: BoxFit.contain)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.meta.copyWith(
                          fontSize: 12,
                          color: selected
                              ? AppColors.primaryAction
                              : AppColors.textSecondary)),
                ]),
              ),
            ),
          ),
        ),
      );
}

/// Nudaeng in a Primary Light circle, as at the top of a place's sheet.
class _NudaengBadge extends StatelessWidget {
  const _NudaengBadge(this.asset);

  final String asset;
  static const size = 88.0;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(size * .12),
        decoration: const BoxDecoration(
            color: AppColors.primaryLight, shape: BoxShape.circle),
        child: Image.asset(asset, fit: BoxFit.contain),
      );
}

Future<void> showSavedPlaceSheet(BuildContext context, SavedPlace place,
        {Future<void> Function()? onShare}) =>
    showAppSheet<void>(
      context,
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: _NudaengBadge(place.moodAsset)),
          const SizedBox(height: AppSpacing.md),
          Text(place.name,
              textAlign: TextAlign.center, style: AppText.sectionTitle),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final tag in [
                categoryName(place.category),
                place.moodTag,
                moodName(place.moodLabel),
              ])
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: AppSpacing.xs),
                  decoration: const ShapeDecoration(
                      color: AppColors.background, shape: StadiumBorder()),
                  child: Text(tag, style: AppText.meta),
                ),
            ],
          ),
          if (place.note.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(place.note,
                textAlign: TextAlign.center, style: AppText.bodySecondary),
          ],
          const SizedBox(height: AppSpacing.xl),
          AppPrimaryButton(
            label: PlaceSheetText.shareLabel,
            icon: Icons.send_outlined,
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(sheet);
              if (onShare != null) {
                await onShare();
              } else {
                messenger.showSnackBar(
                    const SnackBar(content: Text(PlaceSheetText.shareMock)));
              }
            },
          ),
        ],
      ),
    );

const _friends = [
  ('Tường Vy', 'TV'),
  ('Huy Nhật', 'HN'),
  ('Đình Phúc', 'ĐP'),
];

Future<List<String>?> showShareFriendsSheet(BuildContext context,
        {required String placeName}) =>
    showAppSheet<List<String>>(context,
        builder: (_) => _ShareFriendsSheet(placeName: placeName));

class _ShareFriendsSheet extends StatefulWidget {
  const _ShareFriendsSheet({required this.placeName});
  final String placeName;

  @override
  State<_ShareFriendsSheet> createState() => _ShareFriendsSheetState();
}

class _ShareFriendsSheetState extends State<_ShareFriendsSheet> {
  final _recipients = <String>{};

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(PlaceSheetText.postTitle, style: AppText.sectionTitle),
          const SizedBox(height: AppSpacing.xs),
          Text(widget.placeName, style: AppText.meta),
          const SizedBox(height: AppSpacing.md),
          for (final (name, initials) in _friends)
            CheckboxListTile(
              value: _recipients.contains(name),
              onChanged: (value) => setState(() {
                value == true
                    ? _recipients.add(name)
                    : _recipients.remove(name);
              }),
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.primaryAction,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.small)),
              secondary: CircleAvatar(
                backgroundColor: AppColors.primaryLight,
                foregroundColor: AppColors.primaryAction,
                child: Text(initials,
                    style: AppText.meta.copyWith(
                        color: AppColors.primaryAction,
                        fontWeight: FontWeight.w600)),
              ),
              title: Text(name, style: AppText.body),
              controlAffinity: ListTileControlAffinity.trailing,
            ),
          const SizedBox(height: AppSpacing.lg),
          AppPrimaryButton(
            label: PlaceSheetText.sendLabel,
            icon: Icons.send_outlined,
            onPressed: _recipients.isEmpty
                ? null
                : () => Navigator.pop(context, _recipients.toList()),
          ),
        ],
      );
}

Future<bool?> showInboxSheet(BuildContext context) => showAppSheet<bool>(
      context,
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(PlaceSheetText.inboxTitle, style: AppText.sectionTitle),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.input),
            ),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                    color: AppColors.primaryLight, shape: BoxShape.circle),
                child: const Icon(Icons.mail_outline_rounded,
                    color: AppColors.primaryAction),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(PlaceSheetText.inboxLetter, style: AppText.label),
                    SizedBox(height: 2),
                    Text(PlaceSheetText.inboxMeta, style: AppText.meta),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppPrimaryButton(
            label: PlaceSheetText.openLabel,
            icon: Icons.mark_email_read_outlined,
            onPressed: () => Navigator.pop(sheet, true),
          ),
        ],
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
