import 'analysis_archive.dart';
import 'cloud_ai_api.dart';

/// Brings the account's server-kept analyses into the device's
/// [AnalysisArchive], so the lists, the week's chart and "Xem phân tích AI"
/// show them on any phone.
///
/// Reads only: it never runs the AI and never sends anything up. An
/// analysis kept only on this device stays as it is (decision 29/10/2026:
/// older device analyses are not uploaded), unless the server has one for
/// the same or a newer version of the entry.
class CloudAnalysisSync {
  CloudAnalysisSync._();

  /// One sync at a time per account; a later caller shares it.
  static final _running = <String?, Future<void>>{};

  /// When each account last synced; [maybeSync] skips a recent one.
  static final _lastSync = <String?, DateTime>{};

  static const minGap = Duration(seconds: 30);

  /// Syncs unless one ran within [minGap]. Failure leaves the cache as is.
  static Future<void> maybeSync(CloudAiApi api, {String? userId}) async {
    final last = _lastSync[userId];
    if (last != null && DateTime.now().difference(last) < minGap) return;
    await sync(api, userId: userId);
  }

  static Future<void> sync(CloudAiApi api, {String? userId}) =>
      _running[userId] ??= _sync(api, userId).whenComplete(() {
        _running.remove(userId);
      });

  static Future<void> _sync(CloudAiApi api, String? userId) async {
    final cloud = await api.analyses();
    final archive = await AnalysisArchive.open(userId: userId);
    for (final remote in cloud) {
      await keep(archive, remote);
    }
    _lastSync[userId] = DateTime.now();
  }

  /// Keeps [remote] in [archive] unless the device has a newer one for that
  /// entry. The quote shown with a device copy is kept.
  static Future<void> keep(AnalysisArchive archive, CloudAnalysis remote,
      {({String text, String author})? quote}) async {
    final local = archive.of(remote.entryId);
    if (local != null && local.bodyVersion > remote.bodyVersion) return;
    if (local != null &&
        local.cloud &&
        local.bodyVersion == remote.bodyVersion &&
        local.savedAt == remote.savedAt &&
        local.feedback == remote.feedback) {
      return; // Unchanged: no write, no rebuild.
    }
    await archive.save(SavedAnalysis(
      entryId: remote.entryId,
      bodyVersion: remote.bodyVersion,
      savedAt: remote.savedAt,
      analysis: remote.analysis,
      quote: quote ?? local?.quote,
      cloud: true,
      feedback: remote.feedback,
    ));
  }

  /// Forget throttling (e.g. a new session).
  static void reset() {
    _running.clear();
    _lastSync.clear();
  }
}
