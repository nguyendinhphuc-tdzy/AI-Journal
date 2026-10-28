import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../data/place_mood.dart';
import '../../data/saved_places.dart';

export '../../data/place_mood.dart';
export '../../data/saved_places.dart';

class PlaceDraft {
  const PlaceDraft({
    required this.name,
    required this.category,
    required this.mood,
    required this.note,
    required this.isAnonymousShare,
  });

  final String name;
  final String category;

  /// Null when no Nudaeng was chosen: nothing is assumed.
  final PlaceMood? mood;
  final String note;
  final bool isAnonymousShare;
}

/// What a place is for: the stored key and what it says.
const placeCategories = [
  ('Food', 'Ăn uống'),
  ('Study', 'Học tập'),
  ('Chill', 'Thư giãn'),
];

/// A category key's icon, where a place has no Nudaeng.
IconData categoryIcon(String key) => switch (key) {
      'Food' => Icons.restaurant_outlined,
      'Study' => Icons.menu_book_outlined,
      _ => Icons.spa_outlined,
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
  static const addHelpPinned = 'Nơi này được lưu ở chỗ bạn vừa ghim.';
  static const nameLabel = 'Tên địa điểm';
  static const nameHint = 'Ví dụ: Tiệm bánh cô Hai';
  static const nameMissing = 'Bạn đặt tên cho nơi này nhé.';
  static const closeTooltip = 'Đóng';
  static const categoryLabel = 'Nơi này dành cho…';
  static const moodLabel = 'Nudaeng nào giống bạn lúc này?';
  static const moodHelp = 'Chọn nếu bạn muốn';
  static const noteLabel = 'Vài dòng về nơi này';
  static const noteHint = 'Không bắt buộc';
  static const filterTitle = 'Lọc theo cảm xúc';
  static const filterHelp = 'Chỉ hiện những nơi bạn đã chọn Nudaeng này.';
  static const filterAll = 'Mọi cảm xúc';
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

/// [pinned]: the user chose where the place goes (a pin, a search result)
/// rather than the middle of the map. [name]: a name to start from, e.g. a
/// search result's.
Future<PlaceDraft?> showAddPlaceSheet(BuildContext context,
        {bool pinned = false, String? name}) =>
    showAppSheet<PlaceDraft>(context,
        builder: (_) => _AddPlaceSheet(pinned: pinned, name: name));

/// What was filled in before the sheet was closed without saving, for the
/// session: opening it again carries on. Saving clears it.
class _Unsaved {
  static var name = '';
  static var note = '';
  static String category = placeCategories.first.$1;
  static PlaceMood? mood;
  static var anonymous = false;

  static void clear() {
    name = '';
    note = '';
    category = placeCategories.first.$1;
    mood = null;
    anonymous = false;
  }
}

/// Forgets what [showAddPlaceSheet] kept from a closed sheet (tests).
@visibleForTesting
void clearUnsavedPlace() => _Unsaved.clear();

class _AddPlaceSheet extends StatefulWidget {
  const _AddPlaceSheet({required this.pinned, this.name});

  final bool pinned;
  final String? name;

  @override
  State<_AddPlaceSheet> createState() => _AddPlaceSheetState();
}

class _AddPlaceSheetState extends State<_AddPlaceSheet> {
  late final _name = TextEditingController(text: widget.name ?? _Unsaved.name);
  final _note = TextEditingController(text: _Unsaved.note);
  String _category = _Unsaved.category;
  PlaceMood? _mood = _Unsaved.mood;
  bool _isAnonymousShare = _Unsaved.anonymous;
  bool _nameMissing = false;
  var _saved = false;

  @override
  void dispose() {
    // Closed without saving (close button, back, tapping outside): keep it.
    if (!_saved) {
      _Unsaved.name = _name.text;
      _Unsaved.note = _note.text;
      _Unsaved.category = _category;
      _Unsaved.mood = _mood;
      _Unsaved.anonymous = _isAnonymousShare;
    }
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
    _saved = true;
    _Unsaved.clear();
    Navigator.pop(
        context,
        PlaceDraft(
          name: name,
          category: _category,
          mood: _mood,
          note: _note.text.trim(),
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
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(PlaceSheetText.addTitle,
                      style: AppText.sectionTitle),
                ),
              ),
              // Always a way back to the map without saving.
              IconButton(
                tooltip: PlaceSheetText.closeTooltip,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded,
                    color: AppColors.textSecondary),
              ),
            ]),
            Text(
                widget.pinned
                    ? PlaceSheetText.addHelpPinned
                    : PlaceSheetText.addHelp,
                style: AppText.meta),
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
            const _Section(PlaceSheetText.moodLabel,
                help: PlaceSheetText.moodHelp),
            MoodGrid(
              selected: _mood,
              // Tapping the chosen one again leaves it unchosen.
              onChanged: (mood) => setState(() => _mood = mood),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _note,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              style: AppText.body,
              decoration: _field(
                  label: PlaceSheetText.noteLabel,
                  hint: PlaceSheetText.noteHint),
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

/// Picks a Nudaeng mood for the map filter: the same six, and "Mọi cảm xúc".
/// Null when closed without choosing; `(null,)` for every mood.
Future<(PlaceMood?,)?> showMoodFilterSheet(
        BuildContext context, PlaceMood? current) =>
    showAppSheet<(PlaceMood?,)>(
      context,
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: AppSpacing.sm),
                child: Text(PlaceSheetText.filterTitle,
                    style: AppText.sectionTitle),
              ),
            ),
            IconButton(
              tooltip: PlaceSheetText.closeTooltip,
              onPressed: () => Navigator.pop(sheet),
              icon: const Icon(Icons.close_rounded,
                  color: AppColors.textSecondary),
            ),
          ]),
          const Text(PlaceSheetText.filterHelp, style: AppText.meta),
          const SizedBox(height: AppSpacing.lg),
          MoodGrid(
            selected: current,
            onChanged: (mood) => Navigator.pop(sheet, (mood,)),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSecondaryButton(
            label: PlaceSheetText.filterAll,
            compact: true,
            onPressed: () => Navigator.pop(sheet, (null,)),
          ),
        ],
      ),
    );

