/// Domain model used throughout the UI (SongCard, SongShelf, PlayerScreen,
/// mini-player, etc.). Deliberately kept independent of Drift's generated
/// SongRow — see database/song_mapper.dart for the conversion — so this
/// class has zero dependency on the persistence layer and stays cheap to
/// construct for mock/demo data and LocalMusicService results too.
///
/// All server-catalog metadata fields (artistId, albumId, albumName,
/// downloadUrl, fileSizeBytes, mimeType, version, createdAt, updatedAt) are
/// nullable/optional here on purpose: LocalMusicService (device files) and
/// mock_data.dart (demo catalog) legitimately don't have server-side
/// metadata, and forcing them to fake it would be worse than leaving it
/// absent. Code that needs a field should null-check it, not assume it's
/// always populated.
class Song {
  final String id;
  final String title;
  final String artist;
  final String artworkUrl;
  /// Android MediaStore audio id used to retrieve embedded local artwork.
  /// Null for cloud/catalog songs.
  final int? artworkId;
  final String streamUrl;
  final Duration duration;
  bool isDownloaded;
  bool isLiked;
  final double fileSizeMb;

  // True for songs pulled from the device's local storage via
  // LocalMusicService. When true, `streamUrl` holds a local file path (not
  // a network URL), and PlayerState uses AudioPlayer.setFilePath instead
  // of setUrl.
  final bool isLocal;

  // --- Server catalog metadata (Phase A audit fix) ---
  // These previously existed in the Drift schema but were silently dropped
  // by the mapper. Carried through properly now.
  final String? artistId;
  final String? albumId;
  final String? albumName;
  // Streaming and downloading are allowed to use different URLs/qualities
  // in the roadmap's model (e.g. a lower-bitrate stream vs. a full-quality
  // download). Falls back to streamUrl when the catalog doesn't provide a
  // distinct one.
  final String? downloadUrl;
  final int? fileSizeBytes;
  final String? mimeType;
  // The server catalog version this record was last changed at — lets the
  // UI (or future debug tooling) show "last updated at version N" rather
  // than only a raw timestamp.
  final int? version;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  // Populated once the Download Manager (Phase C) actually saves the file
  // on-device; null until then even if isDownloaded is somehow true.
  final String? localPath;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.artworkUrl,
    this.artworkId,
    required this.streamUrl,
    required this.duration,
    this.isDownloaded = false,
    this.isLiked = false,
    this.fileSizeMb = 0,
    this.isLocal = false,
    this.artistId,
    this.albumId,
    this.albumName,
    this.downloadUrl,
    this.fileSizeBytes,
    this.mimeType,
    this.version,
    this.createdAt,
    this.updatedAt,
    this.localPath,
  });

  /// The URL to actually use for downloading, falling back to streamUrl
  /// when the catalog didn't provide a separate download-quality URL.
  String get effectiveDownloadUrl =>
      (downloadUrl != null && downloadUrl!.isNotEmpty) ? downloadUrl! : streamUrl;

  Song copyWith({
    String? id,
    String? title,
    String? artist,
    String? artworkUrl,
    int? artworkId,
    String? streamUrl,
    Duration? duration,
    bool? isDownloaded,
    bool? isLiked,
    double? fileSizeMb,
    bool? isLocal,
    String? artistId,
    String? albumId,
    String? albumName,
    String? downloadUrl,
    int? fileSizeBytes,
    String? mimeType,
    int? version,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? localPath,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      artworkId: artworkId ?? this.artworkId,
      streamUrl: streamUrl ?? this.streamUrl,
      duration: duration ?? this.duration,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      isLiked: isLiked ?? this.isLiked,
      fileSizeMb: fileSizeMb ?? this.fileSizeMb,
      isLocal: isLocal ?? this.isLocal,
      artistId: artistId ?? this.artistId,
      albumId: albumId ?? this.albumId,
      albumName: albumName ?? this.albumName,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      mimeType: mimeType ?? this.mimeType,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      localPath: localPath ?? this.localPath,
    );
  }
}
