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
    title: 'Để ý những điều nhỏ khiến bạn vui',
    minutes: 4,
    paragraphs: [
      'Không phải ngày nào cũng có chuyện đặc biệt xảy ra. Đôi khi, điều khiến một ngày trở nên dễ chịu lại rất đơn giản: một bữa ăn ngon, vài phút nghỉ ngơi hay một tin nhắn hỏi thăm từ bạn bè.',
      'Những chuyện nhỏ như vậy thường dễ bị bỏ qua, nhất là khi bạn đang bận rộn hoặc có nhiều điều phải lo.',
      'Hôm nay, thử nhớ lại một khoảnh khắc khiến bạn cảm thấy vui hoặc thoải mái hơn một chút. Đó có thể là lúc bạn được ăn món mình thích, hoàn thành một việc còn dang dở, hoặc có ai đó giúp đỡ đúng lúc.',
      'Hãy viết lại những gì đã xảy ra, bạn đã ở đâu, với ai và cảm thấy thế nào.',
      'Ví dụ:\n“Hôm nay trời mưa, mình quên mang áo mưa. May mà cô bán hàng gần trường nhắc mình mua trước khi đi. Chỉ là một lời nhắc thôi nhưng mình thấy khá vui vì có người quan tâm.”',
      'Bạn không cần cố tìm một câu chuyện thật ý nghĩa. Cứ viết lại những gì bạn nhớ.',
      'Và nếu hôm nay không có gì khiến bạn vui, điều đó cũng bình thường. Bạn không cần ép mình phải biết ơn hay tìm mặt tích cực trong mọi chuyện.',
    ],
    summary: [
      'Bắt đầu từ một khoảnh khắc cụ thể.',
      'Viết lại chuyện đã xảy ra và cảm nhận của bạn.',
      'Không cần cố tìm điều tích cực trong một ngày khó khăn.'
    ],
    prompt:
        'Hôm nay có chuyện nhỏ nào khiến bạn vui hoặc cảm thấy dễ chịu hơn không?',
  ),
  StudyLesson(
    id: 'gratitude-thanks',
    title: 'Viết một lời cảm ơn thật cụ thể',
    minutes: 4,
    paragraphs: [
      'Thử nhớ lại một người đã giúp bạn trong ngày hôm nay. Đó có thể là bạn bè, người thân, đồng nghiệp hoặc thậm chí một người bạn chỉ gặp thoáng qua.',
      'Họ đã làm gì khiến bạn cảm thấy vui hoặc nhẹ nhõm hơn?',
      'Thay vì chỉ viết “Mình biết ơn vì được giúp đỡ”, hãy thử ghi lại cụ thể hơn một chút.',
      'Chẳng hạn:\n“Sáng nay mình dậy muộn, may mà bạn đợi mình ở cổng trường. Nhờ vậy mình bớt cuống và có một buổi sáng dễ chịu hơn.”',
      'Chỉ cần kể lại chuyện đã xảy ra và điều đó có ý nghĩa thế nào với bạn.',
      'Bạn cũng không nhất thiết phải gửi lời cảm ơn ngay. Đôi khi, viết ra là cách để mình nhận ra những điều tốt đẹp mà người khác đã làm cho mình.',
      'Còn nếu muốn, bạn hoàn toàn có thể chia sẻ lời cảm ơn ấy với họ sau.',
    ],
    summary: [
      'Nghĩ đến một người và việc cụ thể họ đã làm.',
      'Ghi lại vì sao hành động đó có ý nghĩa với bạn.',
      'Bạn có thể giữ lời cảm ơn cho riêng mình hoặc chia sẻ với người ấy.'
    ],
    prompt:
        'Hôm nay bạn muốn cảm ơn ai? Họ đã làm điều gì khiến bạn cảm thấy biết ơn?',
  ),
  StudyLesson(
    id: 'gratitude-carry',
    title: 'Một điều bạn muốn giữ lại cho ngày mai',
    minutes: 4,
    paragraphs: [
      'Sau khi viết nhật ký, bạn có thể dành thêm một chút thời gian để đọc lại những gì mình vừa ghi.',
      'Có điều gì hôm nay khiến bạn muốn nhớ đến vào ngày mai không? Đó có thể là một khoảnh khắc vui, một điều bạn nhận ra về bản thân, hoặc một thói quen nhỏ mà bạn muốn duy trì.',
      'Ví dụ, nếu hôm nay bạn thấy thoải mái hơn sau khi dành vài phút đi dạo, bạn có thể thử làm điều tương tự vào ngày mai.',
      'Không cần đặt mục tiêu quá lớn. Chỉ cần chọn một việc đơn giản mà bạn nghĩ mình có thể thực hiện.',
      'Và nếu ngày mai mọi chuyện không diễn ra như dự định thì cũng không sao. Bạn vẫn có thể thử lại vào một ngày khác.',
      'Đôi khi, chỉ cần nhớ lại một điều khiến mình vui hôm nay là đủ. Không phải bài nhật ký nào cũng cần kết thúc bằng một kế hoạch.',
    ],
    summary: [
      'Chọn một điều bạn muốn ghi nhớ.',
      'Nếu muốn tiếp tục, hãy bắt đầu bằng một việc đơn giản.',
      'Không cần biến mọi điều bạn viết thành mục tiêu phải đạt được.'
    ],
    prompt:
        'Có điều gì từ hôm nay mà bạn muốn tiếp tục hoặc ghi nhớ vào ngày mai không?',
  ),
];

