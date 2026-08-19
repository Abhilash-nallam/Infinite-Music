import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:infinite_music/database/app_database.dart';
import 'package:infinite_music/services/api_service.dart';
import 'package:infinite_music/services/sync_service.dart';

SongsCompanion _companion(String id, {String title = 'T', int version = 1}) {
  return SongsCompanion.insert(id: id, title: title, artist: 'A', version: Value(version));
}

/// Scripted fake standing in for the real ApiService, so these tests never
/// touch a network — they verify SyncService's OWN logic (does it correctly
/// apply what the API returns?), not the HTTP layer, which is covered
/// separately by the backend's own test suite for the real contract shape.
class FakeCatalogApi implements CatalogApi {
  final List<SyncResult> responses;
  int callCount = 0;
  final List<int> requestedVersions = [];

  FakeCatalogApi(this.responses);

  @override
  Future<SyncResult> fetchSync(int sinceVersion) async {
    requestedVersions.add(sinceVersion);
    if (callCount >= responses.length) {
      throw StateError(
        'FakeCatalogApi received more calls than scripted responses '
        '(${responses.length}). This means SyncService called fetchSync() '
        'more times than the test scenario expected — either the test\'s '
        'response list is incomplete, or SyncService is calling the API '
        'more often than intended. Failing loudly instead of silently '
        'reusing the last scripted response.',
      );
    }
    final result = responses[callCount];
    callCount++;
    return result;
  }
}

class _BlockingCatalogApi implements CatalogApi {
  final Completer<SyncResult> completer;
  int callCount = 0;

  _BlockingCatalogApi(this.completer);

  @override
  Future<SyncResult> fetchSync(int sinceVersion) {
    callCount++;
    return completer.future;
  }
}

class ThrowingCatalogApi implements CatalogApi {
  @override
  Future<SyncResult> fetchSync(int sinceVersion) async {
    throw ApiException('simulated network failure');
  }
}

