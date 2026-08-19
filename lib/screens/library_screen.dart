import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/player_state.dart';
import '../models/song.dart';
import '../providers/catalog_provider.dart';
import '../providers/local_music_provider.dart';
import '../services/library_store.dart';
import '../theme/app_theme.dart';
import '../widgets/artwork_tile.dart';

class LibraryScreen extends StatefulWidget {
  final int initialTab;

  const LibraryScreen({super.key, this.initialTab = 1});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int _tabIndex = 1;
  final _tabs = const ['Downloads', 'My Device', 'Playlists', 'Liked'];

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.initialTab.clamp(0, 3).toInt();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocalMusicProvider>().scan();
    });
  }

  @override
  Widget build(BuildContext context) {
    final playerState = context.read<PlayerState>();
    final catalog = context.watch<CatalogProvider>();
    final localMusic = context.watch<LocalMusicProvider>();
    final library = context.watch<LibraryStore>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Your Library',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh device music',
                    onPressed: localMusic.isLoading ? null : localMusic.scan,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(_tabs.length, (i) {
                    final active = i == _tabIndex;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: GestureDetector(
                        onTap: () => setState(() => _tabIndex = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.violet
                                : AppColors.bgElevated,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _tabs[i],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: active ? Colors.white : AppColors.muted,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: _buildTabContent(
                  catalog: catalog,
                  localMusic: localMusic,
                  library: library,
                  playerState: playerState,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent({
    required CatalogProvider catalog,
    required LocalMusicProvider localMusic,
    required LibraryStore library,
    required PlayerState playerState,
  }) {
    if (_tabIndex == 0) {
      return _SongList(
        songs: catalog.downloadedSongs,
        playerState: playerState,
        library: library,
        emptyMessage: 'No downloaded songs yet',
      );
    }

    if (_tabIndex == 1) {
      return _LocalDeviceTab(
        provider: localMusic,
        playerState: playerState,
        library: library,
      );
    }

    if (_tabIndex == 2) {
      return _PlaylistsTab(
        library: library,
        playerState: playerState,
        onCreate: () => _showCreatePlaylist(context),
      );
    }

    final merged = <String, Song>{};
    for (final song in catalog.likedSongs) {
      merged[song.id] = song;
    }
    for (final song in library.likedSongs) {
      merged[song.id] = song;
    }

    return _SongList(
      songs: merged.values.toList(growable: false),
      playerState: playerState,
      library: library,
      emptyMessage: 'No liked songs yet',
    );
  }

  Future<void> _showCreatePlaylist(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Playlist name'),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) Navigator.pop(context, value.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (!mounted || name == null) return;
    final store = context.read<LibraryStore>();
    if (store.playlistNames.contains(name)) {
      _showMessage('A playlist with that name already exists.');
      return;
    }
    await store.createPlaylist(name);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PlaylistsTab extends StatelessWidget {
  final LibraryStore library;
  final PlayerState playerState;
  final VoidCallback onCreate;

  const _PlaylistsTab({
    required this.library,
    required this.playerState,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final names = library.playlistNames;
    if (names.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 42),
          const _IconBubble(icon: Icons.queue_music_rounded),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'Make your first playlist',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text(
              'Collect your favorite songs in one place.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create playlist'),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New playlist'),
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: names.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final name = names[index];
              final songs = library.songsInPlaylist(name);
              return ListTile(
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      colors: [AppColors.violet, AppColors.amber],
                    ),
                  ),
                  child: const Icon(Icons.queue_music_rounded, color: Colors.white),
                ),
                title: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  '${songs.length} ${songs.length == 1 ? 'song' : 'songs'}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _PlaylistDetailScreen(
                      name: name,
                      library: library,
                      playerState: playerState,
                    ),
                  ),
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'rename') {
                      final controller = TextEditingController(text: name);
                      final renamed = await showDialog<String>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Rename playlist'),
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
                              onPressed: () => Navigator.pop(
                                context,
                                controller.text.trim(),
                              ),
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                      );
                      controller.dispose();
                      if (renamed != null && renamed.isNotEmpty) {
                        await library.renamePlaylist(name, renamed);
                      }
                    } else if (value == 'delete') {
                      await library.deletePlaylist(name);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PlaylistDetailScreen extends StatelessWidget {
  final String name;
  final LibraryStore library;
  final PlayerState playerState;

  const _PlaylistDetailScreen({
    required this.name,
    required this.library,
    required this.playerState,
  });

  @override
  Widget build(BuildContext context) {
    final songs = library.songsInPlaylist(name);
    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          IconButton(
            tooltip: 'Play all',
            onPressed: songs.isEmpty
                ? null
                : () => playerState.playSong(songs.first, fromQueue: songs),
            icon: const Icon(Icons.play_arrow_rounded),
          ),
        ],
      ),
      body: songs.isEmpty
          ? const Center(
              child: Text(
                'This playlist is empty',
                style: TextStyle(color: AppColors.muted),
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
              itemCount: songs.length,
              onReorder: (oldIndex, newIndex) =>
                  library.reorderPlaylist(name, oldIndex, newIndex),
              itemBuilder: (context, index) {
                final song = songs[index];
                return ListTile(
                  key: ValueKey('${song.id}-$index'),
                  onTap: () => playerState.playSong(song, fromQueue: songs),
                  leading: ArtworkTile(size: 52, radius: 13, song: song),
                  title: Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                  trailing: IconButton(
                    tooltip: 'Remove from playlist',
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                    onPressed: () => library.removeFromPlaylist(name, song.id),
                  ),
                );
              },
            ),
    );
  }
}

class _LocalDeviceTab extends StatelessWidget {
  final LocalMusicProvider provider;
  final PlayerState playerState;
  final LibraryStore library;

  const _LocalDeviceTab({
    required this.provider,
    required this.playerState,
    required this.library,
  });

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading || provider.status == LocalMusicStatus.idle) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.violetSoft),
      );
    }

    if (provider.status == LocalMusicStatus.permissionDenied) {
      return _PermissionState(onRetry: provider.scan);
    }

    if (provider.status == LocalMusicStatus.error) {
      return _ErrorState(
        message: provider.error ?? 'Could not scan device music.',
        onRetry: provider.scan,
      );
    }

    if (provider.songs.isEmpty) {
      return const _EmptyDeviceState();
    }

    return RefreshIndicator(
      color: AppColors.violet,
      onRefresh: provider.scan,
      child: _SongList(
        songs: provider.songs,
        playerState: playerState,
        library: library,
        emptyMessage: 'No audio files found',
      ),
    );
  }
}

