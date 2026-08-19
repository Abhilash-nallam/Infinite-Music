import '../database/app_database.dart';
import 'api_service.dart';

/// Implements the roadmap's auto-sync rules (section 10): always sync via
/// delta from the last known version rather than re-fetching the whole
/// catalog, apply additions/updates and deletions, then persist the new
/// version as the sync cursor.
///
/// Audit fix (#1): the commit is now atomic — see
/// AppDatabase.applySyncResult, which wraps the upserts, deletions, and
/// cursor advance in a single Drift transaction. If the app is killed or
/// throws partway through, the local cursor never ends up ahead of what's
/// actually persisted, so the next sync correctly re-requests anything
/// that didn't make it in.
class SyncService {
  final CatalogApi api;
  final AppDatabase db;
  Future<void>? _inFlight;

  SyncService({required this.api, required this.db});

  /// Coalesces concurrent refresh requests. Without this guard, an automatic
  /// launch sync and a pull-to-refresh could both read the same cursor and
  /// race to commit responses in an arbitrary order. The database rejects
  /// regressions, but preventing the duplicate request is cleaner and avoids
  /// unnecessary network traffic.
  Future<void> syncCatalog() {
    final existing = _inFlight;
    if (existing != null) return existing;

    final future = _performSync();
    _inFlight = future;
    future.then<void>(
      (_) {
        if (identical(_inFlight, future)) _inFlight = null;
      },
      onError: (Object error, StackTrace stack) {
        if (identical(_inFlight, future)) _inFlight = null;
      },
    );
    return future;
  }

  Future<void> _performSync() async {
    final currentVersion = await db.getCatalogVersion();
    final result = await api.fetchSync(currentVersion);

    if (result.catalogVersion < currentVersion) {
      throw StaleSyncException(
        localVersion: currentVersion,
        serverVersion: result.catalogVersion,
      );
    }

    await db.applySyncResult(
      upserts: result.upserts,
      deletedIds: result.deletedIds,
      newCatalogVersion: result.catalogVersion,
    );
  }
}
