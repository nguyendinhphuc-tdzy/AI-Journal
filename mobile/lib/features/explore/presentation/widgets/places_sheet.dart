import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../social/data/my_shares.dart';
import 'map_marker_art.dart';
import 'place_sheets.dart';

abstract final class PlacesSheetText {
  static const title = 'Những nơi của bạn';
  static const emptyTitle = 'Lưu góc nhỏ đầu tiên của bạn';
  static const emptyBody =
      'Một quán quen, một góc học bài hay một chỗ để thở chậm lại.';
  static const addLabel = 'Lưu một nơi';
  static const noMatch = 'Chưa có nơi nào khớp bộ lọc.';
  static const clearFilters = 'Bỏ lọc';
  static const detailsLabel = 'Xem chi tiết';
  static const community = 'Cộng đồng';
  static const communityHint = 'Hiện trạm cộng đồng ẩn danh';
  static String savedTab(int n) => 'Đã lưu · $n';
  static String sharedTab(int n) => 'Đã chia sẻ · $n';
  static const sharingNow = 'Đang chia sẻ';
  static const sharedEmpty =
      'Bạn chưa chia sẻ kỷ niệm nào. Vào Kỷ niệm, mở một kỷ niệm rồi chọn '
      '"Chia sẻ trong 24 giờ"; bài sẽ được giữ ở đây sau khi hết hạn.';
  static const ended = 'Đã hết hạn';
  static const revoked = 'Đã gỡ';

  /// "Còn 5 giờ", "Còn 20 phút".
  static String left(DateTime expiresAt, DateTime now) {
    final rest = expiresAt.difference(now);
    if (rest.inHours >= 1) return 'Còn ${rest.inHours} giờ';
    return 'Còn ${rest.inMinutes.clamp(1, 59)} phút';
  }

  /// "Hôm nay", "Hôm qua" or the date.
  static String day(DateTime at, DateTime now) {
    final t = at.toLocal();
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(t.year, t.month, t.day))
        .inDays;
    String two(int n) => n.toString().padLeft(2, '0');
    return days == 0
        ? 'Hôm nay'
        : days == 1
            ? 'Hôm qua'
            : '${two(t.day)}/${two(t.month)}/${t.year}';
  }
}

/// "Những nơi của bạn": a sheet pulled up from the bottom of the map, at
/// three heights. Collapsed: the title and how many places are saved. Half:
/// the places as cards (Nudaeng, what it is for, the mood, a short note).
/// Full: the whole list. With nothing saved: a small Nudaeng and an
/// invitation to save the first place. The chosen place's card is
/// highlighted, its note shown whole, with its actions.
class PlacesSheet extends StatelessWidget {
  const PlacesSheet({
    super.key,
    required this.controller,
    required this.collapsed,
    required this.places,
    required this.savedCount,
    required this.selectedId,
    required this.cardKeys,
    required this.community,
    required this.onCommunity,
    required this.onSelect,
    required this.onDetails,
    required this.onShare,
    required this.onAdd,
    required this.onClearFilters,
    this.shares,
    this.sharedView = false,
    this.onView,
    this.onSelectShare,
    this.selectedShareId,
  });

  /// The user's shared posts (newest first); null without an account, and
  /// then there are no tabs.
  final List<MyShare>? shares;

  /// "Đã chia sẻ" chosen: the shared posts instead of saved places.
  final bool sharedView;
  final ValueChanged<bool>? onView;
  final ValueChanged<MyShare>? onSelectShare;
  final String? selectedShareId;

  final DraggableScrollableController controller;

  /// The collapsed height, as a part of the room it is in.
  final double collapsed;

  /// The places the filters let through, and how many are saved in all.
  final List<SavedPlace> places;
  final int savedCount;
  final String? selectedId;

  /// One per place, to bring the chosen card into view.
  final Map<String, GlobalKey> cardKeys;

  final bool community;
  final ValueChanged<bool> onCommunity;
  final ValueChanged<SavedPlace> onSelect;
  final ValueChanged<SavedPlace> onDetails;
  final ValueChanged<SavedPlace> onShare;
  final VoidCallback onAdd;
  final VoidCallback onClearFilters;

  /// Half open and fully open, as parts of the room.
  static const half = .45;
  static const full = .88;

