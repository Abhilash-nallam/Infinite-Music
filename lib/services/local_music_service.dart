import 'package:on_audio_query_pluse/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/song.dart';

/// Scans the device's local storage for audio files and maps them into
/// the app's Song model. Android 13+ (API 33) uses the scoped READ_MEDIA_AUDIO
/// permission; older versions fall back to READ_EXTERNAL_STORAGE. Both are
/// requested via `permission_handler`.
class LocalMusicService {
  final OnAudioQuery _audioQuery = OnAudioQuery();

  Future<bool> requestPermission() async {
    final audioStatus = await Permission.audio.status;
    if (audioStatus.isGranted) return true;

    final requestedAudio = await Permission.audio.request();
    if (requestedAudio.isGranted) return true;

    final storageStatus = await Permission.storage.request();
    return storageStatus.isGranted;
  }

  Future<bool> isPermanentlyDenied() async {
    return await Permission.audio.isPermanentlyDenied ||
        await Permission.storage.isPermanentlyDenied;
  }

  Future<List<Song>> fetchDeviceSongs({bool assumePermission = false}) async {
    if (!assumePermission) {
      final granted = await requestPermission();
      if (!granted) return [];
    }

    final tracks = await _audioQuery.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    return tracks
        .where((t) => t.isMusic == true && t.duration != null && t.duration! > 0)
        .map((t) => Song(
              id: 'local_${t.id}',
              title: t.title.isNotEmpty ? t.title : 'Unknown Title',
              artist: (t.artist != null && t.artist!.isNotEmpty)
                  ? t.artist!
                  : 'Unknown Artist',
              artworkUrl: '',
              artworkId: t.id,
              streamUrl: t.data,
              duration: Duration(milliseconds: t.duration ?? 0),
              isDownloaded: true,
              isLocal: true,
              fileSizeMb: t.size / (1024 * 1024),
            ))
        .toList();
  }
}