void main() {
  group('SyncService — initial and delta sync', () {
    late AppDatabase db;
    tearDown(() => db.close());

    test('initial full sync (cursor starts at 0) populates the DB completely', () async {
      db = AppDatabase.forTesting();
      final api = FakeCatalogApi([
        SyncResult(
          upserts: [_companion('s1', version: 1), _companion('s2', version: 2)],
          deletedIds: [],
          catalogVersion: 2,
        ),
      ]);
      final sync = SyncService(api: api, db: db);

      await sync.syncCatalog();

      expect(api.requestedVersions, [0]); // asked from cursor 0 on a fresh DB
      final rows = await db.watchAllSongs().first;
      expect(rows.length, 2);
      expect(await db.getCatalogVersion(), 2);
    });

    test('a second sync requests from the cursor left by the first, not from 0 again', () async {
      db = AppDatabase.forTesting();
      final api = FakeCatalogApi([
        SyncResult(upserts: [_companion('s1', version: 1)], deletedIds: [], catalogVersion: 1),
        SyncResult(upserts: [_companion('s2', version: 2)], deletedIds: [], catalogVersion: 2),
      ]);
      final sync = SyncService(api: api, db: db);

      await sync.syncCatalog();
      await sync.syncCatalog();

      expect(api.requestedVersions, [0, 1]);
      final rows = await db.watchAllSongs().first;
      expect(rows.map((r) => r.id).toSet(), {'s1', 's2'});
    });

    test('repeated sync when nothing changed leaves the DB and cursor stable', () async {
      db = AppDatabase.forTesting();
      final api = FakeCatalogApi([
        SyncResult(upserts: [_companion('s1', version: 1)], deletedIds: [], catalogVersion: 1),
        SyncResult(upserts: [], deletedIds: [], catalogVersion: 1),
        SyncResult(upserts: [], deletedIds: [], catalogVersion: 1),
      ]);
      final sync = SyncService(api: api, db: db);

      await sync.syncCatalog();
      await sync.syncCatalog();
      await sync.syncCatalog();

      expect(await db.getCatalogVersion(), 1);
      final rows = await db.watchAllSongs().first;
      expect(rows.length, 1);
    });

    test('a deletion returned by the API removes the row locally', () async {
      db = AppDatabase.forTesting();
      final api = FakeCatalogApi([
        SyncResult(
          upserts: [_companion('s1', version: 1), _companion('s2', version: 2)],
          deletedIds: [],
          catalogVersion: 2,
        ),
        SyncResult(upserts: [], deletedIds: ['s1'], catalogVersion: 3),
      ]);
      final sync = SyncService(api: api, db: db);

      await sync.syncCatalog();
      await sync.syncCatalog();

      final rows = await db.watchAllSongs().first;
      expect(rows.map((r) => r.id), ['s2']);
    });

    test('cursor strictly increases across a realistic multi-sync sequence', () async {
      db = AppDatabase.forTesting();
      final api = FakeCatalogApi([
        SyncResult(upserts: [_companion('s1', version: 1)], deletedIds: [], catalogVersion: 1),
        SyncResult(upserts: [_companion('s2', version: 3)], deletedIds: [], catalogVersion: 3),
        SyncResult(upserts: [], deletedIds: ['s1'], catalogVersion: 4),
      ]);
      final sync = SyncService(api: api, db: db);

      final cursors = <int>[];
      for (var i = 0; i < 3; i++) {
        await sync.syncCatalog();
        cursors.add(await db.getCatalogVersion());
      }

      expect(cursors, [1, 3, 4]);
      for (var i = 1; i < cursors.length; i++) {
        expect(cursors[i], greaterThan(cursors[i - 1]));
      }
    });

    test('concurrent sync calls are coalesced into one network request', () async {
      db = AppDatabase.forTesting();
      final completer = Completer<SyncResult>();
      final api = _BlockingCatalogApi(completer);
      final sync = SyncService(api: api, db: db);

      final first = sync.syncCatalog();
      final second = sync.syncCatalog();
      expect(identical(first, second), true);

      // syncCatalog() starts asynchronous DB cursor loading before reaching
      // fetchSync(). Give that in-flight operation one event-loop turn to
      // reach the API before asserting the request count.
      await Future<void>.delayed(Duration.zero);
      expect(api.callCount, 1);

      completer.complete(
        SyncResult(upserts: [_companion('s1', version: 1)], deletedIds: [], catalogVersion: 1),
      );
      await first;
      expect(await db.getCatalogVersion(), 1);
    });

    test('offline: a failed sync leaves the previously cached catalog fully intact', () async {
      db = AppDatabase.forTesting();
      final workingApi = FakeCatalogApi([
        SyncResult(upserts: [_companion('s1', version: 1)], deletedIds: [], catalogVersion: 1),
      ]);
      await SyncService(api: workingApi, db: db).syncCatalog();
      final before = await db.watchAllSongs().first;
      expect(before.length, 1);

      // Now simulate the network dropping — SyncService.syncCatalog() should
      // propagate the failure (so CatalogProvider can show an error state)
      // WITHOUT touching the already-cached rows.
      final offlineSync = SyncService(api: ThrowingCatalogApi(), db: db);
      await expectLater(offlineSync.syncCatalog(), throwsA(isA<ApiException>()));

      final after = await db.watchAllSongs().first;
      expect(after.length, 1);
      expect(after.first.id, 's1');
      expect(await db.getCatalogVersion(), 1, reason: 'cursor must not move on a failed sync');
    });

    // Hardening pass — same scenario as database_test.dart but exercised
    // through the full SyncService path (API -> SyncService -> DB), not
    // just the DB layer directly, proving the rejection holds end-to-end.
    test(
        'end-to-end: local cursor=10, server reports catalogVersion=8 -> '
        'sync rejected, cursor stays 10, catalog unchanged', () async {
      db = AppDatabase.forTesting();
      final api = FakeCatalogApi([
        SyncResult(
          upserts: [_companion('keep1'), _companion('keep2')],
          deletedIds: [],
          catalogVersion: 10,
        ),
      ]);
      await SyncService(api: api, db: db).syncCatalog();
      expect(await db.getCatalogVersion(), 10);

      final staleApi = FakeCatalogApi([
        SyncResult(
          upserts: [_companion('malicious')],
          deletedIds: ['keep1'],
          catalogVersion: 8, // behind the local cursor
        ),
      ]);
      final staleSync = SyncService(api: staleApi, db: db);

      await expectLater(staleSync.syncCatalog(), throwsA(isA<StaleSyncException>()));

      expect(await db.getCatalogVersion(), 10, reason: 'cursor must not regress to 8');
      final rows = await db.watchAllSongs().first;
      expect(rows.map((r) => r.id).toSet(), {'keep1', 'keep2'});
      expect(rows.any((r) => r.id == 'malicious'), false);
    });
  });
}
