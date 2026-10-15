import 'package:flutter/foundation.dart';

// In-memory prototype data shared by Home and Reflection; resets on restart.
final ValueNotifier<List<Map<String, dynamic>>> savedThisWeekItems =
    ValueNotifier<List<Map<String, dynamic>>>([
  {
    'type': 'insight',
    'title': 'Avoiding school',
    'content':
        "School is the thing you've been trying not to think about right now.",
    'mood': 'Uneasy',
    'moodIcon': '😕',
    'date': 'Today',
    'timestamp': 'Oct 15 - 15:15',
  },
  {
    'type': 'quote',
    'content': 'Do what you can, with what you have, where you are.',
    'author': 'Theodore Roosevelt',
    'date': 'Today',
    'timestamp': 'Oct 15 - 15:15',
  },
]);
