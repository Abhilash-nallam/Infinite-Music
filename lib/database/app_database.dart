import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// Thrown by applySyncResult when the server's reported catalogVersion is
/// lower than what's already stored locally. The local cursor is a
/// security/consistency boundary, not just a cache hint — it must never
/// regress, so this is a hard failure, not a value the caller can silently
/// ignore or clamp.
class StaleSyncException implements Exception {
  final int localVersion;
  final int serverVersion;
  StaleSyncException({required this.localVersion, required this.serverVersion});

  @override
  String toString() =>
      'StaleSyncException: server returned catalogVersion=$serverVersion, '
      'which is behind the local cursor ($localVersion). Rejected — local '
      'catalog and cursor are unchanged.';
}

class InvalidSyncException implements Exception {
  final String message;
  InvalidSyncException(this.message);

  @override
  String toString() => 'InvalidSyncException: $message';
}

/// The app's local catalog cache — songs synced from the backend live here,
/// not just in memory. This is what makes the catalog browseable offline
/// and what the delta-sync engine reads/writes against (roadmap section 10).
@DriftDatabase(tables: [Songs, SyncState])
class AppDatabase extends _$AppDatabase {
  AppDatabase({QueryExecutor? executor}) : super(executor ?? _openConnection());

  /// Test-only constructor for an in-memory database, so unit tests never
  /// touch disk or leak state between runs. See test/sync_service_test.dart.
  AppDatabase.forTesting() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  /// Audit fix (#9): explicit migration strategy instead of relying on
  /// Drift's implicit default, so future schema changes for Phase B/C
  /// (playlists, albums, artists, download queue tables, etc.) can be added
  /// as non-destructive `onUpgrade` steps rather than someone reaching for
  /// a destructive drop-and-recreate later. No migrations exist yet because
  /// no schema version bump has happened yet — this just puts the seam in
  /// place ahead of time.
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // Example of the pattern future migrations should follow —
          // additive only, never DROP/recreate a table with existing data:
          //
          // if (from < 2) {
          //   await m.addColumn(songs, songs.someNewColumn);
          // }
        },
      );

  Stream<List<SongRow>> watchAllSongs() {
    return (select(songs)..orderBy([(t) => OrderingTerm.asc(t.title)])).watch();
  }

  Future<SongRow?> getSongById(String id) {
    return (select(songs)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> getCatalogVersion() async {
    final row =
        await (select(syncState)..where((t) => t.id.equals(0))).getSingleOrNull();
    return row?.catalogVersion ?? 0;
  }

  Future<void> setCatalogVersion(int version) async {
    await into(syncState).insertOnConflictUpdate(
      SyncStateCompanion.insert(
        id: const Value(0),
        catalogVersion: Value(version),
      ),
    );
  }

  /// Audit fix (#1): applies an entire sync result — upserts, deletions,
  /// and the new cursor — as ONE atomic transaction. If anything in here
  /// throws (disk full, constraint violation, whatever), Drift rolls the
  /// whole thing back and `getCatalogVersion()` still returns the OLD
  /// value. That's what "advance the cursor only after all changes are
  /// successfully committed" means in practice: a crash mid-sync can never
  /// leave the local cursor ahead of what's actually stored.
  ///
  /// Hardening pass fix (#1): the cursor must NEVER move backwards, even if
  /// the server response claims a lower catalogVersion than what's already
  /// stored locally — whether from a buggy server, a stale/replayed
  /// response, or something actively malicious. The check happens INSIDE
  /// the transaction (reading the current cursor with the same connection
  /// used for the write) so there's no race between reading the cursor and
  /// applying the result. On rejection: throw before touching any table —
  /// no partial write, no version update, local catalog is provably
  /// byte-for-byte unchanged.
  Future<void> applySyncResult({
    required List<SongsCompanion> upserts,
    required List<String> deletedIds,
    required int newCatalogVersion,
  }) async {
    await transaction(() async {
      final currentVersion = await getCatalogVersion();
      if (newCatalogVersion < 0) {
        throw InvalidSyncException('catalogVersion cannot be negative');
      }
      if (newCatalogVersion < currentVersion) {
        throw StaleSyncException(
          localVersion: currentVersion,
          serverVersion: newCatalogVersion,
        );
      }

      // A response that changes records must also advance the catalog
      // cursor. Accepting a same-version mutation would allow a malformed
      // or replayed response to mutate local state indefinitely.
      if (newCatalogVersion == currentVersion &&
          (upserts.isNotEmpty || deletedIds.isNotEmpty)) {
        throw InvalidSyncException(
          'catalogVersion did not advance but the sync contained changes',
        );
      }

      // Remote catalog sync must never overwrite local-only state such as
      // likes and downloaded-file metadata. For existing rows we use an
      // UPDATE with the remote companion; absent local columns remain
      // untouched. For new rows we INSERT and let their local defaults
      // initialize to false/null.
      for (final companion in upserts) {
        final id = companion.id.value;
        final existing = await getSongById(id);
        if (existing == null) {
          await into(songs).insert(companion);
        } else {
          await (update(songs)..where((t) => t.id.equals(id))).write(companion);
        }
      }

      if (deletedIds.isNotEmpty) {
        await (delete(songs)..where((t) => t.id.isIn(deletedIds))).go();
      }
      await setCatalogVersion(newCatalogVersion);
    });
  }

  Future<void> setLiked(String id, bool liked) async {
    await (update(songs)..where((t) => t.id.equals(id)))
        .write(SongsCompanion(isLiked: Value(liked)));
  }

  Future<void> setDownloaded(String id, {required bool isDownloaded, String? localPath}) async {
    await (update(songs)..where((t) => t.id.equals(id))).write(
      SongsCompanion(
        isDownloaded: Value(isDownloaded),
        localPath: Value(localPath),
      ),
    );
  }

  /// Audit fix (#5): local, offline-capable search across title, artist,
  /// and album name. This is the PRIMARY search path — the backend's
  /// /search endpoint is a secondary/future capability only, per the audit.
  Future<List<SongRow>> searchSongs(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    final pattern = '%$trimmed%';
    return (select(songs)
          ..where((t) =>
              t.title.like(pattern) |
              t.artist.like(pattern) |
              t.albumName.like(pattern))
          ..orderBy([(t) => OrderingTerm.asc(t.title)]))
        .get();
  }

  /// Reactive variant for a live-updating search UI (updates automatically
  /// if the underlying catalog changes while the user has a query active).
  Stream<List<SongRow>> watchSearchSongs(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return Stream.value(const []);
    final pattern = '%$trimmed%';
    return (select(songs)
          ..where((t) =>
              t.title.like(pattern) |
              t.artist.like(pattern) |
              t.albumName.like(pattern))
          ..orderBy([(t) => OrderingTerm.asc(t.title)]))
        .watch();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'infinite_music.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
