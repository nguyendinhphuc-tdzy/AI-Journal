import 'package:ai_diary/features/journal/data/api_ai_service.dart';
import 'package:ai_diary/features/journal/data/quote_picker.dart';
import 'package:ai_diary/features/journal/data/quotes_vi.dart';
import 'package:flutter_test/flutter_test.dart';

AiAnalysis _analysis(String emotion, String observation,
        {List<String> topics = const []}) =>
    AiAnalysis(
      emotion: emotion,
      observation: observation,
      reflection: 'có lẽ bạn cần thêm thời gian cho mình.',
      question: 'điều gì giúp bạn nhẹ lòng hơn?',
      topics: topics,
    );

void main() {
  group('The team\'s list', () {
    test('80 quotes, numbered 1 to 80', () {
      expect([for (final quote in quotesVi) quote.id],
          [for (var i = 1; i <= 80; i++) i]);
    });

    test('no em dash anywhere; the screen adds a short one', () {
      for (final quote in quotesVi) {
        for (final text in [quote.text, quote.author, quote.work ?? '']) {
          expect(text, isNot(contains('—')), reason: '#${quote.id}');
        }
      }
    });

    test('tags are known topics; a quote with tags can be found', () {
      for (final quote in quotesVi) {
        for (final tag in quote.tags) {
          expect(quoteTopics.keys, contains(tag), reason: '#${quote.id}');
        }
        if (quote.pickable) {
          expect(quote.tags, isNotEmpty, reason: '#${quote.id}');
        }
      }
    });

    test('only quotes known to be the author\'s can be picked', () {
      for (final quote in quotesVi.where((quote) => quote.pickable)) {
        expect(quote.attribution, Attribution.known, reason: '#${quote.id}');
      }
      // In doubt: to check before ever showing them.
      expect(
          [
            for (final quote in quotesVi)
              if (quote.attribution == Attribution.doubtful) quote.id
          ],
          [7, 12, 22, 33, 39, 46, 49, 50, 51, 52, 55]);
    });
  });

  group('Picking from the analysis', () {
    const picker = QuotePicker();

    test('school pressure: a quote about pressure', () {
      final quote = picker.pick(
          _analysis('áp lực', 'việc học dồn lại khiến bạn thấy ngợp.'),
          entry: 'Bài tập nhiều quá');
      expect(quote, isNotNull);
      expect(quote!.tags, contains('áp lực'));
    });

    test('sad after a break-up: Xuân Diệu', () {
      final quote = picker.pick(
          _analysis('buồn', 'bạn vừa chia tay người yêu.'),
          entry: 'Hôm nay chia tay');
      expect(quote?.id, 47);
    });

    test('topics from the backend count too', () {
      final quote = picker.pick(
          _analysis('lo lắng', 'bạn nghĩ nhiều về ngày mai.',
              topics: ['học tập']),
          entry: '');
      expect(quote, isNotNull);
      expect(quote!.tags, anyOf(contains('lo lắng'), contains('học tập')));
    });

    test('nothing fits: no quote rather than one beside the point', () {
      expect(
          picker.pick(_analysis('bình thường', 'một ngày như mọi ngày.'),
              entry: 'Không có gì đặc biệt'),
          isNull);
    });

    test('"bạn" in the AI\'s words is not about friendship', () {
      final quote = picker.pick(
          _analysis('bình thường', 'bạn cảm thấy bạn đang ổn.'),
          entry: 'ổn');
      expect(quote, isNull);
    });

    test('a doubtful or set-aside quote is never picked', () {
      const only = QuotePicker([
        Quote(1, 'A', 'X',
            attribution: Attribution.doubtful, tags: ['buồn']),
        Quote(2, 'B', 'Y', autoPick: false, tags: ['buồn']),
      ]);
      expect(only.pick(_analysis('buồn', 'buồn quá.')), isNull);
    });

    test('the same entry gets the same quote', () {
      final analysis = _analysis('buồn', 'bạn thấy trống rỗng.');
      final first = picker.pick(analysis, seed: 'entry-1');
      expect(picker.pick(analysis, seed: 'entry-1'), same(first));
    });
  });
}
