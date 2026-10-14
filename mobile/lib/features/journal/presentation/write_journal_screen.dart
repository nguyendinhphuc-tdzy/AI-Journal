import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../navigation/app_shell.dart';
import '../../../navigation/custom_bottom_navigation.dart';
import 'ai_reflection_screen.dart';

class WriteJournalScreen extends StatefulWidget {
  const WriteJournalScreen({super.key});

  @override
  State<WriteJournalScreen> createState() => _WriteJournalScreenState();
}

class _WriteJournalScreenState extends State<WriteJournalScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openReflection() {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiReflectionScreen(
          journalContent: _controller.text.trim(),
        ),
      ),
    );
  }

  void _selectTab(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => AppShell(initialIndex: index)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      extendBody: true,
      backgroundColor: AppColors.background,
      bottomNavigationBar: CustomBottomNavigation(
        selectedIndex: 0,
        onDestinationSelected: _selectTab,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/background_journal.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: LayoutBuilder(builder: (context, cardConstraints) {
                final compact = cardConstraints.maxHeight < 300;
                return Column(
                  children: [
                    Row(children: [
                      IconButton(
                        tooltip: 'Close',
                        icon: const Icon(Icons.close),
                        color: AppColors.textPrimary,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Daily Reflection',
                            textAlign: TextAlign.center,
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ]),
                    SizedBox(height: compact ? 4 : 12),
                    ConstrainedBox(
                      constraints:
                          BoxConstraints(maxHeight: compact ? 44 : 100),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: cardConstraints.maxWidth,
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  width: 4,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryDark,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'What do you notice about your mood today?',
                                    style: textTheme.titleMedium?.copyWith(
                                      color: AppColors.textPrimary,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 4 : 8),
                    Expanded(
                      flex: 3,
                      child: LayoutBuilder(builder: (context, constraints) {
                        // Leave typing space when the keyboard reduces height.
                        final mascotSize = math.min(
                            120.0,
                            math.min(constraints.maxWidth,
                                constraints.maxHeight * 0.4));
                        return Stack(
                          children: [
                            Positioned.fill(
                              child: Column(children: [
                                Expanded(
                                  child: TextField(
                                    controller: _controller,
                                    expands: true,
                                    minLines: null,
                                    maxLines: null,
                                    keyboardType: TextInputType.multiline,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    textAlignVertical: TextAlignVertical.top,
                                    cursorColor: AppColors.primaryDark,
                                    style: textTheme.bodyLarge?.copyWith(
                                      color: AppColors.textPrimary,
                                      height: 1.5,
                                    ),
                                    onTapOutside: (_) => FocusManager
                                        .instance.primaryFocus
                                        ?.unfocus(),
                                    decoration: const InputDecoration(
                                      isCollapsed: true,
                                      hintText: 'Start writing...',
                                      hintStyle: TextStyle(
                                          color: AppColors.textSecondary),
                                      filled: false,
                                      fillColor: Colors.transparent,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                                SizedBox(height: mascotSize),
                              ]),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              width: mascotSize,
                              height: mascotSize,
                              child: IgnorePointer(
                                child: Semantics(
                                  label: 'Nudaeng, reading',
                                  child: ColoredBox(
                                    color: Colors.transparent,
                                    child: ColorFiltered(
                                      // Remove near-white pixels, including white
                                      // details inside the mascot, as on Home.
                                      colorFilter: const ColorFilter.matrix([
                                        // dart format off
                                        1, 0, 0, 0, 0,
                                        0, 1, 0, 0, 0,
                                        0, 0, 1, 0, 0,
                                        -4.252, -14.304, -1.444, 20, 0,
                                        // dart format on
                                      ]),
                                      child: Image.asset(
                                        'assets/images/docsach.gif',
                                        width: 120,
                                        height: 120,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                    SizedBox(height: compact ? 4 : 8),
                    _buildToolbar(),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Attachment flows are not implemented in this UI prototype.
        const Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            tooltip: 'Attach file (coming soon)',
            onPressed: null,
            disabledColor: AppColors.textSecondary,
            icon: Icon(Icons.attach_file),
          ),
          IconButton(
            tooltip: 'Add image (coming soon)',
            onPressed: null,
            disabledColor: AppColors.textSecondary,
            icon: Icon(Icons.image_outlined),
          ),
        ]),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              OutlinedButton(
                onPressed: _openReflection,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryDark,
                  side: const BorderSide(color: AppColors.primaryDark),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 48),
                ),
                child: const Text('Finish'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _openReflection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.surface,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 48),
                ),
                child: const Text('✨ Go Deeper'),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}