/// The six Nudaeng moods, three to a row, all in view at once. The chosen
/// one has Primary Light behind it, a teal outline and a tick; every one
/// keeps its name under it. Tapping the chosen one again gives null.
class MoodGrid extends StatelessWidget {
  const MoodGrid({super.key, required this.selected, required this.onChanged});

  final PlaceMood? selected;
  final ValueChanged<PlaceMood?> onChanged;

  static const gap = AppSpacing.sm;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final width = (box.maxWidth - gap * 2) / 3;
        return Wrap(spacing: gap, runSpacing: gap, children: [
          for (final mood in PlaceMood.values)
            SizedBox(
              width: width,
              child: _MoodTile(
                mood: mood,
                selected: mood == selected,
                onTap: () => onChanged(mood == selected ? null : mood),
              ),
            ),
        ]);
      });
}

/// A small label over a group of choices.
class _Section extends StatelessWidget {
  const _Section(this.text, {this.help});

  final String text;
  final String? help;

  @override
  Widget build(BuildContext context) {
    final help = this.help;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(text,
            style: AppText.label.copyWith(color: AppColors.textSecondary)),
        if (help != null) ...[
          const SizedBox(height: 2),
          Text(help, style: AppText.meta.copyWith(fontSize: 12)),
        ],
      ]),
    );
  }
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

/// Nudaeng in one mood with its name; chosen: Primary Light, a teal outline
/// and a tick in the corner.
class _MoodTile extends StatelessWidget {
  const _MoodTile({
    required this.mood,
    required this.selected,
    required this.onTap,
  });

  final PlaceMood mood;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: 'Nudaeng ${mood.label}',
        excludeSemantics: true,
        child: Stack(clipBehavior: Clip.none, children: [
          Material(
            color: selected ? AppColors.primaryLight : AppColors.background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              side: BorderSide(
                  color:
                      selected ? AppColors.primaryAction : Colors.transparent,
                  width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xs, AppSpacing.sm, AppSpacing.xs, AppSpacing.sm),
                child: Column(children: [
                  AspectRatio(
                    aspectRatio: 1.25,
                    child: Image.asset(mood.asset,
                        fit: BoxFit.contain, cacheWidth: 260),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(mood.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.meta.copyWith(
                          fontSize: 13,
                          color: selected
                              ? AppColors.primaryAction
                              : AppColors.textPrimary,
                          fontWeight: selected ? FontWeight.w600 : null)),
                ]),
              ),
            ),
          ),
          if (selected)
            const Positioned(
              top: 6,
              right: 6,
              child: DecoratedBox(
                decoration: BoxDecoration(
                    color: AppColors.primaryAction, shape: BoxShape.circle),
                child: Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.check_rounded,
                      size: 14, color: AppColors.surface),
                ),
              ),
            ),
        ]),
      );
}

/// The place's Nudaeng in a Primary Light circle at the top of its sheet;
/// without one, what the place is for.
class _PlaceBadge extends StatelessWidget {
  const _PlaceBadge(this.place);

  final SavedPlace place;
  static const size = 88.0;

  @override
  Widget build(BuildContext context) {
    final mood = place.mood;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(size * .1),
      decoration: const BoxDecoration(
          color: AppColors.primaryLight, shape: BoxShape.circle),
      child: mood != null
          ? Image.asset(mood.asset, fit: BoxFit.contain, cacheWidth: 260)
          : Icon(categoryIcon(place.category),
              size: 36, color: AppColors.primaryAction),
    );
  }
}

Future<void> showSavedPlaceSheet(BuildContext context, SavedPlace place,
        {Future<void> Function()? onShare}) =>
    showAppSheet<void>(
      context,
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: _PlaceBadge(place)),
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
                if (place.mood case final mood?) mood.label,
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
