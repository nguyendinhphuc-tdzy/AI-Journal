import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../onboarding/data/onboarding_scope.dart';
import '../data/analysis_archive.dart';
import '../data/journal_entry.dart';
import 'ai_reflection_screen.dart';
import 'sentence_case.dart';

/// Under an entry in a list: the feeling its kept AI analysis named
/// ("✦ Bình yên"); a tap opens that analysis again. Nothing when the entry
/// has none. Follows the archive, so a new analysis shows at once.
class KeptAnalysisChip extends StatefulWidget {
  const KeptAnalysisChip(
      {super.key, required this.entry, this.padding = EdgeInsets.zero});

  final JournalEntry entry;

  /// Around the chip, only when there is one: no gap under an entry
  /// without an analysis.
  final EdgeInsetsGeometry padding;

  static const tooltip = 'Xem phân tích AI';

  /// Opens [saved], kept for [entry], to read again.
  static void open(
          BuildContext context, JournalEntry entry, SavedAnalysis saved) =>
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AiReflectionScreen.review(
            journalContent: entry.body,
            saved: saved,
            entry: entry,
          ),
        ),
      );

  @override
  State<KeptAnalysisChip> createState() => _KeptAnalysisChipState();
}

class _KeptAnalysisChipState extends State<KeptAnalysisChip> {
  SavedAnalysis? _saved;
  String? _userId;

  @override
  void initState() {
    super.initState();
    AnalysisArchive.changes.addListener(_load);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _userId = OnboardingScope.maybeOf(context)?.userId;
    _load();
  }

  @override
  void didUpdateWidget(KeptAnalysisChip old) {
    super.didUpdateWidget(old);
    if (old.entry.id != widget.entry.id) _load();
  }

  @override
  void dispose() {
    AnalysisArchive.changes.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final id = widget.entry.id;
    try {
      final saved = (await AnalysisArchive.open(userId: _userId)).of(id);
      if (mounted && id == widget.entry.id) setState(() => _saved = saved);
    } catch (_) {
      // Not shown is better than an error in a list.
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = _saved;
    if (saved == null) return const SizedBox.shrink();
    final feeling = sentenceCase(saved.analysis.emotion);
    final chip = Semantics(
      button: true,
      label: '${KeptAnalysisChip.tooltip}: $feeling',
      excludeSemantics: true,
      child: Material(
        color: AppColors.primaryLight,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => KeptAnalysisChip.open(context, widget.entry, saved),
          child: ConstrainedBox(
            // A finger's height, though it looks small.
            constraints: const BoxConstraints(minHeight: 32),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.auto_awesome,
                    size: 14, color: AppColors.primaryAction),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    feeling,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.meta.copyWith(
                        color: AppColors.primaryAction,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
    return Padding(
      padding: widget.padding,
      child: Align(alignment: Alignment.centerLeft, child: chip),
    );
  }
}
