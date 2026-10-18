import 'package:flutter/foundation.dart';

import '../../journal/data/journal_entry.dart';
import '../../journal/data/reflection_service.dart';
import '../data/onboarding_store.dart';

enum ReflectionStatus { idle, pending, ready, failed }

/// The AI reflection on the first entry, owned by the flow.
///
/// Asks only when AI is on, and only for a saved entry. A result belongs to
/// one (entry id, body version): a newer version, a newer request, or AI
/// being switched off in the meantime all make a late response be ignored.
/// Retrying asks again for the same entry; it never creates one.
class FirstReflection extends ChangeNotifier {
  FirstReflection({required this.service, required this.store});

  final ReflectionService service;
  final OnboardingStore store;

  Reflection? _result;
  var _status = ReflectionStatus.idle;
  var _request = 0;
  var _disposed = false;

  ReflectionStatus get status => _status;

  /// The reflection for exactly this version of [entry], if there is one.
  Reflection? resultFor(JournalEntry entry) {
    final result = _result;
    return result != null &&
            result.entryId == entry.id &&
            result.bodyVersion == entry.bodyVersion
        ? result
        : null;
  }

  /// Asks for a reflection on [entry]; reuses one for the same version.
  void request(JournalEntry entry) {
    if (store.aiEnabled != true) {
      cancel();
      return;
    }
    if (resultFor(entry) != null) {
      _status = ReflectionStatus.ready;
      _notify();
      return;
    }
    final request = ++_request;
    _status = ReflectionStatus.pending;
    _notify();
    service.reflect(entry).then((result) {
      if (request != _request) return; // superseded or cancelled
      if (store.aiEnabled != true) {
        _status = ReflectionStatus.idle;
      } else if (result.entryId == entry.id &&
          result.bodyVersion == entry.bodyVersion) {
        _result = result;
        _status = ReflectionStatus.ready;
      } else {
        return;
      }
      _notify();
    }, onError: (Object _) {
      if (request != _request) return;
      _status = ReflectionStatus.failed;
      _notify();
    });
  }

  /// Stops waiting: a response still in flight is ignored when it lands.
  /// (The mock cannot be cancelled; the API version should cancel too.)
  void cancel() {
    _request++;
    if (_status == ReflectionStatus.pending) {
      _status = ReflectionStatus.idle;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _request++;
    super.dispose();
  }
}