  /// The same list every build: a new one would count as a change and stop
  /// a drag under way.
  static const _snaps = [half];

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
        controller: controller,
        initialChildSize: collapsed,
        minChildSize: collapsed,
        maxChildSize: full,
        snap: true,
        snapSizes: _snaps,
        builder: (context, scroll) => DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: _radius,
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: .12),
                blurRadius: 18,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          // Nothing inside ever shows past the rounded top.
          child: ClipRRect(
            borderRadius: _radius,
            child: CustomScrollView(
              controller: scroll,
              slivers: [
                // The title stays; the cards scroll under it, never past it.
                SliverPersistentHeader(
                    pinned: true, delegate: _HeaderDelegate(this)),
                if (shares != null)
                  SliverToBoxAdapter(
                    child: _Tabs(
                      saved: savedCount,
                      shared: shares!.length,
                      sharedView: sharedView,
                      onView: onView,
                    ),
                  ),
                if (sharedView && shares != null)
                  ..._sharedSlivers(context)
                else if (savedCount == 0)
                  SliverToBoxAdapter(child: _Empty(onAdd: onAdd))
                else if (places.isEmpty)
                  SliverToBoxAdapter(
                      child: _NoMatch(onClearFilters: onClearFilters))
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
                    sliver: SliverList.separated(
                      itemCount: places.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, i) {
                        final place = places[i];
                        return _PlaceCard(
                          key: cardKeys[place.id],
                          place: place,
                          selected: place.id == selectedId,
                          onTap: () => place.id == selectedId
                              ? onDetails(place)
                              : onSelect(place),
                          onDetails: () => onDetails(place),
                          onShare: () => onShare(place),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      );

  static const _radius = BorderRadius.vertical(top: Radius.circular(24));

  /// The shared posts: those still on first, then the rest by day.
  List<Widget> _sharedSlivers(BuildContext context) {
    final now = DateTime.now();
    final all = shares!;
    if (all.isEmpty) {
      return [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
            child: Text(PlacesSheetText.sharedEmpty,
                textAlign: TextAlign.center, style: AppText.bodySecondary),
          ),
        ),
      ];
    }
    final rows = <Object>[];
    final active = [for (final s in all) if (s.isActive(now)) s];
    if (active.isNotEmpty) rows..add(PlacesSheetText.sharingNow)..addAll(active);
    String? day;
    for (final s in all) {
      if (s.isActive(now)) continue;
      final d = PlacesSheetText.day(s.sharedAt, now);
      if (d != day) rows.add(d);
      day = d;
      rows.add(s);
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
        sliver: SliverList.builder(
          itemCount: rows.length,
          itemBuilder: (context, i) {
            final row = rows[i];
            if (row is String) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xs, AppSpacing.sm, 0, AppSpacing.xs),
                child: Text(row,
                    style: AppText.meta.copyWith(
                        fontWeight: FontWeight.w600,
                        color: row == PlacesSheetText.sharingNow
                            ? const Color(0xFFB07A1E)
                            : AppColors.textSecondary)),
              );
            }
            final share = row as MyShare;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ShareRow(
                key: ValueKey('my-share-${share.id}'),
                share: share,
                now: now,
                selected: share.id == selectedShareId,
                onTap: () => onSelectShare?.call(share),
              ),
            );
          },
        ),
      ),
    ];
  }
}

/// "Đã lưu · n" | "Đã chia sẻ · m".
class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.saved,
    required this.shared,
    required this.sharedView,
    required this.onView,
  });

  final int saved;
  final int shared;
  final bool sharedView;
  final ValueChanged<bool>? onView;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
        child: SegmentedButton<bool>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor: AppColors.primaryLight,
            selectedForegroundColor: AppColors.primaryAction,
            foregroundColor: AppColors.textSecondary,
            side: const BorderSide(color: AppColors.border),
          ),
          segments: [
            ButtonSegment(
                value: false,
                icon: const Icon(Icons.bookmark_outline_rounded, size: 18),
                label: Text(PlacesSheetText.savedTab(saved))),
            ButtonSegment(
                value: true,
                icon: const Icon(Icons.photo_outlined, size: 18),
                label: Text(PlacesSheetText.sharedTab(shared))),
          ],
          selected: {sharedView},
          onSelectionChanged: onView == null ? null : (v) => onView!(v.single),
        ),
      );
}

/// One shared post: its photo small, what and where, and whether it is
/// still on.
class _ShareRow extends StatelessWidget {
  const _ShareRow({
    super.key,
    required this.share,
    required this.now,
    required this.selected,
    required this.onTap,
  });

  final MyShare share;
  final DateTime now;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = share.isActive(now);
    final path = share.photoPath;
    final state = active
        ? PlacesSheetText.left(share.expiresAt, now)
        : share.revokedAt != null
            ? PlacesSheetText.revoked
            : PlacesSheetText.ended;
    return Material(
      color: selected ? AppColors.primaryLight : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(
            color: active
                ? const Color(0xFFD99A2B).withValues(alpha: .55)
                : AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox.square(
                dimension: 56,
                child: path == null
                    ? const ColoredBox(
                        color: AppColors.background,
                        child: Icon(Icons.photo_outlined,
                            color: AppColors.textSecondary))
                    : Opacity(
                        opacity: active ? 1 : .6,
                        child: Image.file(File(path),
                            fit: BoxFit.cover,
                            cacheWidth: 168,
                            errorBuilder: (_, __, ___) => const ColoredBox(
                                color: AppColors.background,
                                child: Icon(Icons.photo_outlined,
                                    color: AppColors.textSecondary))),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(share.title ?? share.placeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.label.copyWith(
                          color: active
                              ? AppColors.textPrimary
                              : AppColors.textSecondary)),
                  Text(share.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.meta),
                  Text('$state · ${share.placeLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.meta.copyWith(
                          fontSize: 12.5,
                          color: active
                              ? const Color(0xFFB07A1E)
                              : AppColors.textSecondary)),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  _HeaderDelegate(this.sheet);

  final PlacesSheet sheet;

  /// The grip and the title row; a little room under them.
  static const height = 80.0;

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrink, bool overlaps) =>
      DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          // A hairline once cards scroll under it.
          border: overlaps
              ? const Border(bottom: BorderSide(color: AppColors.border))
              : null,
        ),
        child: _Header(sheet: sheet),
      );

