import 'journal_entry.dart';

/// An AI reflection on one version of an entry. It belongs to
/// ([entryId], [bodyVersion]), so it is never shown for edited text.
class Reflection {
  const Reflection({
    required this.entryId,
    required this.bodyVersion,
    required this.text,
    required this.simulated,
  });

  final String entryId;
  final int bodyVersion;
  final String text;

  /// True for the stand-in: the UI then says it is simulated.
  final bool simulated;
}

/// Asks for a reflection on a saved entry. The API version should call
/// `POST /api/v1/ai/reflection` through the backend (never a provider
/// directly) and support cancelling.
abstract interface class ReflectionService {
  Future<Reflection> reflect(JournalEntry entry);
}

/// Deterministic stand-in (ADR-005): nothing leaves the device. It answers
/// from which blanks were filled, never from guesses about the person, and
/// in open, tentative language rather than conclusions.
class MockReflectionService implements ReflectionService {
  MockReflectionService({this.delay = const Duration(seconds: 3)});

  /// Stands in for a real service's latency so the wait can be seen in the
  /// demo. It is the service's delay, not a UI minimum: a faster service is
  /// shown at once.
  final Duration delay;

  @override
  Future<Reflection> reflect(JournalEntry entry) async {
    await Future<void>.delayed(delay);
    return Reflection(
      entryId: entry.id,
      bodyVersion: entry.bodyVersion,
      text: textFor(entry),
      simulated: true,
    );
  }

  static String textFor(JournalEntry entry) {
    final fields = entry.content.guided?.fields ?? const {};
    final lines = <String>[
      if (fields.containsKey('cause'))
        'Bạn đã thử gọi tên điều có thể đang ảnh hưởng tới cảm xúc của mình. '
            'Chỉ cần nhận ra nó thôi, đôi khi mọi thứ đã rõ hơn một chút.',
      if (fields.containsKey('thought'))
        'Điều đang ở trong đầu bạn có lẽ đáng được viết thêm vài dòng vào lúc '
            'khác, nếu bạn muốn quay lại với nó.',
      if (fields.containsKey('hope'))
        'Điều bạn mong đợi trong vài ngày tới có thể là một điểm nhỏ để bạn '
            'hướng tới, dù mọi chuyện diễn ra thế nào.',
    ];
    if (lines.isEmpty) {
      lines.add('Những dòng bạn vừa viết là một khởi đầu. Bạn có thể đọc lại '
          'chúng vào lúc khác để xem điều gì vẫn còn đúng với mình.');
    }
    return lines.take(2).join('\n\n');
  }
}
