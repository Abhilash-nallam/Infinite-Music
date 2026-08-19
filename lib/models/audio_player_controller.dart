import 'package:just_audio/just_audio.dart' as ja;
import 'package:audio_service/audio_service.dart';

/// Narrow abstraction over exactly the just_audio AudioPlayer surface
/// PlayerState actually uses. Exists purely as a test seam.
///
/// Production code never sees this directly — PlayerState defaults to
/// JustAudioPlayerController (below), which wraps a real just_audio
/// AudioPlayer and behaves identically to before this seam existed. Tests
/// can instead supply any AudioPlayerController implementation (e.g. a
/// fake built from plain StreamControllers) without touching just_audio's
/// platform channel at all — no guessing channel names, no risk of a
/// MissingPluginException in a widget/unit test environment where no real
/// platform implementation is registered.
///
/// `ja.PlayerState` and `ja.ProcessingState` (used in playerStateStream's
/// type) are just_audio's own plain data classes — they carry no platform-
/// channel dependency themselves, so a fake can construct real instances
/// of them freely.
abstract class AudioPlayerController {
  Stream<Duration> get positionStream;
  Stream<ja.PlayerState> get playerStateStream;
  bool get playing;

  Future<void> setFilePath(String path, {MediaItem? tag});
  Future<void> setUrl(String url, {MediaItem? tag});
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> dispose();
}

/// The real implementation — a thin pass-through to just_audio's actual
/// AudioPlayer. This is what production always uses; nothing about
/// playback behavior changes from before this seam was introduced.
class JustAudioPlayerController implements AudioPlayerController {
  final ja.AudioPlayer _player = ja.AudioPlayer();

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<ja.PlayerState> get playerStateStream => _player.playerStateStream;

  @override
  bool get playing => _player.playing;

  @override
  Future<void> setFilePath(String path, {MediaItem? tag}) =>
      _player.setAudioSource(ja.AudioSource.file(path, tag: tag));

  @override
  Future<void> setUrl(String url, {MediaItem? tag}) =>
      _player.setAudioSource(ja.AudioSource.uri(Uri.parse(url), tag: tag));

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> dispose() => _player.dispose();
}
