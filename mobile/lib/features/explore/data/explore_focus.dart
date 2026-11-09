import 'package:flutter/foundation.dart';

/// A friend's 24-hour moment to show on the map, asked for from outside
/// Khám phá (a tapped push notification): the shell goes to Khám phá, which
/// turns friends' moments on, opens that one and clears this.
abstract final class ExploreFocus {
  static final post = ValueNotifier<String?>(null);
}
