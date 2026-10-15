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
  final _followUpController = TextEditingController();
  final _followUpFocus = FocusNode();
  final _scrollController = ScrollController();
  bool _hasFollowUp = false;
  bool _isPaperBackground = true;

  void _goDeeper() {
    if (_hasFollowUp || _controller.text.trim().isEmpty) return;
    setState(() => _hasFollowUp = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _followUpFocus.requestFocus();
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _finishEntry() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Finished?',
                textAlign: TextAlign.center,
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(sheetContext, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black),
                    ),
                    child: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(sheetContext, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Confirm'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (!mounted || confirmed != true) return;
    _openReflection();
  }

  @override
  void dispose() {
    _controller.dispose();
    _followUpController.dispose();
    _followUpFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _openReflection() {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiReflectionScreen(
          journalContent: [
            _controller.text.trim(),
            if (_hasFollowUp) _followUpController.text.trim(),
          ].where((answer) => answer.isNotEmpty).join('\n\n'),
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
                color:
                    _isPaperBackground ? Colors.transparent : AppColors.surface,
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
                      IconButton(
                        tooltip: 'Toggle journal background',
                        icon: const Icon(Icons.palette_outlined),
                        color: AppColors.textPrimary,
                        onPressed: () => setState(() {
                          _isPaperBackground = !_isPaperBackground;
                        }),
                      ),
                    ]),
                    SizedBox(height: compact ? 4 : 12),
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
                              child: SingleChildScrollView(
                                controller: _scrollController,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _buildPrompt(
                                        'What do you notice about your mood today?'),
                                    const SizedBox(height: 12),
                                    if (_hasFollowUp) ...[
                                      Text(
                                        _controller.text,
                                        style: textTheme.bodyLarge?.copyWith(
                                          color: Colors.grey.shade700,
                                          height: 1.5,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      _buildPrompt(
                                          'What about school is weighing on you right now?'),
                                      const SizedBox(height: 12),
                                    ],
                                    TextField(
                                      key: ValueKey(_hasFollowUp),
                                      controller: _hasFollowUp
                                          ? _followUpController
                                          : _controller,
                                      focusNode:
                                          _hasFollowUp ? _followUpFocus : null,
                                      minLines: 3,
                                      maxLines: null,
                                      keyboardType: TextInputType.multiline,
                                      textCapitalization:
                                          TextCapitalization.sentences,
                                      cursorColor: AppColors.primaryDark,
                                      style: textTheme.bodyLarge?.copyWith(
                                        color: AppColors.textPrimary,
                                        height: 1.5,
                                      ),
                                      onTapOutside: (_) => FocusManager
                                          .instance.primaryFocus
                                          ?.unfocus(),
                                      decoration: InputDecoration(
                                        isCollapsed: true,
                                        hintText: _hasFollowUp
                                            ? 'Write here...'
                                            : 'Start writing...',
                                        hintStyle: const TextStyle(
                                            color: AppColors.textSecondary),
                                        filled: false,
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                    SizedBox(height: mascotSize),
                                  ],
                                ),
                              ),
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

  Widget _buildPrompt(String prompt) {
    return Container(
      padding: const EdgeInsets.only(left: 12),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.primary, width: 4)),
      ),
      child: Text(
        prompt,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              height: 1.4,
            ),
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
            tooltip: 'Voice input (coming soon)',
            onPressed: null,
            disabledColor: AppColors.textSecondary,
            icon: Icon(Icons.mic_none_outlined),
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
                onPressed: _finishEntry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryDark,
                  side: const BorderSide(color: AppColors.primaryDark),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 48),
                ),
                child: const Text('Finish entry'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _hasFollowUp ? null : _goDeeper,
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
