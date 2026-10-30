/// An entry written with "Nhìn lại cùng bạn", as the AI reads it: the
/// opening question and answer, each AI question with its answer, and why
/// the user journals (OB03), if said.
class AiConversation {
  const AiConversation({
    required this.prompt,
    required this.entry,
    this.rounds = const [],
    this.goal,
  });

  final String prompt;
  final String entry;
  final List<({String question, String answer})> rounds;
  final String? goal;

  /// The backend reads at most 8000 characters; this keeps room for it.
  static const defaultBudget = 6000;

  /// For the analysis on save: the whole entry matters more.
  static const reflectionBudget = 7500;

  /// An older answer cut down to this when the whole does not fit.
  static const shortAnswer = 160;

  /// The conversation in at most [budget] characters. What matters most is
  /// kept whole: the start (up to half the budget) and the latest rounds.
  /// Older rounds are shortened when needed, then the oldest of them left
  /// out with a note, so the AI knows something came before.
  String text({int budget = defaultBudget}) {
    if (budget <= 0) return '';
    final head = [
      'Câu hỏi: ${_clip(prompt.trim(), budget ~/ 8)}',
      'Trả lời: ${_clip(entry.trim(), budget ~/ 2)}',
    ].join('\n');
    final tail = goal == null
        ? ''
        : '\nNgười viết muốn viết nhật ký để: ${_clip(goal!.trim(), budget ~/ 8)}';
    var room = budget - head.length - tail.length;
    final kept = <String>[];
    var shorten = false;
    var left = 0;
    final answered = [
      for (final round in rounds)
        if (round.answer.trim().isNotEmpty) round,
    ];
    for (var i = answered.length - 1; i >= 0; i--) {
      final round = answered[i];
      final question =
          'Câu hỏi: ${_clip(round.question.trim(), budget ~/ 8)}\nTrả lời: ';
      final answer = round.answer.trim();
      String? block;
      if (!shorten && question.length + answer.length + 1 <= room) {
        block = '$question$answer';
      } else if (i == answered.length - 1) {
        // The latest answer, the one asked about: always in, cut to fit.
        block = '$question${_clip(answer, room - question.length - 1)}';
      } else {
        shorten = true;
        final short = '$question${_clip(answer, shortAnswer)}';
        if (short.length + 1 <= room) block = short;
      }
      if (block == null) {
        left = i + 1;
        break;
      }
      kept.insert(0, block);
      room -= block.length + 1;
    }
    final result = [
          head,
          if (left > 0) '(Đã lược bớt $left lượt hỏi đáp trước đó.)',
          ...kept,
        ].join('\n') +
        tail;
    return _clip(result, budget);
  }

  static String _clip(String text, int max) {
    if (max <= 1) return '';
    return text.length <= max ? text : '${text.substring(0, max - 1)}…';
  }
}
