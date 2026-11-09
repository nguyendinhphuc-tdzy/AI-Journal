import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/app_ui.dart';
import '../data/journal_entry.dart';
import '../data/journal_mood.dart';
import '../data/journal_repository.dart';
import '../journal_scope.dart';
import '../../sound/app_sound.dart';
import '../../onboarding/data/onboarding_scope.dart';
import '../data/analysis_archive.dart';
import '../data/api_ai_service.dart';
import '../data/cloud_ai_api.dart';
import '../data/cloud_analysis_sync.dart';
import 'delete_entry_dialog.dart';
import 'kept_analysis_chip.dart';
import 'write_journal_screen.dart';

/// Every saved entry, newest first, grouped by month, to read or keep
/// writing. Search finds words with or without Vietnamese accents; the
/// chips keep one mood (only moods that were picked are offered).
class JournalListScreen extends StatefulWidget {
  const JournalListScreen({super.key});

  static const title = 'Nhật ký của bạn';
  static const deleteTooltip = 'Xóa bài viết';

  /// An entry's first line, as its title, and the rest on one line.
  static (String, String) summary(JournalEntry entry) {
    final lines = [
      for (final line in entry.body.split('\n'))
        if (line.trim().isNotEmpty) line.trim(),
    ];
    return (lines.firstOrNull ?? '', lines.skip(1).join(' '));
  }

  /// [text] in lower case without Vietnamese accents, so "hom nay" finds
  /// "Hôm nay".
  static String fold(String text) {
    const from = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡ'
        'ùúụủũưừứựửữỳýỵỷỹđ';
    const to = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooo'
        'uuuuuuuuuuuyyyyyd';
    final lower = text.toLowerCase();
    final out = StringBuffer();
    for (final rune in lower.runes) {
      final char = String.fromCharCode(rune);
      final at = from.indexOf(char);
      out.write(at < 0 ? char : to[at]);
    }
    return out.toString();
  }

  @override
  State<JournalListScreen> createState() => _JournalListScreenState();
}

class _JournalListScreenState extends State<JournalListScreen> {
  JournalRepository? _journals;
  late Future<List<JournalEntry>> _entries;
  String _query = '';
  JournalMood? _mood;

  @override
  void initState() {
    super.initState();
    // The notebook opened.
    AppSound.instance.play(SoundCue.bookOpen);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final journals = JournalScope.of(context);
    if (journals == _journals) return;
    _journals?.removeListener(_reload);
    _journals = journals..addListener(_reload);
    _entries = journals.entries();
    // Analyses made on another phone appear on the entries (read only).
    if (AiRemoteScope.maybeOf(context) case final ai?) {
      CloudAnalysisSync.maybeSync(CloudAiApi(ai.client),
              userId: OnboardingScope.maybeOf(context)?.userId)
          .catchError((Object _) {});
    }
  }

  /// An entry was written or changed (e.g. opened from here and edited).
  void _reload() {
    final entries = _journals!.entries();
    // A block: an arrow would hand setState the Future it assigns.
    setState(() {
      _entries = entries;
    });
  }

  @override
  void dispose() {
    _journals?.removeListener(_reload);
    super.dispose();
  }

  void _open(JournalEntry entry) => Navigator.push(context,
      MaterialPageRoute(builder: (_) => WriteJournalScreen(entry: entry)));

  void _write() => Navigator.push(
      context, MaterialPageRoute(builder: (_) => const WriteJournalScreen()));

