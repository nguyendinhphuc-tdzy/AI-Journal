import 'package:flutter/foundation.dart';

// In-memory prototype data shared by Home and Reflection; resets on restart.
final ValueNotifier<List<Map<String, dynamic>>> savedThisWeekItems =
    ValueNotifier<List<Map<String, dynamic>>>([
  {
    'type': 'insight',
    'title': 'Áp lực việc học',
    'content': 'Việc học là thứ mà hiện tại bạn đang cố gắng không nghĩ tới.',
    'mood': 'Bồn chồn',
    'moodIcon': '😕',
    'date': 'Hôm nay',
    'timestamp': '15 Thg 10 · 15:15',
  },
  {
    'type': 'quote',
    'content':
        'Hãy làm những gì bạn có thể, với những gì bạn đang có, ngay tại nơi bạn đang đứng.',
    'author': 'Theodore Roosevelt',
    'date': 'Hôm nay',
    'timestamp': '15 Thg 10 · 15:15',
  },
]);
