/// Where the AI's words for a feeling ("thất vọng", "nặng nề nhưng tìm thấy
/// sự dịu nhẹ") fall on a 0–100 line, for the week's chart. The AI writes
/// the feeling freely; the app sorts it into a few groups by their words.
///
/// It is the AI's reading of an entry, sorted by the app: never shown as a
/// rating or a diagnosis of the person (the chart says so).
library;

class EmotionGroup {
  const EmotionGroup(this.id, this.label, this.score, this.words);

  final String id;

  /// As shown: "Vui vẻ", "Lo lắng"…
  final String label;

  /// Its place on the chart, 0 (heavy) to 100 (light).
  final int score;

  /// Lower-case words or phrases that name it, matched whole.
  final List<String> words;
}

const emotionGroups = <EmotionGroup>[
  EmotionGroup('joy', 'Vui vẻ', 90, [
    'vui', 'vui vẻ', 'hạnh phúc', 'hào hứng', 'phấn khởi', 'háo hức',
    'tự hào', 'yêu đời', 'thích thú', 'phấn chấn', 'hân hoan', 'sung sướng',
  ]),
  EmotionGroup('grateful', 'Biết ơn', 85, [
    'biết ơn', 'trân trọng', 'cảm kích', 'ấm lòng',
  ]),
  EmotionGroup('calm', 'Bình yên', 80, [
    'bình yên', 'nhẹ nhõm', 'thư giãn', 'thoải mái', 'bình an', 'an yên',
    'dịu nhẹ', 'thanh thản', 'bình tĩnh', 'ấm áp', 'nhẹ lòng', 'thư thái',
  ]),
  EmotionGroup('hopeful', 'Hy vọng', 72, [
    'hy vọng', 'hi vọng', 'lạc quan', 'mong chờ', 'quyết tâm', 'động lực',
    'tò mò', 'kỳ vọng', 'tin tưởng',
  ]),
  EmotionGroup('mixed', 'Lẫn lộn', 55, [
    'bối rối', 'lẫn lộn', 'phân vân', 'băn khoăn', 'hoài niệm', 'bâng khuâng',
    'bình thường', 'trung tính', 'chưa rõ', 'trầm ngâm', 'suy tư',
  ]),
  EmotionGroup('tired', 'Mệt mỏi', 40, [
    'mệt', 'mệt mỏi', 'kiệt sức', 'uể oải', 'đuối', 'nặng nề', 'kiệt quệ',
    'chán chường',
  ]),
  EmotionGroup('anxious', 'Lo lắng', 35, [
    'lo', 'lo lắng', 'lo âu', 'áp lực', 'căng thẳng', 'bồn chồn', 'bất an',
    'choáng ngợp', 'quá tải', 'hồi hộp', 'ngợp', 'sốt ruột',
  ]),
  EmotionGroup('afraid', 'Sợ hãi', 30, [
    'sợ', 'sợ hãi', 'hoảng', 'hoảng sợ', 'e ngại', 'lo sợ',
  ]),
  EmotionGroup('angry', 'Tức giận', 30, [
    'tức', 'tức giận', 'giận', 'bực', 'bực bội', 'khó chịu', 'ức chế',
    'phẫn nộ',
  ]),
  EmotionGroup('sad', 'Buồn', 25, [
    'buồn', 'thất vọng', 'chán', 'chán nản', 'cô đơn', 'tủi thân',
    'trống rỗng', 'đau lòng', 'tổn thương', 'hụt hẫng', 'tiếc nuối',
    'tự ti', 'u sầu', 'buồn bã',
  ]),
];

/// The groups [emotion] names, in the order of [emotionGroups]. Empty when
/// none fits: then it has no place on the chart, only its words.
List<EmotionGroup> groupsOf(String emotion) {
  final text = ' ${emotion.toLowerCase().split(RegExp(r'[^\p{L}\p{N}]+',
      unicode: true)).where((word) => word.isNotEmpty).join(' ')} ';
  bool names(String phrase) {
    if (!text.contains(' $phrase ')) return false;
    // "không vui" is not joy.
    return !RegExp('(không|chẳng|chưa|hết) $phrase ').hasMatch(text);
  }

  return [
    for (final group in emotionGroups)
      if (group.words.any(names)) group,
  ];
}

/// [emotion]'s place on the chart: the mean of its groups, or null.
double? scoreOf(String emotion) {
  final groups = groupsOf(emotion);
  if (groups.isEmpty) return null;
  return groups.fold(0, (sum, group) => sum + group.score) / groups.length;
}
