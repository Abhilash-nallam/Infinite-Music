import 'dart:io';

import 'package:on_audio_query_pluse/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';

import '../models/song.dart';

/// Materializes embedded MediaStore artwork into a real file URI so Android's
/// MediaSession/lock-screen notification can display the same high-quality
/// artwork as the Flutter UI.
class LocalArtworkCache {
  LocalArtworkCache._();

  static final OnAudioQuery _query = OnAudioQuery();
  static final Map<int, String> _paths = <int, String>{};

  static Future<Song> prepare(Song song) async {
    if (!song.isLocal || song.artworkId == null) return song;
    final id = song.artworkId!;
    final existing = _paths[id];
    if (existing != null && await File(existing).exists()) {
      return song.copyWith(artworkUrl: File(existing).uri.toString());
    }

    try {
      final bytes = await _query.queryArtwork(
        id,
        ArtworkType.AUDIO,
        format: ArtworkFormat.JPEG,
        size: 2000,
        quality: 100,
      );
      if (bytes == null || bytes.isEmpty) return song;

      final dir = Directory(
        '${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}artwork',
      );
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File('${dir.path}${Platform.pathSeparator}audio_$id.jpg');
      await file.writeAsBytes(bytes, flush: true);
      _paths[id] = file.path;
      return song.copyWith(artworkUrl: file.uri.toString());
    } catch (_) {
      return song;
    }
  }
}