  @override
  bool shouldRebuild(_HeaderDelegate old) => true;
}

/// The grip, the title with the count, and the community switch: all that
/// shows when collapsed.
class _Header extends StatelessWidget {
  const _Header({required this.sheet});

  final PlacesSheet sheet;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
        child: Column(children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 6),
          Row(children: [
            // The title takes the room first; the switch keeps its own.
            Expanded(
              child: Row(children: [
                Flexible(
                  child: Semantics(
                    header: true,
                    child: Text(PlacesSheetText.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.label.copyWith(fontSize: 17)),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: const ShapeDecoration(
                      color: AppColors.primaryLight, shape: StadiumBorder()),
                  child: Text('${sheet.savedCount}',
                      style: AppText.meta.copyWith(
                          color: AppColors.primaryAction,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
            Semantics(
              label: PlacesSheetText.communityHint,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.volunteer_activism_outlined,
                    size: 18, color: AppColors.primaryAction),
                const SizedBox(width: 4),
                Text(PlacesSheetText.community,
                    style: AppText.meta.copyWith(color: AppColors.textPrimary)),
                Switch(
                  value: sheet.community,
                  onChanged: sheet.onCommunity,
                  activeTrackColor: AppColors.primaryAction,
                  activeThumbColor: AppColors.surface,
                  inactiveTrackColor: AppColors.background,
                  inactiveThumbColor: AppColors.textSecondary,
                  trackOutlineColor:
                      const WidgetStatePropertyAll(AppColors.border),
                ),
              ]),
            ),
          ]),
        ]),
      );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
        child: Column(children: [
          ExcludeSemantics(
            child: Image.asset(PinArt.neutral,
                width: 56, height: 56, cacheWidth: 180),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(PlacesSheetText.emptyTitle,
              textAlign: TextAlign.center, style: AppText.label),
          const SizedBox(height: AppSpacing.xs),
          const Text(PlacesSheetText.emptyBody,
              textAlign: TextAlign.center, style: AppText.meta),
          const SizedBox(height: 12),
          AppPrimaryButton(
            label: PlacesSheetText.addLabel,
            icon: Icons.add_location_alt_outlined,
            compact: true,
            onPressed: onAdd,
          ),
        ]),
      );
}

class _NoMatch extends StatelessWidget {
  const _NoMatch({required this.onClearFilters});

  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
        child: Row(children: [
          const Expanded(
              child: Text(PlacesSheetText.noMatch, style: AppText.meta)),
          TextButton(
            onPressed: onClearFilters,
            style:
                TextButton.styleFrom(foregroundColor: AppColors.primaryAction),
            child: const Text(PlacesSheetText.clearFilters),
          ),
        ]),
      );
}

/// One saved place: its Nudaeng (or what it is for), name, what it is for
/// and the mood, a short note. Chosen: Primary Light, an outline, the note
/// whole and its actions.
class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    super.key,
    required this.place,
    required this.selected,
    required this.onTap,
    required this.onDetails,
    required this.onShare,
  });

  final SavedPlace place;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDetails;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final mood = place.mood;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      selected: selected,
      child: AnimatedContainer(
        duration: reduced ? Duration.zero : const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.input),
          border: Border.all(
              color: selected ? AppColors.primaryAction : Colors.transparent,
              width: 1.5),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.input),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 52,
                      height: 52,
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: AppColors.surface, shape: BoxShape.circle),
                      child: mood != null
                          ? Image.asset(mood.asset, cacheWidth: 160)
                          : Icon(categoryIcon(place.category),
                              color: AppColors.primaryAction),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(place.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.label),
                          const SizedBox(height: 2),
                          Text(
                              [
                                categoryName(place.category),
                                if (mood != null) mood.label,
                              ].join(' · '),
                              style: AppText.meta
                                  .copyWith(color: AppColors.primaryAction)),
                          if (place.note.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(place.note,
                                maxLines: selected ? 4 : 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.meta),
                          ],
                        ],
                      ),
                    ),
                  ]),
                  if (selected) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      TextButton(
                        onPressed: onDetails,
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            minimumSize: const Size(48, 40)),
                        child: const Text(PlacesSheetText.detailsLabel),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      FilledButton.icon(
                        onPressed: onShare,
                        icon: const Icon(Icons.send_outlined, size: 18),
                        label: const Text(PlaceSheetText.shareLabel),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryAction,
                          minimumSize: const Size(48, 40),
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
