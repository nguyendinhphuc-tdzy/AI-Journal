/// User-requested demo content. No video source or production persistence is
/// implied by these article fixtures. IDs are stable within the demo catalog.
class StudyLesson {
  const StudyLesson(
      {required this.id,
      required this.title,
      required this.minutes,
      required this.paragraphs,
      required this.summary,
      required this.prompt});
  final String id;
  final String title;
  final int minutes;
  final List<String> paragraphs;
  final List<String> summary;
  final String prompt;
}

const studyLessons = [
  StudyLesson(
    id: 'gratitude-notice',
    title: 'Nhìn thấy điều nhỏ đang nâng đỡ bạn',
    minutes: 4,
    paragraphs: [
      'Một ngày đáng ghi lại không nhất thiết phải có chuyện lớn. Cốc nước mát sau khi đi bộ, một tin nhắn hỏi thăm hay vài phút ngồi yên đều có thể là điểm bắt đầu.',
      'Hãy chọn một khoảnh khắc cụ thể. Bạn ở đâu? Điều gì đã xảy ra? Chi tiết nào khiến bạn muốn dừng lại? Viết những gì bạn nhớ, thay vì cố tìm một câu thật hay.',
      'Ví dụ: “Trên đường về, mình được người bán hàng nhắc mang theo áo mưa. Một lời nhắc nhỏ khiến mình thấy được quan tâm.” Chi tiết giúp trang viết mang dấu ấn của riêng bạn.',
      'Biết ơn không có nghĩa là bỏ qua điều khó chịu. Bạn có thể vừa mệt vì một ngày dài, vừa trân trọng một việc nhỏ đã giúp mình đi qua ngày ấy.',
    ],
    summary: [
      'Chọn một khoảnh khắc cụ thể.',
      'Ghi lại điều đã xảy ra và cảm nhận của bạn.',
      'Cho phép cảm xúc dễ chịu và khó chịu cùng có mặt.'
    ],
    prompt: 'Một điều nhỏ hôm nay khiến bạn biết ơn là gì?',
  ),
  StudyLesson(
    id: 'gratitude-thanks',
    title: 'Viết một lời cảm ơn thật cụ thể',
    minutes: 4,
    paragraphs: [
      'Nghĩ về một người đã làm điều gì đó giúp ngày của bạn dễ chịu hơn. Đó có thể là một người thân, một đồng nghiệp hoặc người bạn chỉ gặp thoáng qua.',
      'Thay vì dừng ở “Cảm ơn vì đã giúp mình”, hãy gọi tên hành động: họ lắng nghe, chờ bạn, chia sẻ một bữa ăn hay giải thích điều bạn chưa hiểu?',
      'Tiếp theo, viết hành động ấy có ý nghĩa gì với bạn. “Khi bạn chờ mình ở cổng, mình thấy bớt vội và không phải bắt đầu buổi sáng trong lo lắng.” Không cần đoán ý định của người kia.',
      'Bạn không cần gửi lời cảm ơn này. Trang nhật ký có thể là nơi riêng tư để bạn nhận ra điều mình trân trọng. Nếu muốn chia sẻ, bạn có thể quyết định sau.',
    ],
    summary: [
      'Gọi tên một hành động cụ thể.',
      'Nói điều đó có ý nghĩa gì với bạn.',
      'Chia sẻ lời cảm ơn là lựa chọn của bạn.'
    ],
    prompt:
        'Bạn muốn cảm ơn ai hôm nay, và hành động cụ thể nào của họ đã giúp bạn?',
  ),
  StudyLesson(
    id: 'gratitude-carry',
    title: 'Giữ lại điều bạn muốn mang sang ngày mai',
    minutes: 4,
    paragraphs: [
      'Đọc lại một hoặc hai điều bạn vừa ghi. Có điều gì bạn muốn nhớ khi bắt đầu ngày mai? Đó có thể là một cảm giác, một cách chăm sóc mình hoặc một lời nhắc giản dị.',
      'Chọn điều nằm trong khả năng của bạn. Thay vì hứa “Ngày mai sẽ luôn vui”, bạn có thể viết “Mình sẽ dành vài phút uống trà trước khi mở điện thoại”.',
      'Bước tiếp theo không cần lớn. Một hành động nhỏ, rõ ràng giúp ý định dễ hình dung hơn. Nếu ngày mai khác dự định, bạn vẫn có thể quay lại trang viết mà không cần làm lại từ đầu.',
      'Kết thúc bằng một câu dành cho chính mình. Bạn không phải biến mỗi điều biết ơn thành mục tiêu; đôi khi chỉ cần ghi nhớ nó là đủ.',
    ],
    summary: [
      'Chọn một điều muốn ghi nhớ.',
      'Nếu muốn hành động, bắt đầu bằng một bước nhỏ.',
      'Không cần biến mọi trang viết thành một mục tiêu.'
    ],
    prompt:
        'Từ điều bạn trân trọng hôm nay, bạn muốn giữ lại điều gì cho ngày mai?',
  ),
];

