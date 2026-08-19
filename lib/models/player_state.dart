import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:audio_service/audio_service.dart';
import 'package:permission_handler/permission_handler.dart';

import 'audio_player_controller.dart';
import 'song.dart';
import '../services/app_preferences.dart';
import '../services/background_audio_handler.dart';
import '../services/library_store.dart';
import '../services/local_artwork_cache.dart';

enum RepeatMode { off, one, all }

/// Shared playback state for the complete app.
///
/// The state owns the logical queue while InfiniteAudioHandler owns the
/// platform audio session. All controls in the UI call this class so there is
/// one source of truth for play/pause, seek, queue, shuffle and repeat.
class PlayerState extends ChangeNotifier {
  final AudioPlayerController? _audioPlayer;
  final InfiniteAudioHandler? _backgroundHandler;
  final AppPreferences? _settings;
  final LibraryStore? _library;

  bool _miniPlayerVisible = true;
  Song? _currentSong;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  final List<Song> _queue = [];
  int _playRequestId = 0;
  bool _shuffleEnabled = false;
  RepeatMode _repeatMode = RepeatMode.off;
  bool _disposed = false;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  Song? get currentSong => _currentSong;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  List<Song> get queue => List.unmodifiable(_queue);
  bool get miniPlayerVisible => _miniPlayerVisible;
  bool get shuffleEnabled => _shuffleEnabled;
  RepeatMode get repeatMode => _repeatMode;

  PlayerState({
    AudioPlayerController? controller,
    InfiniteAudioHandler? backgroundHandler,
    AppPreferences? settings,
    LibraryStore? library,
  })  : _audioPlayer = controller,
        _backgroundHandler = backgroundHandler,
        _settings = settings,
        _library = library {
    if (_backgroundHandler != null) {
      _subscriptions.add(_backgroundHandler.playbackState.listen((state) {
        if (_disposed) return;
        _isPlaying = state.playing;
        _position = state.position;
        if (state.processingState == AudioProcessingState.completed &&
            (_settings?.autoplay ?? true) &&
            _repeatMode == RepeatMode.off) {
          skipNext();
        }
        notifyListeners();
      }));

      _subscriptions.add(_backgroundHandler.mediaItem.listen((item) {
        if (_disposed || item == null) return;
        final index = _queue.indexWhere((song) => song.id == item.id);
        if (index >= 0) {
          _currentSong = _queue[index];
          _position = Duration.zero;
          _miniPlayerVisible = true;
          notifyListeners();
        }
      }));
    } else {
      final audioPlayer = _audioPlayer;
      if (audioPlayer == null) return;

      _subscriptions.add(audioPlayer.positionStream.listen((pos) {
        if (_disposed) return;
        _position = pos;
        notifyListeners();
      }));

      _subscriptions.add(audioPlayer.playerStateStream.listen((state) {
        if (_disposed) return;
        _isPlaying = state.playing;
        if (state.processingState == ja.ProcessingState.completed &&
            (_settings?.autoplay ?? true) &&
            _repeatMode == RepeatMode.off) {
          skipNext();
        }
        notifyListeners();
      }));
    }
  }

