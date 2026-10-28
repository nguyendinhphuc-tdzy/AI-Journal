import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_ui.dart';
import '../data/album_theme.dart';
import 'album_cover.dart';

/// Pieces shared by the album forms (A02 create, A03 settings), so both read
/// as one design: paper sections, the same cover preview, theme grid, lock
/// card and messages.

/// A sheet of paper grouping one part of a form.
class AlbumFormSection extends StatelessWidget {
  const AlbumFormSection({super.key, this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    // A Material, so list tiles inside show their ink.
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Text(title, style: AlbumFormText.section),
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// The cover as it will look, static; a theme change crossfades (180 ms),
/// reduced motion swaps at once. Sits on mint so the folder reads as an
/// object, not a sticker on paper.
class AlbumCoverPreview extends StatelessWidget {
  const AlbumCoverPreview({super.key, required this.themeId});

  final String themeId;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: SizedBox(
            width: 168,
            child: ExcludeSemantics(
              child: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                child: AlbumCover(
                    key: ValueKey(themeId), themeId: themeId, locked: false),
              ),
            ),
          ),
        ),
      );
}

/// All six themes at once, three per row: thumbnail and name. Selected:
/// Primary Light fill, Primary outline and a check, read out as selected.
class AlbumThemeGrid extends StatelessWidget {
  const AlbumThemeGrid({
    super.key,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final String selected;
  final bool enabled;
  final ValueChanged<String> onSelected;

  static const gap = AppSpacing.sm;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final width = (box.maxWidth - gap * 2) / 3;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final theme in AlbumTheme.all)
              SizedBox(
                width: width,
                child: _ThemeTile(
                  theme: theme,
                  selected: theme.id == selected,
                  onTap: enabled ? () => onSelected(theme.id) : null,
                ),
              ),
          ],
        );
      });
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile(
      {required this.theme, required this.selected, required this.onTap});

  final AlbumTheme theme;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        label: 'Bìa ${theme.label}',
        excludeSemantics: true,
        child: Material(
          color: selected ? AppColors.primaryLight : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
              child: Column(children: [
                Stack(clipBehavior: Clip.none, children: [
                  AlbumCoverThumbnail(themeId: theme.id),
                  if (selected)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryAction,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded,
                            size: 14, color: AppColors.surface),
                      ),
                    ),
                ]),
                const SizedBox(height: 6),
                Text(theme.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AlbumFormText.chip),
              ]),
            ),
          ),
        ),
      );
}

/// "Khóa album": the switch, what the lock does (and does not), and, on A03,
/// the album's current state as text and icon. Unsupported devices get the
/// reason in full-contrast text, never a greyed-out riddle.
class AlbumLockCard extends StatelessWidget {
  const AlbumLockCard({
    super.key,
    required this.title,
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.help,
    this.currentlyLocked,
  });

  final String title;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final String help;

  /// The saved state (A03); null hides the status line.
  final bool? currentlyLocked;

  static const lockedStatus = 'Đang khóa';
  static const unlockedStatus = 'Chưa khóa';
  static const notEncrypted =
      'Khóa chỉ chặn việc mở album trong app, không mã hóa ảnh và ghi chú.';

  @override
  Widget build(BuildContext context) {
    final current = currentlyLocked;
    return AlbumFormSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(title, style: AlbumFormText.section),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(help, style: AlbumFormText.body),
            ),
            value: value,
            onChanged: enabled ? onChanged : null,
            activeTrackColor: AppColors.primaryAction,
            activeThumbColor: AppColors.surface,
          ),
          if (current != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: _StatusPill(locked: current),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          const Divider(height: AppSpacing.md, color: AppColors.border),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.info_outline_rounded,
                    size: 16, color: AppColors.textPrimary),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(notEncrypted, style: AlbumFormText.note)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.locked});

  final bool locked;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(locked ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
              size: 16, color: AppColors.textPrimary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Hiện tại: ${locked ? AlbumLockCard.lockedStatus : AlbumLockCard.unlockedStatus}',
              style: AlbumFormText.bodyStrong,
            ),
          ),
        ]),
      );
}

/// A short message next to the action it is about, read out when it appears.
class AlbumFormMessage extends StatelessWidget {
  const AlbumFormMessage(this.text, {super.key, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon ?? Icons.info_outline_rounded,
                  size: 20, color: AppColors.textPrimary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(text, style: AlbumFormText.body)),
            ],
          ),
        ),
      );
}

/// Full-width primary action: the app's [AppPrimaryButton] (56 high, pill,
/// a spinner in place of the label while [busy], same size; taps ignored by
/// the caller).
class AlbumPrimaryButton extends StatelessWidget {
  const AlbumPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) =>
      AppPrimaryButton(label: label, onPressed: onPressed, busy: busy);
}

abstract final class AlbumFormText {
  static const title = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppColors.textPrimary,
  );
  static const section = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.5,
    color: AppColors.textPrimary,
  );
  static const body = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 14,
    height: 20 / 14,
    color: AppColors.textPrimary,
  );
  static const bodyStrong = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 20 / 14,
    color: AppColors.textPrimary,
  );
  static const note = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 13,
    height: 18 / 13,
    color: AppColors.textPrimary,
  );
  static const chip = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 18 / 13,
    color: AppColors.textPrimary,
  );
  static const button = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.5,
  );
}
