import '../models/song.dart';
import 'app_database.dart';

/// Converts a Drift row into the app's domain Song model, so every screen
/// and widget built against `Song` (SongCard, SongShelf, PlayerScreen, etc.)
/// keeps working unmodified — they don't need to know the catalog is
/// backed by a real database instead of a mock list.
///
/// Audit fix: previously this dropped artistId, albumId, albumName,
/// downloadUrl, mimeType, version, createdAt, updatedAt, and localPath on
/// the floor even though the Drift schema already stored them. Every
/// column now has a corresponding Song field.
extension SongRowMapper on SongRow {
  Song toSong() {
    return Song(
      id: id,
      title: title,
      artist: artist,
      artworkUrl: artworkUrl,
      streamUrl: streamUrl,
      duration: Duration(milliseconds: durationMs),
      isDownloaded: isDownloaded,
      isLiked: isLiked,
      fileSizeMb: fileSizeBytes == null ? 0 : fileSizeBytes! / (1024 * 1024),
      isLocal: false,
      artistId: artistId,
      albumId: albumId,
      albumName: albumName,
      downloadUrl: downloadUrl,
      fileSizeBytes: fileSizeBytes,
      mimeType: mimeType,
      version: version,
      createdAt: createdAt == null ? null : DateTime.fromMillisecondsSinceEpoch(createdAt!),
      updatedAt: updatedAt == null ? null : DateTime.fromMillisecondsSinceEpoch(updatedAt!),
      localPath: localPath,
    );
  }
}