const studyCase = StudyLesson(
  id: 'small-progress',
  title: 'Hôm nay, bạn đã làm được gì?',
  minutes: 5,
  paragraphs: [
    'Cuối ngày, chúng ta thường dễ nhớ đến những việc mình chưa hoàn thành hơn là những gì đã làm được.',
    'Có thể bạn vẫn còn một bài tập chưa xong, một cuộc hẹn chưa sắp xếp được hoặc vài công việc phải dời sang ngày mai.',
    'Nhưng thử nghĩ lại xem, hôm nay bạn đã làm được những gì?',
    'Có thể bạn đã hoàn thành một phần bài tập, chủ động hỏi lại khi chưa hiểu vấn đề, dành thời gian ăn uống đầy đủ hoặc giúp đỡ một người bạn.',
    'Những việc ấy có thể không quá lớn, nhưng chúng vẫn là những điều bạn đã dành thời gian và công sức để thực hiện.',
    'Nếu muốn nhìn lại ngày hôm nay, bạn có thể thử viết theo ba câu hỏi:',
    '1. Hôm nay mình đã làm được gì?\nLiệt kê một vài việc bạn đã hoàn thành, dù lớn hay nhỏ.',
    '2. Điều gì vẫn còn khó khăn?\nCó việc nào chưa diễn ra như bạn mong đợi không? Bạn gặp khó khăn ở đâu?',
    '3. Mình muốn làm gì tiếp theo?\nChọn một việc bạn muốn tiếp tục hoặc cải thiện vào ngày mai.',
    'Không cần so sánh hôm nay với hôm qua hay với người khác. Mục đích là để bạn nhìn lại ngày của mình một cách đầy đủ hơn, thay vì chỉ tập trung vào những việc chưa xong.',
  ],
  summary: [
    'Ghi lại những việc bạn đã làm được, kể cả việc nhỏ.',
    'Nhìn nhận cả điều thuận lợi lẫn điều còn khó khăn.',
    'Chọn bước tiếp theo, thay vì chỉ tập trung vào những thiếu sót.'
  ],
  prompt: 'Hôm nay bạn đã làm được việc gì mà bản thân cảm thấy hài lòng?',
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

/// "Cách thực hiện": each step's name and the question it asks.
const frameworkSteps = [
  (
    'Viết ra điều bạn đang nghĩ đến',
    'Có chuyện gì đang khiến bạn lo lắng hoặc suy nghĩ nhiều gần đây?'
  ),
  (
    'Phân biệt sự thật và suy đoán',
    'Điều gì bạn biết chắc đã xảy ra? Điều gì chỉ là điều bạn đang nghĩ hoặc '
        'lo rằng sẽ xảy ra?'
  ),
  (
    'Chọn một việc bạn có thể làm',
    'Với những gì bạn biết lúc này, có việc nhỏ nào bạn có thể làm để cải '
        'thiện tình hình không?'
  ),
];

/// The writing template's name (was "Clear My Mind").
const frameworkTitle = 'Gỡ rối suy nghĩ';

/// Its page: what it is for.
const frameworkIntro =
    'Viết ra những điều đang khiến bạn băn khoăn để sắp xếp lại suy nghĩ.';

const frameworkPrompt =
    'Điều gì đang làm tâm trí bạn bận rộn? Bạn biết chắc điều gì, đang suy đoán điều gì và có thể làm bước nhỏ nào?';
const challengeId = 'gratitude-seven';
const challengePrompts = [
  'Hôm nay có điều nhỏ nào khiến bạn thấy vui hoặc biết ơn không?',
  'Hôm nay có ai khiến một ngày của bạn dễ chịu hơn không?',
  'Có khoảnh khắc bình thường nào hôm nay mà bạn muốn nhớ lại không?',
  'Hôm nay, cơ thể đã giúp bạn làm được những gì?',
  'Có nơi nào bạn đến mà luôn cảm thấy thoải mái không?',
  'Gần đây, bạn nhận ra điều gì mới về bản thân?',
  'Có điều gì bạn muốn cảm ơn chính mình không?'
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
