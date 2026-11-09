import 'package:flutter/foundation.dart';

// In-memory prototype data shared by Home and Reflection; resets on restart.
final ValueNotifier<List<Map<String, dynamic>>> savedThisWeekItems =
    ValueNotifier<List<Map<String, dynamic>>>([
  {
    'type': 'insight',
    'title': 'Chuyện học hành',
    'content': 'Dạo này, bạn có vẻ không muốn nghĩ nhiều đến chuyện học.',
    'mood': 'Bồn chồn',
    'moodIcon': '😕',
    'date': 'Hôm nay',
    'timestamp': '15 Thg 10 · 15:15',
  },
  {
    'type': 'quote',
    'content':
        'Hãy làm những gì bạn có thể, bằng những gì bạn có, ngay tại nơi bạn đang đứng.',
    'author': 'Theodore Roosevelt',
    'date': 'Hôm nay',
    'timestamp': '15 Thg 10 · 15:15',
  },
]);