  Future<void> playSong(Song song, {List<Song>? fromQueue}) async {
    final requestId = ++_playRequestId;
    _currentSong = song;
    _miniPlayerVisible = true;
    _position = Duration.zero;

    _queue
      ..clear()
      ..addAll(fromQueue ?? <Song>[song]);

    // If the selected song was not in the supplied queue, always keep it.
    if (!_queue.any((item) => item.id == song.id)) {
      _queue.insert(0, song);
    }

    if (_backgroundHandler != null) {
      final prepared = <Song>[];
      for (final item in _queue) {
        prepared.add(await LocalArtworkCache.prepare(item));
      }
      _queue
        ..clear()
        ..addAll(prepared);
      _currentSong = _queue.firstWhere(
        (item) => item.id == song.id,
        orElse: () => song,
      );
    }

    if (_disposed) return;
    notifyListeners();

    if (song.streamUrl.isEmpty) {
      _isPlaying = true;
      notifyListeners();
      return;
    }

    try {
      await _ensureNotificationPermission();

      final handler = _backgroundHandler;
      if (handler != null) {
        final index = _queue.indexWhere((item) => item.id == song.id);
        await handler.loadSongs(_queue, index < 0 ? 0 : index);
        if (requestId != _playRequestId || _currentSong?.id != song.id) {
          return;
        }
        await handler.setShuffleEnabled(_shuffleEnabled);
        await handler.setInfiniteRepeatMode(_toLoopMode(_repeatMode));
        await handler.play();
        return;
      }

      final audioPlayer = _audioPlayer;
      if (audioPlayer == null) return;

      final mediaItem = MediaItemCompat.fromSong(song);
      if (song.isLocal) {
        await audioPlayer.setFilePath(song.streamUrl, tag: mediaItem);
      } else {
        await audioPlayer.setUrl(song.streamUrl, tag: mediaItem);
      }

      if (requestId != _playRequestId || _currentSong?.id != song.id) {
        return;
      }
      await audioPlayer.play();
    } catch (e) {
      debugPrint('Playback error for "${song.title}": $e');
      if (!_disposed &&
          requestId == _playRequestId &&
          _currentSong?.id == song.id) {
        _isPlaying = false;
        notifyListeners();
      }
    }
  }

  Future<void> _ensureNotificationPermission() async {
    if (_settings?.notifications != true) return;
    if (defaultTargetPlatform != TargetPlatform.android) return;

    final status = await Permission.notification.status;
    if (!status.isGranted && !status.isPermanentlyDenied) {
      await Permission.notification.request();
    }
  }

  void dismissMiniPlayer() {
    _miniPlayerVisible = false;
    notifyListeners();
  }

  Future<void> stopPlayback() async {
    if (_disposed) return;
    final handler = _backgroundHandler;
    if (handler != null) {
      await handler.stop();
    } else {
      await _audioPlayer?.pause();
    }
    if (_disposed) return;
    _isPlaying = false;
    _position = Duration.zero;
    _miniPlayerVisible = false;
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (_currentSong == null) return;

    if (_currentSong!.streamUrl.isEmpty) {
      _isPlaying = !_isPlaying;
      notifyListeners();
      return;
    }

    final handler = _backgroundHandler;
    if (handler != null) {
      if (handler.playbackState.value.playing) {
        await handler.pause();
      } else {
        await handler.play();
      }
      return;
    }

    final audioPlayer = _audioPlayer;
    if (audioPlayer == null) return;
    if (audioPlayer.playing) {
      await audioPlayer.pause();
    } else {
      await audioPlayer.play();
    }
  }

  Future<void> seekTo(Duration position) async {
    final total = _currentSong?.duration ?? Duration.zero;
    final safe = total > Duration.zero
        ? Duration(
            milliseconds: position.inMilliseconds.clamp(
              0,
              total.inMilliseconds,
            ),
          )
        : position;
    _position = safe;
    notifyListeners();

    if (_currentSong == null || _currentSong!.streamUrl.isEmpty) return;

    if (_backgroundHandler != null) {
      await _backgroundHandler.seek(safe);
    } else {
      await _audioPlayer?.seek(safe);
    }
  }

  Future<void> toggleShuffle() async {
    if (_disposed) return;
    _shuffleEnabled = !_shuffleEnabled;
    if (_backgroundHandler != null) {
      await _backgroundHandler.setShuffleEnabled(_shuffleEnabled);
    } else if (!_shuffleEnabled) {
      // Nothing else is needed for the single-player test seam.
    }
    if (_disposed) return;
    notifyListeners();
  }

  Future<void> cycleRepeat() async {
    if (_disposed) return;
    _repeatMode = switch (_repeatMode) {
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };
    if (_backgroundHandler != null) {
      await _backgroundHandler.setInfiniteRepeatMode(_toLoopMode(_repeatMode));
    }
    if (_disposed) return;
    notifyListeners();
  }

  ja.LoopMode _toLoopMode(RepeatMode mode) => switch (mode) {
        RepeatMode.off => ja.LoopMode.off,
        RepeatMode.one => ja.LoopMode.one,
        RepeatMode.all => ja.LoopMode.all,
      };

