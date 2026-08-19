import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:infinite_music/database/app_database.dart';
import 'package:infinite_music/services/api_service.dart';
import 'package:infinite_music/services/sync_service.dart';
import 'package:infinite_music/providers/catalog_provider.dart';

class _FakeApi implements CatalogApi {
  SyncResult? nextResult;
  Object? nextError;

  @override
  Future<SyncResult> fetchSync(int sinceVersion) async {
    if (nextError != null) throw nextError!;
    return nextResult ?? SyncResult(upserts: [], deletedIds: [], catalogVersion: sinceVersion);
  }
}

void main() {
  group('CatalogProvider — the UI-facing single source of truth', () {
    late AppDatabase db;
    late _FakeApi api;
    late CatalogProvider provider;

    setUp(() {
      db = AppDatabase.forTesting();
      api = _FakeApi();
    });
    tearDown(() {
      provider.dispose();
      db.close();
    });

    test('a successful sync populates songs and clears any prior error', () async {
      api.nextResult = SyncResult(
        upserts: [
          SongsCompanion.insert(id: 'p1', title: 'A', artist: 'X'),
          SongsCompanion.insert(id: 'p2', title: 'B', artist: 'Y'),
        ],
        deletedIds: [],
        catalogVersion: 2,
      );
      provider = CatalogProvider(db: db, syncService: SyncService(api: api, db: db), autoSync: false);
      await provider.syncNow(); // constructor's own syncNow already ran; re-run deterministically

      expect(provider.hasCatalog, true);
      expect(provider.songs.length, 2);
      expect(provider.syncError, isNull);
      expect(provider.isSyncing, false);
    });

    test('a failed sync sets syncError but keeps the previously cached songs', () async {
      api.nextResult = SyncResult(
        upserts: [SongsCompanion.insert(id: 'p1', title: 'A', artist: 'X')],
        deletedIds: [],
        catalogVersion: 1,
      );
      provider = CatalogProvider(db: db, syncService: SyncService(api: api, db: db), autoSync: false);
      await provider.syncNow();
      expect(provider.songs.length, 1);

      api.nextResult = null;
      api.nextError = ApiException('offline');
      await provider.syncNow();

      expect(provider.syncError, isNotNull);
      expect(provider.songs.length, 1, reason: 'cached catalog must survive a failed sync');
      expect(provider.hasCatalog, true);
    });

    test('downloadedSongs and likedSongs filter correctly from the same source of truth', () async {
      api.nextResult = SyncResult(
        upserts: [
          SongsCompanion.insert(id: 'p1', title: 'A', artist: 'X', isDownloaded: const Value(true)),
          SongsCompanion.insert(id: 'p2', title: 'B', artist: 'Y', isLiked: const Value(true)),
          SongsCompanion.insert(id: 'p3', title: 'C', artist: 'Z'),
        ],
        deletedIds: [],
        catalogVersion: 3,
      );
      provider = CatalogProvider(db: db, syncService: SyncService(api: api, db: db), autoSync: false);
      await provider.syncNow();

      expect(provider.downloadedSongs.map((s) => s.id), ['p1']);
      expect(provider.likedSongs.map((s) => s.id), ['p2']);
    });

    test('watchSearch streams local results without any network call', () async {
      api.nextResult = SyncResult(
        upserts: [
          SongsCompanion.insert(id: 'p1', title: 'Neon Hours', artist: 'Levit'),
          SongsCompanion.insert(id: 'p2', title: 'Static Bloom', artist: 'Rhea K.'),
        ],
        deletedIds: [],
        catalogVersion: 2,
      );
      provider = CatalogProvider(db: db, syncService: SyncService(api: api, db: db), autoSync: false);
      await provider.syncNow();

      final results = await provider.watchSearch('neon').first;
      expect(results.map((s) => s.id), ['p1']);
    });

    test('toggleLiked flips the flag and the reactive stream reflects it', () async {
      api.nextResult = SyncResult(
        upserts: [SongsCompanion.insert(id: 'p1', title: 'A', artist: 'X')],
        deletedIds: [],
        catalogVersion: 1,
      );
      provider = CatalogProvider(db: db, syncService: SyncService(api: api, db: db), autoSync: false);
      await provider.syncNow();
      expect(provider.songs.first.isLiked, false);

      await provider.toggleLiked(provider.songs.first);
      // Give the watchAllSongs() stream a microtask to deliver the update.
      await Future.delayed(Duration.zero);

      expect(provider.songs.first.isLiked, true);
    });
  });
}
