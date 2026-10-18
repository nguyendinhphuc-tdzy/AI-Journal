import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/nickname.dart';
import '../data/onboarding_store.dart';
import 'nudaeng_chasing_cockroach.dart';
import 'onboarding_widgets.dart';

/// OB02: optional nickname. No autofocus, so the keyboard only opens when
/// the field is tapped; Done just closes it. Empty is valid. Over the limit,
/// a message shows under the field and "Tiếp tục" waits until it is fixed.
///
/// Layout ([OnboardingStepScaffold]): the Nudaeng stage collapses first when
/// space is short, and while the keyboard is open; the CTA rises with the
/// keyboard.
class OnboardingNicknameScreen extends StatefulWidget {
  const OnboardingNicknameScreen({
    super.key,
    required this.initialValue,
    required this.onChanged,
    required this.onBack,
    required this.onContinue,
  });

  /// Draft kept by the flow, so Back and return keep what was typed.
  final String initialValue;
  final ValueChanged<String> onChanged;
  final VoidCallback onBack;

  /// Called with the trimmed nickname, or null when left empty.
  final ValueChanged<String?> onContinue;

  static const eyebrow = 'Làm quen một chút nhé.';
  static const title = 'Mình nên gọi bạn là gì?';
  static const label = 'Biệt danh';
  static const hint = 'Bạn muốn được gọi như thế nào?';
  static const helper = 'Bạn có thể để trống và đổi lại sau.';
  static const continueLabel = 'Tiếp tục';

  /// Nudaeng's greeting, live as the user types.
  static String greeting(String raw) =>
      'Chào ${Nickname.normalize(raw) ?? 'bạn'}!';

  static String tooLongMessage(int length) =>
      'Biệt danh tối đa ${Nickname.maxLength} ký tự, hiện có $length. '
      'Bạn rút gọn một chút nhé.';

  @override
  State<OnboardingNicknameScreen> createState() =>
      _OnboardingNicknameScreenState();
}

class _OnboardingNicknameScreenState extends State<OnboardingNicknameScreen> {
  late final _controller = TextEditingController(text: widget.initialValue)
    ..addListener(_onText);
  final _focus = FocusNode();
  late bool _tooLong = Nickname.isTooLong(widget.initialValue);

  void _onText() {
    widget.onChanged(_controller.text);
    final tooLong = Nickname.isTooLong(_controller.text);
    if (tooLong != _tooLong) setState(() => _tooLong = tooLong);
  }

  void _continue() {
    _focus.unfocus();
    widget.onContinue(Nickname.normalize(_controller.text));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  // Parts appear one after another: top bar, eyebrow, title, field,
  // helper, Nudaeng, CTA.
  @override
  Widget build(BuildContext context) => OnboardingStepScaffold(
        step: OnboardingStep.nickname,
        onBack: widget.onBack,
        content: _content(context),
        stage: StaggerItem(order: 5, child: _Stage(nickname: _controller)),
        actions: [
          StaggerItem(
            order: 6,
            child: OnboardingCta(
              label: OnboardingNicknameScreen.continueLabel,
              onPressed: _tooLong ? null : _continue,
            ),
          ),
        ],
      );

  Widget _content(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    final outline = _tooLong ? error : AppColors.border;
    final focused = _tooLong ? error : AppColors.primaryAction;
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: color, width: width),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StaggerItem(
            order: 1,
            child: Text(OnboardingNicknameScreen.eyebrow, style: _Text.eyebrow),
          ),
          const SizedBox(height: AppSpacing.sm),
          StaggerItem(
            order: 2,
            child: Semantics(
              header: true,
              child: const Text(OnboardingNicknameScreen.title,
                  style: _Text.title),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          const StaggerItem(
            order: 3,
            child: ExcludeSemantics(
              child: Text(OnboardingNicknameScreen.label, style: _Text.label),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          StaggerItem(
              order: 3,
              child: Semantics(
                label: OnboardingNicknameScreen.label,
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.words,
                  onSubmitted: (_) => _focus.unfocus(),
                  onTapOutside: (_) => _focus.unfocus(),
                  style: _Text.input,
                  cursorColor: AppColors.primaryAction,
                  decoration: InputDecoration(
                    hintText: OnboardingNicknameScreen.hint,
                    // Smaller than the typed text so the hint fits narrow
                    // screens; wraps instead of being cut.
                    hintStyle: _Text.hint,
                    hintMaxLines: 2,
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.md),
                    enabledBorder: border(outline, 1),
                    focusedBorder: border(focused, 2),
                  ),
                ),
              )),
          const SizedBox(height: AppSpacing.sm),
          StaggerItem(
              order: 4,
              child: _tooLong
                  ? Semantics(
                      liveRegion: true,
                      child: Text(
                        OnboardingNicknameScreen.tooLongMessage(
                            Nickname.length(_controller.text)),
                        style: _Text.helper.copyWith(color: error),
                      ),
                    )
                  : const Text(OnboardingNicknameScreen.helper,
                      style: _Text.helper)),
        ],
      ),
    );
  }
}

abstract final class _Text {
  static const eyebrow = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 16,
    height: 1.5,
    color: AppColors.textSecondary,
  );
  static const title = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: AppColors.textPrimary,
  );
  static const label = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 20 / 14,
    color: AppColors.textPrimary,
  );
  static const input = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 18,
    height: 1.4,
    color: AppColors.textPrimary,
  );
  static const hint = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 16,
    height: 1.5,
    color: AppColors.textSecondary,
  );
  static const helper = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 14,
    height: 20 / 14,
    color: AppColors.textSecondary,
  );
}

/// Nudaeng watching the cockroach, sized and placed like every onboarding
/// mascot ([OnboardingMascot]), greeting the nickname as it is typed.
class _Stage extends StatelessWidget {
  const _Stage({required this.nickname});

  final ValueListenable<TextEditingValue> nickname;

  /// In the 306×319 run frames: head top and feet, measured on frame 12.
  static const _frame = MascotFrame(
    canvas: Size(306, 319),
    headTop: 2,
    feet: Offset(136, 275),
  );

  @override
  Widget build(BuildContext context) => OnboardingMascot(
        frame: _frame,
        bubble: ValueListenableBuilder(
          valueListenable: nickname,
          builder: (context, value, _) =>
              MascotBubble(text: OnboardingNicknameScreen.greeting(value.text)),
        ),
        child: const NudaengChasingCockroach(
          semanticLabel: 'Nudaeng nhìn theo một chú gián chạy vòng',
        ),
      );
}
