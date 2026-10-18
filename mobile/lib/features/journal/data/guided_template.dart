import 'journal_mood.dart';

/// One blank in a guided sentence: "[prefix] [value][suffix]".
class GuidedSlot {
  const GuidedSlot({
    required this.id,
    required this.prefix,
    required this.placeholder,
    this.suffix = '.',
    this.sheetTitle,
  });

  /// The mood blank: filled from [JournalMood], not typed.
  const GuidedSlot.mood({
    required this.prefix,
    required this.placeholder,
    this.suffix = '.',
  })  : id = moodId,
        sheetTitle = null;

  static const moodId = 'mood';

  final String id;
  final String prefix;
  final String placeholder;
  final String suffix;

  /// Title of the sheet that edits this blank.
  final String? sheetTitle;

  bool get isMood => id == moodId;
}

/// A guided body: a few sentences with blanks. Entries keep the template id
/// and [version] with the structured values, plus a readable body snapshot
/// rendered from the filled blanks only.
class GuidedTemplate {
  const GuidedTemplate({
    required this.id,
    required this.version,
    required this.slots,
  });

  final String id;
  final int version;
  final List<GuidedSlot> slots;

  Iterable<GuidedSlot> get textSlots => slots.where((slot) => !slot.isMood);

  /// The OB07 first entry.
  static const firstEntry = GuidedTemplate(
    id: 'onboarding_first_entry',
    version: 1,
    slots: [
      GuidedSlot.mood(
          prefix: 'Lúc này mình cảm thấy', placeholder: 'Chọn cảm xúc'),
      GuidedSlot(
        id: 'cause',
        prefix: 'Có lẽ vì',
        placeholder: 'Điều khiến mình cảm thấy vậy',
        sheetTitle: 'Điều gì khiến bạn cảm thấy vậy?',
      ),
      GuidedSlot(
        id: 'thought',
        prefix: 'Một điều đang ở trong đầu mình là',
        placeholder: 'Điều mình đang nghĩ',
        sheetTitle: 'Điều gì đang ở trong đầu bạn?',
      ),
      GuidedSlot(
        id: 'hope',
        prefix: 'Trong vài ngày tới, mình muốn',
        placeholder: 'Một điều mình mong đợi',
        sheetTitle: 'Trong vài ngày tới, bạn muốn điều gì?',
      ),
    ],
  );

  /// Only blanks with real text, trimmed; never placeholders.
  Map<String, String> clean(Map<String, String> fields) => {
        for (final slot in textSlots)
          if ((fields[slot.id] ?? '').trim().isNotEmpty)
            slot.id: fields[slot.id]!.trim(),
      };

  /// An entry needs at least one text blank; a mood alone is not enough.
  bool hasText(Map<String, String> fields) => clean(fields).isNotEmpty;

  /// Readable body: one sentence per filled blank, in order. Unfilled
  /// blanks are left out entirely, so no half sentences.
  String render({JournalMood? mood, required Map<String, String> fields}) {
    final values = clean(fields);
    return [
      for (final slot in slots)
        if (slot.isMood && mood != null)
          '${slot.prefix} ${_lowerFirst(mood.label)}${slot.suffix}'
        else if (!slot.isMood && values[slot.id] != null)
          '${slot.prefix} ${_finish(values[slot.id]!, slot.suffix)}',
    ].join('\n');
  }

  static String _lowerFirst(String text) =>
      text.isEmpty ? text : text[0].toLowerCase() + text.substring(1);

  /// No doubled punctuation when the user already ended the sentence.
  static String _finish(String value, String suffix) =>
      RegExp(r'[.!?…]$').hasMatch(value) ? value : '$value$suffix';
}
