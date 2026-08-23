import 'package:flutter/foundation.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/song.dart';

/// Reads songs from Android MediaStore.
///
/// The on_audio_query plugin owns the media-library permission flow. Using
/// permission_handler for the query permission can report a granted state
/// that does not match the plugin's native permission controller, which can
/// make querySongs fail inside the Android MethodChannel.
class LocalMusicService {
  final OnAudioQuery _audioQuery = OnAudioQuery();

  Future<bool> requestPermission() async {
    try {
      // Let on_audio_query_pluse check/request the exact permission it uses
      // before any MediaStore query is made.
      final granted = await _audioQuery.checkAndRequest(retryRequest: false);
      if (granted) return true;
    } catch (e) {
      debugPrint('Media permission request failed: $e');
    }

    // Keep permission_handler only as a fallback for older Android versions.
    try {
      final audioStatus = await Permission.audio.status;
      if (audioStatus.isGranted) return true;
      final requested = await Permission.audio.request();
      if (requested.isGranted) {
        // Verify with the same native permission controller used by
        // on_audio_query before allowing querySongs to run.
        return await _audioQuery.permissionsStatus();
      }
    } catch (e) {
      debugPrint('Fallback media permission request failed: $e');
    }

    return false;
  }

  Future<bool> isPermanentlyDenied() async {
    try {
      return await Permission.audio.isPermanentlyDenied ||
          await Permission.storage.isPermanentlyDenied;
    } catch (_) {
      return false;
    }
  }

  Future<List<Song>> fetchDeviceSongs({bool assumePermission = false}) async {
    if (!assumePermission) {
      final granted = await requestPermission();
      if (!granted) return [];
    }

    // Never query MediaStore unless the plugin itself confirms access.
    try {
      final hasAccess = await _audioQuery.permissionsStatus();
      if (!hasAccess) return [];

      final tracks = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      return tracks
          .where((t) =>
              t.isMusic == true && t.duration != null && t.duration! > 0)
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
          .toList(growable: false);
    } catch (e, stack) {
      // A MediaStore/plugin failure must not terminate the Flutter process.
      debugPrint('Local music query failed: $e');
      debugPrintStack(stackTrace: stack);
      return [];
    }
  }
}
