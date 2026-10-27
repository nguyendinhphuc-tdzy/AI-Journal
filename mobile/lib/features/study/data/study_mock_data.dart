import 'package:flutter/foundation.dart';

import '../../journal/data/journal_entry.dart';
import '../../journal/data/journal_repository.dart';

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

/// The writing template's name (was "Clear My Mind").
const frameworkTitle = 'Gỡ rối suy nghĩ';

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

/// "Suy ngẫm sâu hơn": two questions that follow each piece of Study
/// writing, asked one at a time after the first answer. Challenge tasks by
/// index; lessons, the course practice and the template by source id.
const _challengeFollowUps = [
  [
    'Khoảnh khắc đó diễn ra thế nào? Bạn nhớ rõ chi tiết nào nhất?',
    'Điều nhỏ ấy cho bạn biết gì về những gì bạn đang cần lúc này?',
  ],
  [
    'Người ấy đã làm gì, và lúc đó bạn cảm thấy thế nào?',
    'Nếu được nói một câu với người ấy, bạn muốn nói gì?',
  ],
  [
    'Điều gì khiến khoảnh khắc bình thường này trở nên đáng nhớ?',
    'Bạn muốn có thêm những khoảnh khắc như vậy ở đâu trong ngày?',
  ],
  [
    'Hôm nay bạn đã đối xử với cơ thể mình thế nào?',
    'Một việc nhỏ nào bạn có thể làm ngày mai để chăm sóc cơ thể?',
  ],
  [
    'Ở nơi đó, bạn nghe, thấy hay cảm nhận được điều gì?',
    'Khi không thể đến đó, bạn có thể mang cảm giác ấy theo bằng cách nào?',
  ],
  [
    'Điều gì đã giúp bạn nhận ra điều này?',
    'Hiểu điều này rồi, bạn muốn đối xử với mình khác đi thế nào?',
  ],
  [
    'Bạn đã vượt qua điều gì để làm được việc đó?',
    'Sau bảy ngày viết, bạn muốn giữ lại thói quen nào?',
  ],
];

const _followUps = {
  'gratitude-notice': [
    'Chi tiết nào trong khoảnh khắc đó khiến bạn muốn dừng lại?',
    'Khoảnh khắc ấy cho bạn biết điều gì đang nâng đỡ bạn?',
  ],
  'gratitude-thanks': [
    'Hành động ấy có ý nghĩa gì với bạn, vào đúng lúc đó?',
    'Nếu muốn gửi lời cảm ơn này đi, bạn sẽ nói thế nào?',
  ],
  'gratitude-carry': [
    'Một bước nhỏ, rõ ràng nào giúp bạn giữ điều đó cho ngày mai?',
    'Nếu ngày mai khác dự định, bạn muốn nhắc mình điều gì?',
  ],
  'small-progress': [
    'Việc nhỏ đó đã giúp ngày của bạn nhẹ hơn thế nào?',
    'Bạn muốn nói gì với chính mình khi nhìn lại những việc này?',
  ],
  'gratitude-course': [
    'Vì sao khoảnh khắc ấy có ý nghĩa với bạn?',
    'Bạn muốn mang điều gì từ khoảnh khắc ấy sang ngày mai?',
  ],
  'clear-my-mind': [
    'Trong những điều đang suy đoán, điều nào làm bạn lo nhất? Có điều gì '
        'cho thấy nó có thể khác đi không?',
    'Nếu bước nhỏ ấy diễn ra suôn sẻ, bạn sẽ cảm thấy thế nào?',
  ],
};

/// For anything without its own questions.
const _generalFollowUps = [
  'Điều gì khiến điều bạn vừa viết quan trọng với bạn?',
  'Bạn muốn mang điều gì từ đây sang ngày mai?',
];

List<String> studyFollowUps(StudyWritingContext source) {
  final task = source.taskIndex;
  if (source.challenge == challengeId &&
      task != null &&
      task < _challengeFollowUps.length) {
    return _challengeFollowUps[task];
  }
  return _followUps[source.sourceId] ?? _generalFollowUps;
}

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

/// A piece of Study writing as the Study screens show it: the journal entry
/// it was saved as, with the prompt it answered.
class StudyEntry {
  const StudyEntry(
      {required this.id,
      required this.content,
      required this.prompt,
      required this.source});

  /// The journal entry's id.
  final String id;
  final String content;
  final String prompt;
  final StudyWritingContext source;
}

/// Study writing goes into the journal, as entries with a [JournalSource],
/// so it is listed in "Nhật ký của bạn" with the rest. A challenge task
/// keeps one entry: saving it again (e.g. a retried save) returns the same.
/// [taskEntries] (task → journal id) is kept with the Study progress.
class StudySession {
  StudySession({JournalRepository? journals, Map<int, String>? taskEntries})
      : journals = journals ?? InMemoryJournalRepository(),
        taskEntries = taskEntries ?? {};

  JournalRepository journals;
  final Map<int, String> taskEntries;
  final Map<int, StudyEntry> _tasks = {};

  /// Called when [taskEntries] changed, to keep it.
  VoidCallback? onChanged;

  Future<StudyEntry> save(
      String content, String prompt, StudyWritingContext source,
      {required String label}) async {
    final task = source.challenge == challengeId ? source.taskIndex : null;
    final existing = task == null ? null : _tasks[task];
    if (existing != null) return existing;
    final entry = await journals.create(JournalContent(
      body: content,
      source: JournalSource(
          kind: source.kind,
          id: source.challenge ?? source.sourceId,
          task: task,
          label: label),
    ));
    final saved = StudyEntry(
        id: entry.id, content: content, prompt: prompt, source: source);
    if (task != null) {
      _tasks[task] = saved;
      taskEntries[task] = entry.id;
      onChanged?.call();
    }
    return saved;
  }

  /// Reads the tasks' entries back from the journal. One deleted there is
  /// forgotten here; its task stays done.
  Future<void> load() async {
    final gone = <int>[];
    for (final MapEntry(key: task, value: id) in taskEntries.entries) {
      final entry = await journals.entry(id);
      if (entry == null || task >= challengePrompts.length) {
        gone.add(task);
        continue;
      }
      _tasks[task] = StudyEntry(
        id: id,
        content: entry.body,
        prompt: challengePrompts[task],
        source: StudyWritingContext(
            kind: 'challenge',
            sourceId: 'task-${task + 1}',
            challenge: challengeId,
            taskIndex: task),
      );
    }
    if (gone.isEmpty) return;
    for (final task in gone) {
      taskEntries.remove(task);
    }
    onChanged?.call();
  }

  StudyEntry? entryForTask(int task) => _tasks[task];

  List<StudyEntry> get challengeEntries =>
      [for (final task in _tasks.keys.toList()..sort()) _tasks[task]!];
}
