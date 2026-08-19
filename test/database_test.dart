import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:infinite_music/database/app_database.dart';

SongsCompanion _song(String id, {String title = 'T', String artist = 'A', String? albumName}) {
  return SongsCompanion.insert(
    id: id,
    title: title,
    artist: artist,
    albumName: Value(albumName),
  );
}

void main() {
  group('AppDatabase.applySyncResult — atomic commit (audit fix #1)', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.forTesting());
    tearDown(() => db.close());

    test('upserts songs and advances the cursor together', () async {
      await db.applySyncResult(
        upserts: [_song('a1'), _song('a2')],
        deletedIds: [],
        newCatalogVersion: 2,
      );
      final rows = await db.watchAllSongs().first;
      expect(rows.length, 2);
      expect(await db.getCatalogVersion(), 2);
    });

    test('a later sync only needs to touch what changed (delta semantics)', () async {
      await db.applySyncResult(upserts: [_song('a1'), _song('a2')], deletedIds: [], newCatalogVersion: 2);
      await db.applySyncResult(
        upserts: [_song('a3')],
        deletedIds: [],
        newCatalogVersion: 3,
      );
      final rows = await db.watchAllSongs().first;
      expect(rows.map((r) => r.id).toSet(), {'a1', 'a2', 'a3'});
      expect(await db.getCatalogVersion(), 3);
    });

    test('deletions remove the row and advance the cursor in the same commit', () async {
      await db.applySyncResult(upserts: [_song('a1'), _song('a2')], deletedIds: [], newCatalogVersion: 2);
      await db.applySyncResult(upserts: [], deletedIds: ['a1'], newCatalogVersion: 3);

      final rows = await db.watchAllSongs().first;
      expect(rows.map((r) => r.id), ['a2']);
      expect(await db.getCatalogVersion(), 3);
    });

    test('an upsert with the same id as an existing row updates it in place, no duplicate', () async {
      await db.applySyncResult(upserts: [_song('a1', title: 'Old Title')], deletedIds: [], newCatalogVersion: 1);
      await db.applySyncResult(upserts: [_song('a1', title: 'New Title')], deletedIds: [], newCatalogVersion: 2);

      final rows = await db.watchAllSongs().first;
      expect(rows.length, 1);
      expect(rows.first.title, 'New Title');
    });

    test('repeated sync with no changes leaves the DB and cursor untouched', () async {
      await db.applySyncResult(upserts: [_song('a1')], deletedIds: [], newCatalogVersion: 1);
      final before = await db.watchAllSongs().first;

      await db.applySyncResult(upserts: [], deletedIds: [], newCatalogVersion: 1);
      final after = await db.watchAllSongs().first;

      expect(after.length, before.length);
      expect(await db.getCatalogVersion(), 1);
    });

    test('local cursor only ever advances forward across a realistic sequence', () async {
      final versions = <int>[];
      for (final v in [1, 2, 5, 8]) {
        await db.applySyncResult(upserts: [_song('s$v')], deletedIds: [], newCatalogVersion: v);
        versions.add(await db.getCatalogVersion());
      }
      for (var i = 1; i < versions.length; i++) {
        expect(versions[i], greaterThan(versions[i - 1]),
            reason: 'cursor must strictly increase across successive syncs');
      }
    });

    // Hardening pass — exact scenario requested: local cursor is already
    // at 10, server sends a stale/malicious catalogVersion of 8.
    test(
        'REJECTS sync when local cursor=10 and server catalogVersion=8: '
        'throws StaleSyncException, cursor stays 10, catalog unchanged', () async {
      await db.applySyncResult(
        upserts: [_song('keep1', title: 'Keep One'), _song('keep2', title: 'Keep Two')],
        deletedIds: [],
        newCatalogVersion: 10,
      );
      expect(await db.getCatalogVersion(), 10);
      final beforeRows = await db.watchAllSongs().first;
      expect(beforeRows.length, 2);

      await expectLater(
        db.applySyncResult(
          upserts: [_song('malicious', title: 'Should Never Appear')],
          deletedIds: ['keep1'], // attempted delete must not apply either
          newCatalogVersion: 8,
        ),
        throwsA(isA<StaleSyncException>()),
      );

      // Cursor must remain exactly 10.
      expect(await db.getCatalogVersion(), 10);

      // Catalog must be byte-for-byte what it was before the rejected
      // call: same two rows, no injected row, no deleted row.
      final afterRows = await db.watchAllSongs().first;
      expect(afterRows.length, 2);
      expect(afterRows.map((r) => r.id).toSet(), {'keep1', 'keep2'});
      expect(afterRows.any((r) => r.id == 'malicious'), false);
    });

    test('accepts newCatalogVersion equal to the current cursor (no-op, not a regression)', () async {
      await db.applySyncResult(upserts: [_song('a1')], deletedIds: [], newCatalogVersion: 5);
      await db.applySyncResult(upserts: [], deletedIds: [], newCatalogVersion: 5);
      expect(await db.getCatalogVersion(), 5);
    });
  });

  group('AppDatabase.searchSongs — local offline search (audit fix #5)', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting();
      await db.applySyncResult(
        upserts: [
          _song('s1', title: 'Neon Hours', artist: 'Levit'),
          _song('s2', title: 'Static Bloom', artist: 'Rhea K.', albumName: 'Bloom Sessions'),
          _song('s3', title: 'Amber Skies', artist: 'Nova Loop'),
        ],
        deletedIds: [],
        newCatalogVersion: 3,
      );
    });
    tearDown(() => db.close());

    test('matches by title substring, case-insensitively', () async {
      final results = await db.searchSongs('neon');
      expect(results.map((r) => r.id), ['s1']);
    });

    test('matches by artist substring', () async {
      final results = await db.searchSongs('rhea');
      expect(results.map((r) => r.id), ['s2']);
    });

    test('matches by album name substring', () async {
      final results = await db.searchSongs('bloom sessions');
      expect(results.map((r) => r.id), ['s2']);
    });

    test('empty query returns no results rather than the whole catalog', () async {
      final results = await db.searchSongs('   ');
      expect(results, isEmpty);
    });

    test('no match returns an empty list, not an error', () async {
      final results = await db.searchSongs('doesnotexist');
      expect(results, isEmpty);
    });
  });

  group('AppDatabase.setLiked / setDownloaded', () {
    late AppDatabase db;
    setUp(() async {
      db = AppDatabase.forTesting();
      await db.applySyncResult(upserts: [_song('l1')], deletedIds: [], newCatalogVersion: 1);
    });
    tearDown(() => db.close());

    test('setLiked toggles isLiked without touching other fields', () async {
      await db.setLiked('l1', true);
      final row = await db.getSongById('l1');
      expect(row!.isLiked, true);
      expect(row.title, 'T');
    });

    test('setDownloaded records the local path', () async {
      await db.setDownloaded('l1', isDownloaded: true, localPath: '/data/l1.mp3');
      final row = await db.getSongById('l1');
      expect(row!.isDownloaded, true);
      expect(row.localPath, '/data/l1.mp3');
    });

    test('remote sync preserves local liked/downloaded state on updates', () async {
      // The group setUp already advanced the shared test DB cursor to 1
      // with l1. This is a legitimate second catalog change, so it must use
      // a strictly newer server version.
      await db.applySyncResult(
        upserts: [_song('l2', title: 'Original')],
        deletedIds: [],
        newCatalogVersion: 2,
      );
      await db.setLiked('l2', true);
      await db.setDownloaded('l2', isDownloaded: true, localPath: '/data/l2.mp3');

      await db.applySyncResult(
        upserts: [_song('l2', title: 'Updated Title')],
        deletedIds: [],
        newCatalogVersion: 3,
      );

      final row = await db.getSongById('l2');
      expect(row!.title, 'Updated Title');
      expect(row.isLiked, true);
      expect(row.isDownloaded, true);
      expect(row.localPath, '/data/l2.mp3');
    });
  });
}
