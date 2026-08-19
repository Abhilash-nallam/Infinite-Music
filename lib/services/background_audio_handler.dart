import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart' as ja;

import '../models/song.dart';

/// Real Android/iOS media-session bridge.
///
/// The handler owns the single just_audio player so the same playback session
/// is exposed to the Android notification, lock screen, headset buttons and
/// the Flutter UI.  A ConcatenatingAudioSource is used even for one song so
/// next/previous actions are handled by the same queue on every surface.
class InfiniteAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final ja.AudioPlayer _player = ja.AudioPlayer();

  List<Song> _songs = const <Song>[];
  int _currentIndex = 0;
  Timer? _positionTicker;
  ja.LoopMode _repeatMode = ja.LoopMode.off;
  bool _shuffleEnabled = false;

  InfiniteAudioHandler() {
    _player.playbackEventStream.listen(_broadcastState);
    _positionTicker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_player.playing) _broadcastState(_player.playbackEvent);
    });

    _player.currentIndexStream.listen((index) {
      if (index == null || index < 0 || index >= _songs.length) return;
      _currentIndex = index;
      final items = queue.value;
      if (index < items.length) {
        mediaItem.add(items[index]);
      }
      _broadcastState(_player.playbackEvent);
    });
  }

  bool get shuffleEnabled => _shuffleEnabled;
  ja.LoopMode get repeatMode => _repeatMode;

  Future<void> setShuffleEnabled(bool enabled) async {
    _shuffleEnabled = enabled;
    await _player.setShuffleModeEnabled(enabled);
    _broadcastState(_player.playbackEvent);
  }

  Future<void> setInfiniteRepeatMode(ja.LoopMode mode) async {
    _repeatMode = mode;
    await _player.setLoopMode(mode);
    _broadcastState(_player.playbackEvent);
  }

  Future<void> loadSongs(List<Song> songs, int initialIndex) async {
    if (songs.isEmpty) return;

    _songs = List<Song>.from(songs);
    _currentIndex = initialIndex.clamp(0, _songs.length - 1).toInt();

    final items = _songs.map(_mediaItem).toList(growable: false);

    // The UI's queue can contain demo entries with no real URL. Background
    // playback only loads songs that have an actual audio source.
    final playableSongs = <Song>[];
    final playableItems = <MediaItem>[];
    for (var i = 0; i < _songs.length; i++) {
      if (_songs[i].streamUrl.isEmpty) continue;
      playableSongs.add(_songs[i]);
      playableItems.add(items[i]);
    }
    if (playableSongs.isEmpty) return;

    final playableIndex = playableSongs.indexWhere(
      (song) => song.id == _songs[_currentIndex].id,
    );
    _songs = playableSongs;
    _currentIndex = playableIndex < 0 ? 0 : playableIndex;

    final playableSources = <ja.AudioSource>[];
    for (var i = 0; i < _songs.length; i++) {
      final song = _songs[i];
      final tag = playableItems[i];
      playableSources.add(
        song.isLocal
            ? ja.AudioSource.file(song.streamUrl, tag: tag)
            : ja.AudioSource.uri(Uri.parse(song.streamUrl), tag: tag),
      );
    }

    final source = ja.ConcatenatingAudioSource(
      children: playableSources,
      useLazyPreparation: true,
    );

    queue.add(playableItems);
    mediaItem.add(playableItems[_currentIndex]);

    await _player.setAudioSource(
      source,
      initialIndex: _currentIndex,
      initialPosition: Duration.zero,
    );
    await _player.setShuffleModeEnabled(_shuffleEnabled);
    await _player.setLoopMode(_repeatMode);
    _broadcastState(_player.playbackEvent);
  }

  MediaItem _mediaItem(Song song) {
    final artwork = song.artworkUrl.trim();
    return MediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist,
      album: song.albumName ??
          (song.isLocal ? 'My Device' : 'Infinite Music'),
      duration: song.duration,
      artUri: _artUri(artwork),
    );
  }

  Uri? _artUri(String value) {
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        (uri.scheme != 'http' &&
            uri.scheme != 'https' &&
            uri.scheme != 'file' &&
            uri.scheme != 'content')) {
      return null;
    }
    return uri;
  }

  Future<void> replaceQueue(
    List<Song> songs, {
    required int currentIndex,
    required Duration position,
    required bool resume,
  }) async {
    if (songs.isEmpty) return;
    await loadSongs(songs, currentIndex);
    if (position > Duration.zero) await _player.seek(position);
    if (resume) await _player.play();
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_player.hasNext) {
      await _player.seekToNext();
      return;
    }
    if (_currentIndex + 1 < _songs.length) {
      await _player.seek(Duration.zero, index: _currentIndex + 1);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.hasPrevious) {
      await _player.seekToPrevious();
      return;
    }
    if (_currentIndex > 0) {
      await _player.seek(Duration.zero, index: _currentIndex - 1);
    }
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    _broadcastState(_player.playbackEvent);
    await super.stop();
  }

  void _broadcastState(ja.PlaybackEvent event) {
    final playing = _player.playing;
    final processingState = switch (_player.processingState) {
      ja.ProcessingState.idle => AudioProcessingState.idle,
      ja.ProcessingState.loading => AudioProcessingState.loading,
      ja.ProcessingState.buffering => AudioProcessingState.buffering,
      ja.ProcessingState.ready => AudioProcessingState.ready,
      ja.ProcessingState.completed => AudioProcessingState.completed,
    };

    playbackState.add(
      PlaybackState(
        controls: <MediaControl>[
          MediaControl.skipToPrevious,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const <MediaAction>{
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
        },
        androidCompactActionIndices: const <int>[0, 1, 2],
        processingState: processingState,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _currentIndex,
      ),
    );
  }
}