  Future<void> skipNext() async {
    if (_currentSong == null || _queue.isEmpty) return;

    if (_backgroundHandler != null) {
      await _backgroundHandler.skipToNext();
      return;
    }

    if (_repeatMode == RepeatMode.one) {
      await seekTo(Duration.zero);
      await _audioPlayer?.play();
      return;
    }

    final idx = _queue.indexWhere((s) => s.id == _currentSong!.id);
    if (idx == -1) return;

    int nextIndex;
    if (_shuffleEnabled && _queue.length > 1) {
      final choices = List<int>.generate(_queue.length, (i) => i)
        ..remove(idx);
      nextIndex = choices[Random().nextInt(choices.length)];
    } else {
      nextIndex = idx + 1;
    }

    if (nextIndex >= _queue.length) {
      if (_repeatMode == RepeatMode.all) {
        nextIndex = 0;
      } else {
        return;
      }
    }

    await playSong(_queue[nextIndex], fromQueue: _queue);
  }

  Future<void> skipPrevious() async {
    if (_currentSong == null || _queue.isEmpty) return;

    if (_position.inSeconds > 3) {
      await seekTo(Duration.zero);
      return;
    }

    if (_backgroundHandler != null) {
      await _backgroundHandler.skipToPrevious();
      return;
    }

    final idx = _queue.indexWhere((s) => s.id == _currentSong!.id);
    if (idx <= 0) {
      await seekTo(Duration.zero);
      return;
    }

    await playSong(_queue[idx - 1], fromQueue: _queue);
  }

  Future<void> addToQueue(Song song) async {
    if (_queue.any((item) => item.id == song.id)) return;
    _queue.add(song);
    await _syncBackgroundQueue();
    if (_disposed) return;
    notifyListeners();
  }

  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _queue.length) return;
    if (_queue[index].id == _currentSong?.id) return;
    _queue.removeAt(index);
    await _syncBackgroundQueue();
    if (_disposed) return;
    notifyListeners();
  }

  Future<void> clearQueue() async {
    final current = _currentSong;
    _queue
      ..clear()
      ..addAll(current == null ? const <Song>[] : <Song>[current]);
    await _syncBackgroundQueue();
    if (_disposed) return;
    notifyListeners();
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    if (newIndex < 0 || newIndex > _queue.length) return;
    if (oldIndex == newIndex) return;

    if (oldIndex < newIndex) newIndex -= 1;
    final item = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, item);
    await _syncBackgroundQueue();
    if (_disposed) return;
    notifyListeners();
  }

  Future<void> playQueueItem(int index) async {
    if (index < 0 || index >= _queue.length) return;
    await playSong(_queue[index], fromQueue: _queue);
  }

  Future<void> _syncBackgroundQueue() async {
    final handler = _backgroundHandler;
    if (handler == null || _queue.isEmpty || _currentSong == null) return;

    final index = _queue.indexWhere((song) => song.id == _currentSong!.id);
    if (index < 0) return;
    final wasPlaying = _isPlaying;
    final position = _position;
    await handler.replaceQueue(
      _queue,
      currentIndex: index,
      position: position,
      resume: wasPlaying,
    );
    _position = position;
  }

  Future<bool> toggleLike() async {
    final song = _currentSong;
    if (song == null || _library == null) return false;
    final liked = await _library.toggleLike(song);
    song.isLiked = liked;
    if (!_disposed) notifyListeners();
    return liked;
  }

  void setLiked(bool liked) {
    if (_currentSong == null) return;
    _currentSong!.isLiked = liked;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _audioPlayer?.dispose();
    super.dispose();
  }
}

/// Small compatibility adapter used only by the legacy test seam.
class MediaItemCompat {
  static MediaItem fromSong(Song song) {
    final artwork = song.artworkUrl.trim();
    final uri = Uri.tryParse(artwork);
    return MediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist,
      album: song.albumName ?? (song.isLocal ? 'My Device' : 'Infinite Music'),
      duration: song.duration,
      artUri: uri != null &&
              (uri.scheme == 'http' ||
                  uri.scheme == 'https' ||
                  uri.scheme == 'file' ||
                  uri.scheme == 'content')
          ? uri
          : null,
    );
  }
}
