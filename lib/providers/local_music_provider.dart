import 'package:flutter/foundation.dart';

import '../models/song.dart';
import '../services/local_music_service.dart';

enum LocalMusicStatus {
  idle,
  loading,
  ready,
  permissionDenied,
  error,
}

class LocalMusicProvider extends ChangeNotifier {
  final LocalMusicService service;

  LocalMusicProvider({LocalMusicService? service})
      : service = service ?? LocalMusicService();

  LocalMusicStatus _status = LocalMusicStatus.idle;
  List<Song> _songs = const [];
  String? _error;
  bool _disposed = false;

  LocalMusicStatus get status => _status;
  List<Song> get songs => List.unmodifiable(_songs);
  String? get error => _error;
  bool get isLoading => _status == LocalMusicStatus.loading;
  bool get hasPermission => _status == LocalMusicStatus.ready;

  Future<void> scan() async {
    if (_status == LocalMusicStatus.loading) return;

    _status = LocalMusicStatus.loading;
    _error = null;
    notifyListeners();

    try {
      final granted = await service.requestPermission();
      if (_disposed) return;

      if (!granted) {
        _status = LocalMusicStatus.permissionDenied;
        notifyListeners();
        return;
      }

      final songs = await service.fetchDeviceSongs(assumePermission: true);
      if (_disposed) return;

      _songs = songs;
      _status = LocalMusicStatus.ready;
      notifyListeners();
    } catch (e) {
      if (_disposed) return;
      _error = e.toString();
      _status = LocalMusicStatus.error;
      notifyListeners();
    }
  }

  Future<bool> openSettingsIfPermanentlyDenied() async {
    return service.isPermanentlyDenied();
  }

  List<Song> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return songs;
    return _songs.where((song) {
      return song.title.toLowerCase().contains(q) ||
          song.artist.toLowerCase().contains(q) ||
          (song.albumName?.toLowerCase().contains(q) ?? false);
    }).toList(growable: false);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
