/// AI text as shown: the model often writes all in lower case ("hòa bình",
/// "mọi chuyện có thể…"), so the first letter of each sentence is raised.
/// Only letters that start a sentence change; the rest is kept as written.
String sentenceCase(String text) {
  final out = StringBuffer();
  var start = true;
  for (final rune in text.runes) {
    var char = String.fromCharCode(rune);
    if (start) {
      final upper = char.toUpperCase();
      if (upper != char.toLowerCase()) {
        // A letter: the sentence begins here.
        char = upper;
        start = false;
      } else if (_isDigit(char)) {
        start = false;
      }
    } else if ('.!?…\n'.contains(char)) {
      start = true;
    }
    out.write(char);
  }
  return out.toString();
}

bool _isDigit(String char) => '0123456789'.contains(char);
