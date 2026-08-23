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
  Future<void>? _scanFuture;

  // The Library screen currently requests a scan during widget startup.
  // Do not touch the native on_audio_query MethodChannel during app startup;
  // the plugin has been observed to crash with "Reply already submitted".
  // The first scan request is therefore a safe no-op. The user's Refresh
  // action performs the real permission/query operation.
  bool _skipFirstScan = true;

  LocalMusicStatus get status => _status;
  List<Song> get songs => List.unmodifiable(_songs);
  String? get error => _error;
  bool get isLoading => _status == LocalMusicStatus.loading;
  bool get hasPermission => _status == LocalMusicStatus.ready;

  /// Runs only one MediaStore permission/query operation at a time.
  ///
  /// on_audio_query_pluse uses a native MethodChannel. Concurrent permission
  /// or query calls can produce "Reply already submitted" on Android.
  /// Reusing the same Future prevents overlapping native operations.
  Future<void> scan() {
    if (_skipFirstScan) {
      _skipFirstScan = false;
      _status = LocalMusicStatus.ready;
      _error = null;
      if (!_disposed) notifyListeners();
      return Future<void>.value();
    }

    final active = _scanFuture;
    if (active != null) return active;

    final future = _performScan();
    _scanFuture = future;
    return future.whenComplete(() {
      if (identical(_scanFuture, future)) {
        _scanFuture = null;
      }
    });
  }

  Future<void> _performScan() async {
    _status = LocalMusicStatus.loading;
    _error = null;
    if (!_disposed) notifyListeners();

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
