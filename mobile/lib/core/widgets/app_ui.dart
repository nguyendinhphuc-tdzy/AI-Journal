import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// Building blocks shared by every tab, so Home, Study, Album and their
/// flows look like one app: the page header, section headers, cards,
/// buttons, pills and sheets. Sizes follow [AppText], [AppSpacing] and
/// [AppRadius]; colours follow [AppColors] (primary actions in
/// [AppColors.primaryAction]).

/// The top of a tab or screen: a large title on the left (with an optional
/// "?" that explains the page in a sheet), an optional line under it, and
/// actions on the right.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.help,
    this.trailing = const [],
    this.titleStyle = AppText.pageTitle,
    this.subtitleStyle = AppText.meta,
  });

  final String title;
  final String? subtitle;

  /// [AppText.pageTitle] by default.
  final TextStyle titleStyle;

  /// [AppText.meta] by default; darker over a picture, for contrast.
  final TextStyle subtitleStyle;

  /// What the page is for, opened from the "?" next to the title.
  final String? help;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TitleWithHelp(title: title, style: titleStyle, help: help),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle, style: subtitleStyle),
        ],
      ],
    );
    final actions = [
      for (final action in trailing) ...[
        const SizedBox(width: AppSpacing.sm),
        action,
      ],
    ];
    // Large text: the actions get their own row above the title instead of
    // squeezing it.
    if (trailing.isNotEmpty &&
        MediaQuery.textScalerOf(context).scale(16) >= 24) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.end,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: trailing,
          ),
          const SizedBox(height: AppSpacing.sm),
          heading,
        ],
      );
    }
    return Row(children: [Expanded(child: heading), ...actions]);
  }
}

/// A section inside a page, with an optional "?" and an action on the right.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader(
      {super.key, required this.title, this.help, this.action});

  final String title;
  final String? help;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: _TitleWithHelp(
              title: title, style: AppText.sectionTitle, help: help),
        ),
        if (action case final action?) action,
      ]);
}

class _TitleWithHelp extends StatelessWidget {
  const _TitleWithHelp(
      {required this.title, required this.style, required this.help});

  final String title;
  final TextStyle style;
  final String? help;

  @override
  Widget build(BuildContext context) {
    final help = this.help;
    // Its own node, so actions next to it stay separate buttons.
    final text = Semantics(
        header: true, container: true, child: Text(title, style: style));
    if (help == null) return text;
    return Row(children: [
      Flexible(child: text),
      IconButton(
        tooltip: 'Giới thiệu $title',
        onPressed: () => showAppSheet<void>(
          context,
          builder: (sheet) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: AppText.sectionTitle),
              const SizedBox(height: AppSpacing.md),
              Text(help, style: AppText.body),
              const SizedBox(height: AppSpacing.xl),
              AppPrimaryButton(
                  label: 'Đã hiểu', onPressed: () => Navigator.pop(sheet)),
            ],
          ),
        ),
        icon: const Icon(Icons.help_outline_rounded,
            color: AppColors.textSecondary),
      ),
    ]);
  }
}

/// A card: Surface, radius 20, a thin border, 20 inside. With [art], a
/// full-width illustration panel sits above the content (as Study's
/// challenge card). With [onTap], the whole card is one target.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.art,
    this.onTap,
    this.color = AppColors.surface,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  final Widget child;
  final Widget? art;
  final VoidCallback? onTap;
  final Color color;
  final EdgeInsetsGeometry padding;

  static const shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppRadius.card)),
    side: BorderSide(color: AppColors.border),
  );

  @override
  Widget build(BuildContext context) {
    final art = this.art;
    Widget content = Padding(padding: padding, child: child);
    if (art != null) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [art, content],
      );
    }
    // One node per card: read as a unit, apart from its neighbours.
    return Semantics(
      container: true,
      child: Material(
        color: color,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}

/// The small line above a card's title, optionally with an icon
/// ("Challenge gợi ý", "Gợi ý từ AI").
class AppEyebrow extends StatelessWidget {
  const AppEyebrow(this.text, {super.key, this.icon, this.accent = false});

  final String text;
  final IconData? icon;

  /// In the action colour instead of the secondary text colour.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ? AppColors.primaryAction : AppColors.textSecondary;
    final icon = this.icon;
    return Row(children: [
      if (icon != null) ...[
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.sm),
      ],
      Flexible(child: Text(text, style: AppText.meta.copyWith(color: color))),
    ]);
  }
}

/// The main action of a screen or card: filled in [AppColors.primaryAction],
/// 56 high (48 when [compact]), pill-shaped. [busy] shows a spinner in place
/// of the label at the same size; the caller ignores taps meanwhile.
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 48.0 : 56.0;
    final icon = this.icon;
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primaryAction,
        foregroundColor: AppColors.surface,
        minimumSize: Size(0, height),
        // Height comes from the minimum size; a label that wraps adds
        // only its own lines.
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(height / 2)),
        textStyle: AppText.label,
      ),
      child: busy
          ? Semantics(
              label: label,
              child: const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: AppColors.surface),
              ),
            )
          : _Label(label: label, icon: icon),
    );
  }
}

/// A second action next to or under the primary: outlined in the action
/// colour, same size and shape as [AppPrimaryButton].
class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 48.0 : 56.0;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        minimumSize: Size(0, height),
        // Height comes from the minimum size; a label that wraps adds
        // only its own lines.
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        side: BorderSide(
            color:
                onPressed == null ? AppColors.border : AppColors.primaryAction),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(height / 2)),
        textStyle: AppText.label,
      ),
      child: _Label(label: label, icon: icon),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.label, required this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    final text = Text(label, textAlign: TextAlign.center);
    if (icon == null) return text;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 20),
      const SizedBox(width: AppSpacing.sm),
      Flexible(child: text),
    ]);
  }
}

/// A small rounded pill with an icon and a label, e.g. the streak on Home.
/// Tappable when [onTap] is given (48 high either way).
class AppPill extends StatelessWidget {
  const AppPill({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.semanticLabel,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// Read instead of [label] when the short text needs words around it.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        button: onTap != null,
        label: semanticLabel ?? label,
        excludeSemantics: true,
        child: _pill(),
      );

  Widget _pill() => Material(
        color: AppColors.surface,
        shape: const StadiumBorder(side: BorderSide(color: AppColors.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 20, color: AppColors.primaryAction),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.label.copyWith(fontSize: 14)),
                ),
              ]),
            ),
          ),
        ),
      );
}

/// A round icon button on Surface with a border (profile, close on art).
class AppIconAction extends StatelessWidget {
  const AppIconAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.surface,
        shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon, color: AppColors.textPrimary),
        ),
      );
}

/// The app's bottom sheet: Surface, top radius 28, 35 % dim, 24 inside,
/// above the safe area. As tall as its content (up to the screen) and
/// scrolls when that does not fit, e.g. a phone held sideways. Slides up in 300 ms (easeOutCubic) and closes in
/// 220 ms (easeInOut), without bounce; with reduced motion a 120 ms fade.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final reduced = MediaQuery.disableAnimationsOf(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    barrierColor: Colors.black.withValues(alpha: .35),
    shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.modal))),
    sheetAnimationStyle: reduced
        ? const AnimationStyle(
            duration: Duration(milliseconds: 120),
            reverseDuration: Duration(milliseconds: 120))
        : const AnimationStyle(
            duration: Duration(milliseconds: 300),
            reverseDuration: Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInOut),
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.md),
        child: Builder(builder: builder),
      ),
    ),
  );
}
