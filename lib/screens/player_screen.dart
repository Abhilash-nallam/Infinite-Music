import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import '../models/player_state.dart' as player_model;
import '../models/song.dart';
import '../providers/catalog_provider.dart';
import '../theme/app_theme.dart';
import '../services/library_store.dart';
import '../widgets/artwork_tile.dart';
import '../widgets/waveform_scrubber.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString();
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<player_model.PlayerState>(
      builder: (context, playerState, _) {
        final song = playerState.currentSong;
        if (song == null) {
          return const Scaffold(
            body: Center(child: Text('Nothing playing')),
          );
        }

        final catalog = context.watch<CatalogProvider>();
        final library = context.watch<LibraryStore>();
        Song? catalogSong;
        if (!song.isLocal) {
          for (final candidate in catalog.songs) {
            if (candidate.id == song.id) {
              catalogSong = candidate;
              break;
            }
          }
        }
        final isLiked = library.isLiked(song) || (catalogSong?.isLiked ?? song.isLiked);

        final total = song.duration.inMilliseconds;
        final current = playerState.position.inMilliseconds;
        final progress =
            total <= 0 ? 0.0 : (current / total).clamp(0.0, 1.0);

        return Scaffold(
          backgroundColor: AppColors.bg,
          body: Stack(
            children: [
              Positioned.fill(
                child: _ArtworkAtmosphere(song: song),
              ),
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                  child: Container(
                    color: AppColors.bg.withValues(alpha: .72),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _CircleButton(
                            icon: Icons.keyboard_arrow_down_rounded,
                            onTap: () => Navigator.pop(context),
                          ),
                          const Expanded(
                            child: Center(
                              child: Text(
                                'NOW PLAYING',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 10,
                                  letterSpacing: 1.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          _CircleButton(
                            icon: Icons.more_horiz_rounded,
                            onTap: () => _showMore(context, song),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              RepaintBoundary(
                                child: ArtworkTile(
                                  key: ValueKey('player-art-${song.id}'),
                                  size: MediaQuery.sizeOf(context).width - 44,
                                  radius: 26,
                                  amberAccent: true,
                                  song: song,
                                ),
                              ),
                              const SizedBox(height: 22),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          song.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.text,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          song.isLocal
                                              ? '${song.artist} · My Device'
                                              : song.artist,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.muted,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () async {
                                      if (song.isLocal) {
                                        playerState.toggleLike();
                                      } else {
                                        final next = !isLiked;
                                        await catalog.setLiked(song.id, next);
                                        playerState.setLiked(next);
                                      }
                                    },
                                    icon: Icon(
                                      isLiked
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      color: isLiked
                                          ? AppColors.amber
                                          : AppColors.text,
                                      size: 27,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              WaveformScrubber(
                                progress: progress,
                                onSeek: (p) {
                                  final newPosition = Duration(
                                    milliseconds:
                                        (p * total).round().clamp(0, total).toInt(),
                                  );
                                  playerState.seekTo(newPosition);
                                },
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(playerState.position),
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                  Text(
                                    _formatDuration(song.duration),
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 22),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _ControlIcon(
                                    icon: Icons.shuffle_rounded,
                                    active: playerState.shuffleEnabled,
                                    onTap: playerState.toggleShuffle,
                                  ),
                                  _ControlIcon(
                                    icon: Icons.skip_previous_rounded,
                                    size: 34,
                                    onTap: playerState.skipPrevious,
                                  ),
                                  GestureDetector(
                                    onTap: playerState.togglePlayPause,
                                    child: Container(
                                      width: 70,
                                      height: 70,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            AppColors.violet,
                                            AppColors.amber,
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.violet
                                                .withValues(alpha: .34),
                                            blurRadius: 28,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        playerState.isPlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 34,
                                      ),
                                    ),
                                  ),
                                  _ControlIcon(
                                    icon: Icons.skip_next_rounded,
                                    size: 34,
                                    onTap: playerState.skipNext,
                                  ),
                                  _ControlIcon(
                                    icon: playerState.repeatMode == player_model.RepeatMode.one
                                        ? Icons.repeat_one_rounded
                                        : Icons.repeat_rounded,
                                    active: playerState.repeatMode != player_model.RepeatMode.off,
                                    onTap: playerState.cycleRepeat,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: _ActionPill(
                                      icon: song.isDownloaded
                                          ? Icons.check_circle_rounded
                                          : Icons.download_rounded,
                                      label: song.isDownloaded
                                          ? 'On device'
                                          : 'Download',
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () => _showQueue(context),
                                      child: const _ActionPill(
                                        icon: Icons.queue_music_rounded,
                                        label: 'Queue',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _CircleButton(
                                    icon: Icons.share_rounded,
                                    onTap: () async {
                                      await Clipboard.setData(
                                        ClipboardData(
                                          text: '${song.title} — ${song.artist}',
                                        ),
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Song details copied to clipboard'),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAddToPlaylist(BuildContext context, Song song) async {
    final library = context.read<LibraryStore>();
    final names = library.playlistNames;

    if (names.isEmpty) {
      final controller = TextEditingController();
      final name = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Create playlist'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Playlist name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Create'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (name == null || name.isEmpty) return;
      if (library.playlistNames.contains(name)) return;
      await library.createPlaylist(name);
      await library.addToPlaylist(name, song);
      return;
    }

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              leading: Icon(Icons.playlist_add_rounded),
              title: Text('Add to playlist'),
            ),
            for (final name in names)
              ListTile(
                title: Text(name),
                subtitle: Text(
                  library.containsInPlaylist(name, song.id)
                      ? 'Already added'
                      : 'Add this song',
                ),
                onTap: library.containsInPlaylist(name, song.id)
                    ? null
                    : () => Navigator.pop(context, name),
              ),
            ListTile(
              leading: const Icon(Icons.add_rounded),
              title: const Text('Create new playlist'),
              onTap: () => Navigator.pop(context, '__create__'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (selected == null) return;
    if (selected == '__create__') {
      final controller = TextEditingController();
      final name = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Create playlist'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Playlist name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Create'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (name == null || name.isEmpty || library.playlistNames.contains(name)) {
        return;
      }
      await library.createPlaylist(name);
      await library.addToPlaylist(name, song);
    } else {
      await library.addToPlaylist(selected, song);
    }
  }

  Future<void> _showQueue(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Consumer<player_model.PlayerState>(
          builder: (context, state, _) {
            final queue = state.queue;
            return SizedBox(
              height: MediaQuery.sizeOf(context).height * .68,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Queue · ${queue.length}',
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: queue.length <= 1 ? null : state.clearQueue,
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: queue.isEmpty
                        ? const Center(
                            child: Text(
                              'Queue is empty',
                              style: TextStyle(color: AppColors.muted),
                            ),
                          )
                        : ReorderableListView.builder(
                            itemCount: queue.length,
                            onReorder: state.reorderQueue,
                            itemBuilder: (context, index) {
                              final item = queue[index];
                              final current = item.id == state.currentSong?.id;
                              return ListTile(
                                key: ValueKey('${item.id}-$index'),
                                onTap: () => state.playQueueItem(index),
                                leading: ArtworkTile(
                                  size: 46,
                                  radius: 10,
                                  song: item,
                                ),
                                title: Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: current
                                        ? AppColors.amber
                                        : AppColors.text,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  item.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 11,
                                  ),
                                ),
                                trailing: current
                                    ? const Icon(
                                        Icons.equalizer_rounded,
                                        color: AppColors.amber,
                                      )
                                    : IconButton(
                                        tooltip: 'Remove',
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          color: AppColors.muted,
                                        ),
                                        onPressed: () => state.removeFromQueue(index),
                                      ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showMore(BuildContext context, Song song) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('Song details'),
              subtitle: Text('${song.artist} · ${song.duration.inSeconds}s'),
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add_rounded),
              title: const Text('Add to playlist'),
              onTap: () {
                Navigator.pop(context);
                _showAddToPlaylist(context, song);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close_rounded),
              title: const Text('Close'),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ArtworkAtmosphere extends StatelessWidget {
  final Song song;

  const _ArtworkAtmosphere({required this.song});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Opacity(
          opacity: .24,
          child: ArtworkTile(
            size: MediaQuery.sizeOf(context).width * .9,
            radius: 36,
            song: song,
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: AppColors.text, size: 24),
    );
  }
}

class _ControlIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final bool active;
  final VoidCallback onTap;

  const _ControlIcon({
    required this.icon,
    required this.onTap,
    this.size = 22,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: active ? AppColors.amber : AppColors.text, size: size),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ActionPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgElevated.withValues(alpha: .88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.amber, size: 16),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
