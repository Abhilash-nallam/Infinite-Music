import 'package:drift/drift.dart';

/// Local mirror of the server catalog. `@DataClassName('SongRow')` avoids
/// colliding with the app's own domain `Song` model in lib/models/song.dart
/// — the two are deliberately kept separate. Mapping between them happens
/// in song_mapper.dart, so nothing in the UI layer needs to know Drift exists.
@DataClassName('SongRow')
class Songs extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get artist => text()();
  TextColumn get artistId => text().nullable()();
  TextColumn get albumId => text().nullable()();
  TextColumn get albumName => text().nullable()();
  TextColumn get artworkUrl => text().withDefault(const Constant(''))();
  TextColumn get streamUrl => text().withDefault(const Constant(''))();
  TextColumn get downloadUrl => text().nullable()();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  IntColumn get fileSizeBytes => integer().nullable()();
  TextColumn get mimeType => text().nullable()();
  // Server-assigned version this record last changed at. Used for delta sync.
  IntColumn get version => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer().nullable()();
  IntColumn get updatedAt => integer().nullable()();
  BoolColumn get isLiked => boolean().withDefault(const Constant(false))();
  BoolColumn get isDownloaded => boolean().withDefault(const Constant(false))();
  // Set once the Download Manager (Phase C) actually saves the file locally.
  TextColumn get localPath => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Single-row table holding the last catalog version the client has fully
/// synced to. Row id is always 0 — there's only ever one sync cursor.
class SyncState extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))();
  IntColumn get catalogVersion => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