const studyCase = StudyLesson(
  id: 'small-progress',
  title: 'Nhìn lại những điều nhỏ đã làm được',
  minutes: 5,
  paragraphs: [
    'Cuối ngày, Mai mở sổ và chỉ nghĩ đến những việc còn dang dở. Cô chưa xong bản thuyết trình, chưa dọn góc bàn và đã bỏ lỡ cuộc gọi của một người bạn.',
    'Mai thử đổi câu hỏi thành “Hôm nay mình đã có mặt cho điều gì?”. Cô nhớ mình đã hỏi lại một yêu cầu chưa rõ, ăn trưa trước khi quá đói và nhắn cho bạn để hẹn thời gian gọi lại.',
    'Những việc ấy không làm danh sách công việc biến mất. Nhưng khi viết từng việc cụ thể, Mai nhìn thấy cả phần mình đã chăm lo, thay vì chỉ nhìn phần chưa xong.',
    'Bạn có thể thử ba dòng: điều mình đã làm, điều còn khó và điều mình cần tiếp theo. Không cần so sánh với ngày hôm qua hoặc với người khác.',
    'Mai là nhân vật trong tình huống minh họa. Bạn có thể thay các chi tiết bằng trải nghiệm của mình, hoặc chỉ chọn một câu hỏi phù hợp để bắt đầu.',
  ],
  summary: [
    'Ghi nhận hành động nhỏ bằng chi tiết cụ thể.',
    'Nhìn cả điều đã làm và điều còn khó.',
    'Chọn nhu cầu tiếp theo thay vì tự chấm điểm.'
  ],
  prompt:
      'Một việc nhỏ bạn đã làm được hôm nay là gì, và lúc này bạn cần điều gì?',
);

const courseBenefits = [
  'Nhận ra một điều đáng trân trọng trong ngày.',
  'Viết lời cảm ơn bằng một chi tiết cụ thể.',
  'Chọn điều bạn muốn giữ lại cho ngày mai.'
];
const courseSummary = [
  'Quan sát một khoảnh khắc cụ thể.',
  'Gọi tên điều có ý nghĩa với bạn.',
  'Giữ lại một lời nhắc hoặc bước nhỏ cho ngày mai.'
];
const coursePracticePrompt =
    'Chọn một khoảnh khắc bạn biết ơn, viết điều khiến nó có ý nghĩa và điều bạn muốn giữ lại.';
const frameworkSteps = [
  'Đặt tên cho điều đang chiếm tâm trí bạn.',
  'Tách điều bạn biết chắc khỏi điều bạn đang suy đoán.',
  'Chọn một bước nhỏ trong khả năng của bạn lúc này.'
];
const frameworkPrompt =
    'Điều gì đang làm tâm trí bạn bận rộn? Bạn biết chắc điều gì, đang suy đoán điều gì và có thể làm bước nhỏ nào?';
const challengeId = 'gratitude-seven';
const challengePrompts = [
  'Một điều nhỏ hôm nay khiến bạn biết ơn là gì?',
  'Ai đã làm ngày hôm nay của bạn dễ chịu hơn?',
  'Một khoảnh khắc bình thường nhưng đáng nhớ?',
  'Điều gì cơ thể bạn đã giúp bạn làm hôm nay?',
  'Một nơi khiến bạn thấy yên hơn?',
  'Bạn đã học được điều gì về chính mình?',
  'Một điều bạn muốn cảm ơn bản thân?'
];

class StudyWritingContext {
  const StudyWritingContext(
      {required this.kind,
      required this.sourceId,
      this.challenge,
      this.taskIndex});
  final String kind;
  final String sourceId;
  final String? challenge;
  final int? taskIndex;
}

class StudyMockEntry {
  const StudyMockEntry(
      {required this.id,
      required this.content,
      required this.prompt,
      required this.source});
  final String id;
  final String content;
  final String prompt;
  final StudyWritingContext source;
}

/// Deliberately session-only. A stable task association prevents duplicate
/// entries if the same save callback is retried in this UI demo.
class StudyMockSession {
  final Map<String, StudyMockEntry> _entries = {};
  final Map<String, String> _taskEntries = {};

  StudyMockEntry save(
      String content, String prompt, StudyWritingContext source) {
    final taskKey = source.challenge != null && source.taskIndex != null
        ? '${source.challenge}/${source.taskIndex}'
        : null;
    final existingId = _taskEntries[taskKey];
    if (existingId != null) return _entries[existingId]!;
    final entry = StudyMockEntry(
        id: 'study-entry-${_entries.length + 1}',
        content: content,
        prompt: prompt,
        source: source);
    _entries[entry.id] = entry;
    if (taskKey != null) _taskEntries[taskKey] = entry.id;
    return entry;
  }

  StudyMockEntry? entryForTask(int task) =>
      _entries[_taskEntries['$challengeId/$task']];

  List<StudyMockEntry> get challengeEntries => _entries.values
      .where((entry) => entry.source.challenge == challengeId)
      .toList()
    ..sort((a, b) => a.source.taskIndex!.compareTo(b.source.taskIndex!));
}
