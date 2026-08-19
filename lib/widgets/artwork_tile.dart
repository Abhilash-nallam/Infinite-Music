import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../models/song.dart';
import '../theme/app_theme.dart';

/// Shared artwork renderer for the entire app.
///
/// Priority:
/// 1. Embedded artwork from Android MediaStore for local songs.
/// 2. Cached remote artworkUrl for catalog songs.
/// 3. A stable Infinite Music gradient placeholder.
///
/// Local artwork is loaded once per widget instance and kept stable while
/// PlayerState rebuilds. This prevents the large player artwork from flashing
/// between the artwork and gradient on every position update.
class ArtworkTile extends StatefulWidget {
  final double size;
  final double radius;
  final bool amberAccent;
  final Song? song;

  const ArtworkTile({
    super.key,
    required this.size,
    this.radius = AppTheme.cardRadius,
    this.amberAccent = false,
    this.song,
  });

  @override
  State<ArtworkTile> createState() => _ArtworkTileState();
}

class _ArtworkTileState extends State<ArtworkTile> {
  static final Map<int, Uint8List> _artworkCache = <int, Uint8List>{};
  Future<Uint8List?>? _localArtworkFuture;
  int? _loadedArtworkId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prepareArtwork();
  }

  @override
  void didUpdateWidget(covariant ArtworkTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song?.artworkId != widget.song?.artworkId ||
        oldWidget.song?.id != widget.song?.id) {
      _prepareArtwork();
    }
  }

  void _prepareArtwork() {
    final id = widget.song?.isLocal == true ? widget.song?.artworkId : null;
    if (id == null || id == _loadedArtworkId) return;

    _loadedArtworkId = id;
    final cached = _artworkCache[id];
    if (cached != null) {
      _localArtworkFuture = Future<Uint8List?>.value(cached);
      return;
    }
    _localArtworkFuture = OnAudioQuery().queryArtwork(
      id,
      ArtworkType.AUDIO,
      format: ArtworkFormat.JPEG,
      size: 2000,
      quality: 100,
    );
  }

  Widget _placeholder() {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.amberAccent
              ? const [AppColors.violet, AppColors.bgElevated, AppColors.amber]
              : const [AppColors.violet, AppColors.bgElevated],
        ),
      ),
    );
  }

  Widget _frame(Widget child) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: child,
      ),
    );
  }

  Widget _localArtwork() {
    final future = _localArtworkFuture;
    if (future == null) return _placeholder();

    return FutureBuilder<Uint8List?>(
      future: future,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes != null && bytes.isNotEmpty && widget.song?.artworkId != null) {
          _artworkCache[widget.song!.artworkId!] = bytes;
        }
        if (bytes == null || bytes.isEmpty) return _placeholder();

        return _frame(
          Image.memory(
            bytes,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.high,
          ),
        );
      },
    );
  }

  Widget _remoteArtwork(String url) {
    return _frame(
      CachedNetworkImage(
        imageUrl: url,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 120),
        fadeOutDuration: Duration.zero,
        placeholderFadeInDuration: Duration.zero,
        placeholder: (_, __) => _placeholder(),
        errorWidget: (_, __, ___) => _placeholder(),
        useOldImageOnUrlChange: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.song;

    if (song?.isLocal == true && song?.artworkId != null) {
      return _localArtwork();
    }

    final url = song?.artworkUrl.trim() ?? '';
    if (url.isNotEmpty) {
      return _remoteArtwork(url);
    }

    return _placeholder();
  }
}