  /// Asks first; the list reloads itself once the store changed.
  /// The entry goes, and with it the analysis kept for it.
  void _delete(JournalEntry entry) => DeleteEntryDialog.show(context,
      entry: entry, onConfirm: () async {
        // Read before the wait: this screen may be gone after it.
        final userId = context
            .getInheritedWidgetOfExactType<OnboardingScope>()
            ?.store
            .userId;
        await _journals!.delete(entry.id);
        await (await AnalysisArchive.open(userId: userId)).remove(entry.id);
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FutureBuilder<List<JournalEntry>>(
          future: _entries,
          builder: (context, snapshot) {
            final all = snapshot.data;
            return Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 12),
                child: AppPageHeader(
                  title: JournalListScreen.title,
                  subtitle: all == null
                      ? 'Đang tải…'
                      : all.isEmpty
                          ? 'Chưa có bài viết nào'
                          : '${all.length} bài viết',
                  trailing: [
                    AppIconAction(
                      icon: Icons.close_rounded,
                      tooltip: 'Đóng',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Expanded(
                child: all == null
                    ? const SizedBox.shrink()
                    : all.isEmpty
                        ? _buildEmpty()
                        : _buildList(all),
              ),
            ]);
          },
        ),
      ),
    );
  }

  Widget _buildEmpty() => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Chưa có bài nhật ký nào',
                textAlign: TextAlign.center, style: AppText.sectionTitle),
            const SizedBox(height: AppSpacing.sm),
            const Text('Những gì bạn viết sẽ được giữ lại ở đây.',
                textAlign: TextAlign.center, style: AppText.bodySecondary),
            const SizedBox(height: AppSpacing.xl),
            AppPrimaryButton(label: 'Viết bài đầu tiên', onPressed: _write),
          ]),
        ),
      );

  Widget _buildList(List<JournalEntry> all) {
    final moods = {
      for (final entry in all)
        if (entry.content.mood != null) entry.content.mood!,
    };
    final query = JournalListScreen.fold(_query.trim());
    final shown = [
      for (final entry in all)
        if ((_mood == null || entry.content.mood == _mood) &&
            (query.isEmpty ||
                JournalListScreen.fold(entry.body).contains(query)))
          entry,
    ];
    // Newest first already; one group per month.
    final months = <(int, int), List<JournalEntry>>{};
    for (final entry in shown) {
      final at = entry.createdAt.toLocal();
      months.putIfAbsent((at.year, at.month), () => []).add(entry);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl),
      children: [
        TextField(
          key: const ValueKey('journal-list-search'),
          onChanged: (value) => setState(() => _query = value),
          style: AppText.body,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Tìm trong nhật ký',
            hintStyle: AppText.bodySecondary,
            prefixIcon: const Icon(Icons.search_rounded,
                color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: _searchBorder(AppColors.border),
            enabledBorder: _searchBorder(AppColors.border),
            focusedBorder: _searchBorder(AppColors.primaryAction, width: 1.5),
          ),
        ),
        if (moods.isNotEmpty) ...[
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _MoodChip(
                label: 'Tất cả',
                selected: _mood == null,
                onTap: () => setState(() => _mood = null),
              ),
              for (final mood in JournalMood.values)
                if (moods.contains(mood)) ...[
                  const SizedBox(width: AppSpacing.sm),
                  _MoodChip(
                    label: mood.label,
                    selected: _mood == mood,
                    onTap: () =>
                        setState(() => _mood = _mood == mood ? null : mood),
                  ),
                ],
            ]),
          ),
        ],
        if (shown.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.xxl),
            child: Text('Không tìm thấy bài viết phù hợp.',
                textAlign: TextAlign.center, style: AppText.bodySecondary),
          ),
        for (final MapEntry(key: (year, month), value: entries)
            in months.entries) ...[
          Padding(
            padding: const EdgeInsets.only(
                top: AppSpacing.xl, bottom: AppSpacing.sm, left: AppSpacing.xs),
            child: Semantics(
              header: true,
              child: Text('Tháng $month/$year',
                  style:
                      AppText.label.copyWith(color: AppColors.textSecondary)),
            ),
          ),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (final (index, entry) in entries.indexed) ...[
                if (index > 0)
                  const Divider(
                      height: 1,
                      indent: AppSpacing.md + _EntryRow.dateWidth + 12,
                      color: AppColors.border),
                _EntryRow(
                  entry: entry,
                  onTap: () => _open(entry),
                  onDelete: () => _delete(entry),
                ),
              ],
            ]),
          ),
        ],
      ],
    );
  }

  static OutlineInputBorder _searchBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.input)),
        borderSide: BorderSide(color: color, width: width),
      );
}

/// One entry: the day on the left, its first line, a glimpse of the rest,
/// then the time, mood and where it was written (e.g. a Study challenge);
/// a bin on the right to delete it.
class _EntryRow extends StatelessWidget {
  const _EntryRow(
      {required this.entry, required this.onTap, required this.onDelete});

  final JournalEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  static const dateWidth = 40.0;
  static const _weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  @override
  Widget build(BuildContext context) {
    final at = entry.createdAt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    final (title, rest) = JournalListScreen.summary(entry);
    final mood = entry.content.mood;
    return InkWell(
      key: ValueKey('journal-list-entry-${entry.id}'),
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(AppSpacing.md, 14, AppSpacing.sm, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: dateWidth,
              child: Column(children: [
                Text(two(at.day), style: AppText.cardTitle),
                Text(_weekdays[at.weekday - 1], style: AppText.meta),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.label),
                  if (rest.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(rest,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.meta),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    [
                      '${two(at.hour)}:${two(at.minute)}',
                      if (mood != null) mood.label,
                      if (entry.content.source case final source?)
                        source.label,
                    ].join(' · '),
                    style:
                        AppText.meta.copyWith(color: AppColors.primaryAction),
                  ),
                  // Its AI analysis, to read again.
                  KeptAnalysisChip(
                      entry: entry, padding: const EdgeInsets.only(top: 6)),
                ],
              ),
            ),
            // The whole row opens the entry; the bin only asks to delete.
            IconButton(
              key: ValueKey('journal-list-delete-${entry.id}'),
              tooltip: JournalListScreen.deleteTooltip,
              onPressed: onDelete,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// A mood to keep: Primary Light with an outline when chosen.
class _MoodChip extends StatelessWidget {
  const _MoodChip(
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
