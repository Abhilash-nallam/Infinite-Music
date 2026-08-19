import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:infinite_music/database/app_database.dart';
import 'package:infinite_music/database/song_mapper.dart';

void main() {
  group('SongRowMapper.toSong — mapper correctness (audit fix #2)', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.forTesting());
    tearDown(() => db.close());

    test('every non-null field on SongRow is carried through to Song', () async {
      await db.into(db.songs).insert(
            SongsCompanion.insert(
              id: 'm1',
              title: 'Mapper Test Song',
              artist: 'Mapper Artist',
              artistId: const Value('artist-1'),
              albumId: const Value('album-1'),
              albumName: const Value('Test Album'),
              artworkUrl: const Value('https://example.test/art.png'),
              streamUrl: const Value('https://example.test/stream.mp3'),
              downloadUrl: const Value('https://example.test/download.mp3'),
              durationMs: const Value(210000),
              fileSizeBytes: const Value(8388608), // 8 MB exactly
              mimeType: const Value('audio/mpeg'),
              version: const Value(7),
              createdAt: Value(1700000000000),
              updatedAt: Value(1700000100000),
            ),
          );

      final row = await db.getSongById('m1');
      expect(row, isNotNull);
      final song = row!.toSong();

      expect(song.id, 'm1');
      expect(song.title, 'Mapper Test Song');
      expect(song.artist, 'Mapper Artist');
      expect(song.artistId, 'artist-1');
      expect(song.albumId, 'album-1');
      expect(song.albumName, 'Test Album');
      expect(song.artworkUrl, 'https://example.test/art.png');
      expect(song.streamUrl, 'https://example.test/stream.mp3');
      expect(song.downloadUrl, 'https://example.test/download.mp3');
      expect(song.duration, const Duration(milliseconds: 210000));
      expect(song.fileSizeBytes, 8388608);
      expect(song.fileSizeMb, 8.0);
      expect(song.mimeType, 'audio/mpeg');
      expect(song.version, 7);
      expect(song.createdAt, DateTime.fromMillisecondsSinceEpoch(1700000000000));
      expect(song.updatedAt, DateTime.fromMillisecondsSinceEpoch(1700000100000));
      expect(song.isLocal, false); // DB-sourced songs are never local files
    });

    test('null optional fields map to null, not crash or a fake default', () async {
      await db.into(db.songs).insert(
            SongsCompanion.insert(id: 'm2', title: 'Bare Song', artist: 'Bare Artist'),
          );
      final row = await db.getSongById('m2');
      final song = row!.toSong();

      expect(song.artistId, isNull);
      expect(song.albumId, isNull);
      expect(song.albumName, isNull);
      expect(song.downloadUrl, isNull);
      expect(song.fileSizeBytes, isNull);
      expect(song.fileSizeMb, 0); // safe fallback, not a crash on null division
      expect(song.mimeType, isNull);
      expect(song.createdAt, isNull);
      expect(song.updatedAt, isNull);
    });

    test('effectiveDownloadUrl falls back to streamUrl when downloadUrl is absent', () async {
      await db.into(db.songs).insert(
            SongsCompanion.insert(
              id: 'm3',
              title: 'No Download URL',
              artist: 'X',
              streamUrl: const Value('https://example.test/only-stream.mp3'),
            ),
          );
      final song = (await db.getSongById('m3'))!.toSong();
      expect(song.effectiveDownloadUrl, 'https://example.test/only-stream.mp3');
    });

    test('effectiveDownloadUrl prefers downloadUrl when both are present', () async {
      await db.into(db.songs).insert(
            SongsCompanion.insert(
              id: 'm4',
              title: 'Both URLs',
              artist: 'X',
              streamUrl: const Value('https://example.test/stream.mp3'),
              downloadUrl: const Value('https://example.test/download.mp3'),
            ),
          );
      final song = (await db.getSongById('m4'))!.toSong();
      expect(song.effectiveDownloadUrl, 'https://example.test/download.mp3');
    });
  });
}