class _SongList extends StatelessWidget {
  final List<Song> songs;
  final PlayerState playerState;
  final LibraryStore library;
  final String emptyMessage;

  const _SongList({
    required this.songs,
    required this.playerState,
    required this.library,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 50),
          Center(
            child: Text(
              emptyMessage,
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: songs.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final song = songs[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          onTap: () => playerState.playSong(song, fromQueue: songs),
          leading: ArtworkTile(size: 54, radius: 13, song: song),
          title: Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          subtitle: Text(
            song.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, color: AppColors.muted),
            onSelected: (value) => _handleMenu(context, value, song),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'like',
                child: Text(
                  library.isLiked(song) ? 'Remove from liked' : 'Like song',
                ),
              ),
              const PopupMenuItem(
                value: 'queue',
                child: Text('Add to queue'),
              ),
              const PopupMenuItem(
                value: 'playlist',
                child: Text('Add to playlist'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleMenu(
    BuildContext context,
    String value,
    Song song,
  ) async {
    if (value == 'like') {
      await library.toggleLike(song);
    } else if (value == 'queue') {
      await playerState.addToQueue(song);
    } else if (value == 'playlist') {
      await _showAddToPlaylist(context, song);
    }
  }

  Future<void> _showAddToPlaylist(BuildContext context, Song song) async {
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
              onPressed: () => Navigator.pop(
                context,
                controller.text.trim(),
              ),
              child: const Text('Create'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (name == null || name.isEmpty) return;
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
      if (name == null || name.isEmpty) return;
      await library.createPlaylist(name);
      await library.addToPlaylist(name, song);
    } else {
      await library.addToPlaylist(selected, song);
    }
  }
}

class _PermissionState extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _PermissionState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _IconBubble(icon: Icons.music_note_rounded),
            const SizedBox(height: 16),
            const Text(
              'Let Infinite Music access your device music',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This is only used to find and play songs stored on your phone.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.lock_open_rounded, size: 17),
              label: const Text('Allow music access'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDeviceState extends StatelessWidget {
  const _EmptyDeviceState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _IconBubble(icon: Icons.library_music_outlined),
          SizedBox(height: 16),
          Text(
            'No music found on this device',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Add an audio file to your phone and refresh.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _IconBubble(icon: Icons.error_outline_rounded),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  final IconData icon;

  const _IconBubble({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppColors.violet, AppColors.amber],
        ),
      ),
      child: Icon(icon, color: Colors.white, size: 27),
    );
  }
}
