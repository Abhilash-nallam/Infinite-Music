import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/song.dart';

/// Persistent user library data that is independent of the server catalog.
///
/// This store intentionally keeps a compact snapshot of songs in liked lists
/// and playlists so local-device songs remain available even when the media
/// scanner is not currently running and cloud sync is unavailable.
class LibraryStore extends ChangeNotifier {
  static const _likedKey = 'library_liked_songs_v1';
  static const _playlistsKey = 'library_playlists_v1';

  final SharedPreferences _prefs;
  final Map<String, Song> _likedSongs = <String, Song>{};
  final Map<String, List<Song>> _playlists = <String, List<Song>>{};

  LibraryStore(this._prefs) {
    _load();
  }

  List<Song> get likedSongs => List.unmodifiable(_likedSongs.values);
  List<String> get playlistNames => List.unmodifiable(_playlists.keys);
  List<Song> songsInPlaylist(String name) =>
      List.unmodifiable(_playlists[name] ?? const <Song>[]);

  bool isLiked(Song song) => _likedSongs.containsKey(song.id);

  void _load() {
    try {
      final likedRaw = _prefs.getString(_likedKey);
      if (likedRaw != null) {
        final decoded = jsonDecode(likedRaw);
        if (decoded is List) {
          for (final item in decoded) {
            final song = _songFromJson(item);
            if (song != null) _likedSongs[song.id] = song;
          }
        }
      }

      final playlistsRaw = _prefs.getString(_playlistsKey);
      if (playlistsRaw != null) {
        final decoded = jsonDecode(playlistsRaw);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final value = entry.value;
            if (value is List) {
              _playlists[entry.key.toString()] = [
                for (final item in value)
                  if (_songFromJson(item) case final song?) song,
              ];
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Library restore failed: $e');
    }
  }

  Future<bool> toggleLike(Song song) async {
    final liked = !_likedSongs.containsKey(song.id);
    if (liked) {
      _likedSongs[song.id] = song.copyWith(isLiked: true);
    } else {
      _likedSongs.remove(song.id);
    }
    await _persist();
    notifyListeners();
    return liked;
  }

  Future<void> setLiked(Song song, bool liked) async {
    if (liked) {
      _likedSongs[song.id] = song.copyWith(isLiked: true);
    } else {
      _likedSongs.remove(song.id);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> createPlaylist(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || _playlists.containsKey(trimmed)) return;
    _playlists[trimmed] = <Song>[];
    await _persist();
    notifyListeners();
  }

  Future<void> renamePlaylist(String oldName, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || oldName == trimmed || !_playlists.containsKey(oldName)) {
      return;
    }
    if (_playlists.containsKey(trimmed)) return;
    final songs = _playlists.remove(oldName)!;
    _playlists[trimmed] = songs;
    await _persist();
    notifyListeners();
  }

  Future<void> deletePlaylist(String name) async {
    _playlists.remove(name);
    await _persist();
    notifyListeners();
  }

  bool containsInPlaylist(String playlist, String songId) =>
      (_playlists[playlist] ?? const <Song>[]).any((song) => song.id == songId);

  Future<void> addToPlaylist(String playlist, Song song) async {
    final songs = _playlists[playlist];
    if (songs == null) return;
    if (!songs.any((item) => item.id == song.id)) {
      songs.add(song);
      await _persist();
      notifyListeners();
    }
  }

  Future<void> removeFromPlaylist(String playlist, String songId) async {
    final songs = _playlists[playlist];
    if (songs == null) return;
    songs.removeWhere((song) => song.id == songId);
    await _persist();
    notifyListeners();
  }

  Future<void> reorderPlaylist(String playlist, int oldIndex, int newIndex) async {
    final songs = _playlists[playlist];
    if (songs == null) return;
    if (oldIndex < newIndex) newIndex -= 1;
    final song = songs.removeAt(oldIndex);
    songs.insert(newIndex, song);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final liked = _likedSongs.values.map(_songToJson).toList(growable: false);
    final playlists = <String, dynamic>{
      for (final entry in _playlists.entries)
        entry.key: entry.value.map(_songToJson).toList(growable: false),
    };
    await _prefs.setString(_likedKey, jsonEncode(liked));
    await _prefs.setString(_playlistsKey, jsonEncode(playlists));
  }

  Map<String, dynamic> _songToJson(Song song) => {
        'id': song.id,
        'title': song.title,
        'artist': song.artist,
        'artworkUrl': song.artworkUrl,
        'artworkId': song.artworkId,
        'streamUrl': song.streamUrl,
        'durationMs': song.duration.inMilliseconds,
        'isDownloaded': song.isDownloaded,
        'isLiked': song.isLiked,
        'fileSizeMb': song.fileSizeMb,
        'isLocal': song.isLocal,
        'artistId': song.artistId,
        'albumId': song.albumId,
        'albumName': song.albumName,
        'downloadUrl': song.downloadUrl,
        'fileSizeBytes': song.fileSizeBytes,
        'mimeType': song.mimeType,
        'version': song.version,
        'createdAt': song.createdAt?.millisecondsSinceEpoch,
        'updatedAt': song.updatedAt?.millisecondsSinceEpoch,
        'localPath': song.localPath,
      };

  Song? _songFromJson(dynamic raw) {
    if (raw is! Map) return null;
    try {
      return Song(
        id: raw['id']?.toString() ?? '',
        title: raw['title']?.toString() ?? 'Unknown',
        artist: raw['artist']?.toString() ?? 'Unknown artist',
        artworkUrl: raw['artworkUrl']?.toString() ?? '',
        artworkId: raw['artworkId'] is num ? (raw['artworkId'] as num).toInt() : null,
        streamUrl: raw['streamUrl']?.toString() ?? '',
        duration: Duration(milliseconds: (raw['durationMs'] as num?)?.toInt() ?? 0),
        isDownloaded: raw['isDownloaded'] == true,
        isLiked: raw['isLiked'] == true,
        fileSizeMb: (raw['fileSizeMb'] as num?)?.toDouble() ?? 0,
        isLocal: raw['isLocal'] == true,
        artistId: raw['artistId']?.toString(),
        albumId: raw['albumId']?.toString(),
        albumName: raw['albumName']?.toString(),
        downloadUrl: raw['downloadUrl']?.toString(),
        fileSizeBytes: raw['fileSizeBytes'] is num ? (raw['fileSizeBytes'] as num).toInt() : null,
        mimeType: raw['mimeType']?.toString(),
        version: raw['version'] is num ? (raw['version'] as num).toInt() : null,
        createdAt: raw['createdAt'] is num
            ? DateTime.fromMillisecondsSinceEpoch((raw['createdAt'] as num).toInt())
            : null,
        updatedAt: raw['updatedAt'] is num
            ? DateTime.fromMillisecondsSinceEpoch((raw['updatedAt'] as num).toInt())
            : null,
        localPath: raw['localPath']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }
}
