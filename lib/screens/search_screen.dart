import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/player_state.dart';
import '../models/song.dart';
import '../providers/catalog_provider.dart';
import '../providers/local_music_provider.dart';
import '../theme/app_theme.dart';
import '../services/library_store.dart';
import '../widgets/artwork_tile.dart';
import 'library_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    await Future.wait<void>([
      context.read<LocalMusicProvider>().scan(),
      context.read<CatalogProvider>().syncNow(),
    ]);
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final local = context.watch<LocalMusicProvider>();
    final playerState = context.read<PlayerState>();

    return SafeArea(
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
                    'Search',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh device music',
                  onPressed: local.isLoading ? null : _refreshAll,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: TextField(
                controller: _controller,
                onChanged: _onChanged,
                style: const TextStyle(color: AppColors.text, fontSize: 14),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Songs, artists, albums',
                  hintStyle:
                      const TextStyle(color: AppColors.muted, fontSize: 13),
                  icon: const Icon(Icons.search_rounded,
                      size: 20, color: AppColors.muted),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded,
                              size: 18, color: AppColors.muted),
                          onPressed: () {
                            _controller.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _query.isEmpty
                  ? _SearchStart(local: local)
                  : _SearchResults(
                      query: _query,
                      catalog: catalog,
                      local: local,
                      playerState: playerState,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchStart extends StatelessWidget {
  final LocalMusicProvider local;

  const _SearchStart({required this.local});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const _SearchHero(),
        const SizedBox(height: 18),
        if (local.songs.isNotEmpty) ...[
          const Text('On this device', style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: local.songs.take(6).length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final song = local.songs[i];
                return GestureDetector(
                  onTap: () => context.read<PlayerState>().playSong(song, fromQueue: local.songs),
                  child: SizedBox(
                    width: 112,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      ArtworkTile(size: 112, radius: 14, song: song),
                      const SizedBox(height: 6),
                      Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.text, fontSize: 11, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
        ],
        const Text(
          'Search across your music',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            const _SuggestionChip(label: 'Recently played'),
            const _SuggestionChip(label: 'Artists'),
            const _SuggestionChip(label: 'Albums'),
            _SuggestionChip(
              label: 'My Device',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LibraryScreen(initialTab: 1)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SearchHero extends StatelessWidget {
  const _SearchHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A174B), Color(0xFF171321), Color(0xFF3D2815)],
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(Icons.graphic_eq_rounded,
              color: AppColors.violetSoft, size: 26),
          SizedBox(height: 10),
          Text(
            'Find your next favorite song',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Search your synced catalog and music on this device.',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _SuggestionChip({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      label: Text(label),
      backgroundColor: AppColors.bgElevated,
      side: BorderSide.none,
      labelStyle: const TextStyle(color: AppColors.muted, fontSize: 11),
    );
  }
}

class _SearchResults extends StatelessWidget {
  final String query;
  final CatalogProvider catalog;
  final LocalMusicProvider local;
  final PlayerState playerState;

  const _SearchResults({
    required this.query,
    required this.catalog,
    required this.local,
    required this.playerState,
  });

  bool libraryIsLiked(BuildContext context, Song song) =>
      context.read<LibraryStore>().isLiked(song);

  Future<void> _addToPlaylist(
    BuildContext context,
    LibraryStore library,
    Song song,
  ) async {
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
      if (name == null || name.isEmpty || library.playlistNames.contains(name)) return;
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
      if (name == null || name.isEmpty || library.playlistNames.contains(name)) return;
      await library.createPlaylist(name);
      await library.addToPlaylist(name, song);
    } else {
      await library.addToPlaylist(selected, song);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Song>>(
      stream: catalog.watchSearch(query),
      builder: (context, snapshot) {
        final cloud = snapshot.data ?? const <Song>[];
        final device = local.search(query);
        final results = [...device, ...cloud];

        if (!snapshot.hasData && local.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.violetSoft),
          );
        }

        if (results.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.search_off_rounded,
                    color: AppColors.muted, size: 42),
                const SizedBox(height: 12),
                Text(
                  'No results for “$query”',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: results.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final song = results[i];
            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
              onTap: () => playerState.playSong(song, fromQueue: results),
              leading: ArtworkTile(size: 52, radius: 13, song: song),
              title: Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                song.isLocal
                    ? '${song.artist} · On this device'
                    : song.albumName != null
                        ? '${song.artist} · ${song.albumName}'
                        : song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                ),
              ),
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz, color: AppColors.muted),
                onSelected: (value) async {
                  final library = context.read<LibraryStore>();
                  if (value == 'like') {
                    await library.toggleLike(song);
                  } else if (value == 'queue') {
                    await playerState.addToQueue(song);
                  } else if (value == 'playlist') {
                    await _addToPlaylist(context, library, song);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'like',
                    child: Text(
                      libraryIsLiked(context, song)
                          ? 'Remove from liked'
                          : 'Like song',
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
      },
    );
  }
}
