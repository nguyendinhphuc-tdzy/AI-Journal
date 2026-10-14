import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/mascot_placeholder.dart';
import '../home/presentation/widgets/primary_button.dart';
import '../streak/streak_screen.dart';

class ReflectionScreen extends StatelessWidget {
  const ReflectionScreen({super.key, required this.journalContent});

  final String journalContent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text("✨ Nudaeng's thought...",
            style: Theme.of(context).textTheme.titleMedium),
      ),
      body: SafeArea(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 900),
          curve: Curves.easeOut,
          builder: (context, opacity, child) =>
              Opacity(opacity: opacity, child: child),
          child: CustomScrollView(slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Sample insight until the reflection API is integrated.
                    Text(
                      '“It sounds like you found a lot of comfort in simple moments today...”',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontSize: 28,
                            fontStyle: FontStyle.italic,
                            height: 1.5,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 48),
                    Semantics(
                      label: 'Nudaeng, happy',
                      excludeSemantics: true,
                      child: const MascotPlaceholder(
                          state: MascotState.happy, size: 120),
                    ),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Album persistence is not connected in this UI prototype.
            const Tooltip(
              message: 'Save to Album is coming soon',
              child: TextButton(
                onPressed: null,
                child: Text('Save to Album'),
              ),
            ),
            const SizedBox(height: 8),
            PrimaryButton(
              label: 'Continue',
              onPressed: () => Navigator.of(context).pushReplacement(
                StreakScreen.route(),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
