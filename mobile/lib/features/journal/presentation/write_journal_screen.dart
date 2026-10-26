import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../navigation/app_shell.dart';
import '../../../navigation/custom_bottom_navigation.dart';
import '../data/journal_entry.dart';
import '../data/api_ai_service.dart';
import '../journal_scope.dart';
import 'ai_reflection_screen.dart';
import '../../onboarding/data/onboarding_store.dart';
import '../../onboarding/data/onboarding_scope.dart';
import '../../profile/data/writing_preferences.dart';

class WriteJournalScreen extends StatefulWidget {
  const WriteJournalScreen({super.key, this.entry});

  /// An entry to keep writing (e.g. from Home); saving updates the same id.
  final JournalEntry? entry;

  @override
  State<WriteJournalScreen> createState() => _WriteJournalScreenState();
}

class _WriteJournalScreenState extends State<WriteJournalScreen> {
  late final _controller = TextEditingController(text: widget.entry?.body);
  late JournalEntry? _saved = widget.entry;
  bool _saving = false;
  final _followUpController = TextEditingController();
  final _followUpFocus = FocusNode();
  final _scrollController = ScrollController();
  bool _hasFollowUp = false;
  bool _askingDeeper = false;
  String _followUpPrompt = 'Điều gì trong hôm nay khiến bạn muốn viết thêm?';
  bool _isPaperBackground = true;
  double _textSize = 16;
  WritingPreferences? _preferences;
  bool _changingPaper = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await WritingPreferences.open();
      if (!mounted) return;
      setState(() {
        _preferences = prefs;
        _isPaperBackground = prefs.paper;
        _textSize = prefs.textSize;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Chưa tải được tùy chỉnh. Đang dùng giao diện mặc định.')));
      }
    }
  }

  Future<void> _togglePaper() async {
    if (_changingPaper) return;
    setState(() => _changingPaper = true);
    try {
      final prefs = _preferences ?? await WritingPreferences.open();
      final paper = !_isPaperBackground;
      await prefs.savePaper(paper);
      if (!mounted) return;
      setState(() {
        _preferences = prefs;
        _isPaperBackground = paper;
      });
      await prefs.feedback();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Chưa lưu được nền giấy. Hãy thử lại.')));
      }
    } finally {
      if (mounted) setState(() => _changingPaper = false);
    }
  }

  String get _entryText => [
        _controller.text.trim(),
        if (_hasFollowUp) _followUpController.text.trim(),
      ].where((answer) => answer.isNotEmpty).join('\n\n');

  void _showEmptyEntryMessage() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content:
          Text('Vui lòng viết ít nhất một dòng nhật ký trước khi hoàn thành.'),
    ));
  }

  Future<void> _goDeeper() async {
    if (_askingDeeper || _hasFollowUp || _controller.text.trim().isEmpty) return;
    final remote = AiRemoteScope.maybeOf(context);
    if (remote != null) {
      if (OnboardingScope.maybeOf(context)?.aiEnabled != true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Bạn chưa bật phản hồi AI trong cài đặt.'),
        ));
        return;
      }
      setState(() => _askingDeeper = true);
      try {
        final question = await remote.goDeeper(_controller.text);
        if (!mounted) return;
        _followUpPrompt = question;
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Chưa thể nhận câu hỏi AI. Hãy thử lại.'),
        ));
        // Never substitute a demo prompt after a real AI request failed.
        return;
      } finally {
        if (mounted) setState(() => _askingDeeper = false);
      }
    }
    if (!mounted) return;
    setState(() => _hasFollowUp = true);
    _preferences?.feedback();
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
    if (_saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (_entryText.isEmpty) {
      _showEmptyEntryMessage();
      return;
    }
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bạn đã hoàn tất chưa?',
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
                    child: const Text('Quay lại'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(sheetContext, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Xác nhận'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (!mounted || confirmed != true) return;
    // Recheck after the modal: content could have changed while it was open.
    final text = _entryText;
    if (_saving) return;
    if (text.isEmpty) {
      _showEmptyEntryMessage();
      return;
    }

    setState(() => _saving = true);
    final saved = _saved;
    // Preserve guided metadata only while the journal body is unchanged.
    final content = JournalContent(
      body: text,
      mood: saved?.content.mood,
      guided: saved != null && saved.body == text ? saved.content.guided : null,
    );
    bool useAi;
    try {
      final settings = OnboardingScope.maybeOf(context) ??
          await OnboardingStore.open();
      // Preserve the demo's existing flow when no choice has been recorded.
      // Local prototype preserves its old mock behavior, but a real\n      // model is never called without the user's explicit opt-in.\n      useAi = AiRemoteScope.maybeOf(context) == null\n          ? settings.aiEnabled != false\n          : settings.aiEnabled == true;
      if (!mounted) return;
      final journals = JournalScope.of(context);
      _saved = saved == null
          ? await journals.create(content)
          : await journals.update(saved.id, content);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Chưa lưu được nhật ký. Nội dung vẫn còn ở đây.')));
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    await _preferences?.feedback();
    if (!mounted) return;
    if (useAi) {
      _openReflection();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Đã lưu nhật ký. Phản hồi AI đang tắt.')));
      if (Navigator.of(context).canPop()) {
        Navigator.pop(context);
      } else {
        _selectTab(0);
      }
    }
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
          journalContent: _entryText,
          remote: AiRemoteScope.maybeOf(context),
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
                        tooltip: 'Đóng',
                        icon: const Icon(Icons.close),
                        color: AppColors.textPrimary,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Nhật ký hôm nay',
                            textAlign: TextAlign.center,
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Đổi nền nhật ký',
                        icon: const Icon(Icons.palette_outlined),
                        color: AppColors.textPrimary,
                        onPressed: _changingPaper ? null : _togglePaper,
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
                                        'Hôm nay bạn nhận thấy tâm trạng mình thế nào?'),
                                    const SizedBox(height: 12),
                                    if (_hasFollowUp) ...[
                                      Text(
                                        _controller.text,
                                        style: textTheme.bodyLarge?.copyWith(
                                          color: Colors.grey.shade700,
                                          fontSize: _textSize,
                                          height: 1.5,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      _buildPrompt(_followUpPrompt),
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
                                        fontSize: _textSize,
                                        height: 1.5,
                                      ),
                                      onTapOutside: (_) => FocusManager
                                          .instance.primaryFocus
                                          ?.unfocus(),
                                      decoration: InputDecoration(
                                        isCollapsed: true,
                                        hintText: _hasFollowUp
                                            ? 'Viết tại đây...'
                                            : 'Bắt đầu viết...',
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
                                  label: 'Nudaeng đang đọc sách',
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
            tooltip: 'Nhập bằng giọng nói (sắp có)',
            onPressed: null,
            disabledColor: AppColors.textSecondary,
            icon: Icon(Icons.mic_none_outlined),
          ),
          IconButton(
            tooltip: 'Thêm ảnh (sắp có)',
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
                onPressed: _saving ? null : _finishEntry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryDark,
                  side: const BorderSide(color: AppColors.primaryDark),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 48),
                ),
                child: const Text('Hoàn tất'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: (_hasFollowUp || _askingDeeper) ? null : _goDeeper,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryAction,
                  foregroundColor: AppColors.surface,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 48),
                ),
                child: Text(_askingDeeper ? 'Đang hỏi AI…' : '✨ Suy ngẫm sâu hơn'),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}
