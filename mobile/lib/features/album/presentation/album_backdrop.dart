import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// The Album scene behind library and album pages: teal sky fading into
/// mint, static while content scrolls. The asset slot holds the floating
/// Nudaeng of "Background 2"; without it (or while it loads) the plain
/// colours remain, Background Mint at the bottom.
class AlbumBackdrop extends StatelessWidget {
  const AlbumBackdrop({super.key, this.showFigure = false});

  /// The large faint Nudaeng; never next to another Nudaeng on screen.
  final bool showFigure;

  static const figureAsset = 'assets/Deimage/album-bg-nudaeng.png';

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0, .55, 1],
            colors: [
              AppColors.primaryLight,
              AppColors.background,
              AppColors.background,
            ],
          ),
        ),
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: AnimatedOpacity(
              opacity: showFigure ? .5 : 0,
              duration: const Duration(milliseconds: 300),
              child: Align(
                alignment: const Alignment(0, .5),
                child: FractionallySizedBox(
                  widthFactor: .62,
                  child: Image.asset(
                    figureAsset,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
