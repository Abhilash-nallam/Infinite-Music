import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/catalog_provider.dart';
import '../providers/local_music_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/artwork_tile.dart';
import '../widgets/song_shelf.dart';
import 'library_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Good night';
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    if (hour < 21) return 'Good evening';
    return 'Good night';
  }

  void _openMyDevice(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LibraryScreen(initialTab: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final local = context.watch<LocalMusicProvider>();

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.violet,
        onRefresh: () async {
          await Future.wait<void>([
            catalog.syncNow(),
            local.scan(),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_greeting()}, Abhilash',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Your music, ready when you are',
                        style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                _AiButton(
                  onTap: () => _showAiAgent(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _HeroCard(
              localCount: local.songs.length,
              onTap: () => _openMyDevice(context),
            ),
            const SizedBox(height: 18),
            _LocalDeviceBanner(
              songs: local.songs,
              onTap: () => _openMyDevice(context),
            ),
            const SizedBox(height: 18),
            if (local.songs.isNotEmpty)
              SongShelf(
                title: 'On this device',
                songs: local.songs.take(8).toList(),
              ),
            if (catalog.hasCatalog) ...[
              if (catalog.syncError != null) const _OfflineBanner(),
              SongShelf(
                title: 'Recently Added',
                songs: catalog.songs.take(8).toList(),
              ),
              SongShelf(
                title: 'For You',
                songs: catalog.songs.skip(8).take(8).toList(),
              ),
              SongShelf(
                title: 'More music',
                songs: catalog.songs.skip(16).take(8).toList(),
              ),
            ] else ...[
              const _CatalogOfflineCard(),
              const SizedBox(height: 14),
              _OfflineLocalCard(
                count: local.songs.length,
                onTap: () => _openMyDevice(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAiAgent(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.bgElevated,
      builder: (_) => const Padding(
        padding: EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AiBadge(size: 54),
            SizedBox(height: 12),
            Text(
              'AI Music Agent · Premium',
              style: TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 8),
            Text(
              'Your AI music assistant will be connected after the production service is ready.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AiButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: const _AiBadge(size: 48),
    );
  }
}

class _AiBadge extends StatelessWidget {
  final double size;
  const _AiBadge({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [AppColors.violet, AppColors.amber]),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
          Positioned(
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Text('AI', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final int localCount;
  final VoidCallback onTap;
  const _HeroCard({required this.localCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        height: 174,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6D28D9), Color(0xFF25163F), Color(0xFFD97706)],
            stops: [0, .62, 1],
          ),
          boxShadow: [
            BoxShadow(color: AppColors.violet.withValues(alpha: .18), blurRadius: 28, offset: const Offset(0, 14)),
          ],
        ),
        child: Stack(
          children: [
            const Positioned(right: -18, top: -24, child: Icon(Icons.graphic_eq_rounded, color: Colors.white24, size: 130)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text('INFINITE MUSIC', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                const SizedBox(height: 5),
                const Text('Your music.\nOne tap away.', style: TextStyle(color: Colors.white, fontSize: 22, height: 1.05, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Text(localCount > 0 ? '$localCount songs on this device · Tap to open My Device' : 'Tap to open My Device', style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalDeviceBanner extends StatelessWidget {
  final List songs;
  final VoidCallback onTap;
  const _LocalDeviceBanner({required this.songs, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final song = songs.isNotEmpty ? songs.first : null;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        height: 82,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.violet.withValues(alpha: .16)),
        ),
        child: Row(
          children: [
            if (song != null) ArtworkTile(size: 62, radius: 14, song: song) else const _FallbackArt(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('My Device', style: TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w700)),
                  Text(song == null ? 'Your offline music' : song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 10.5)),
                  const Text('Play without internet', style: TextStyle(color: AppColors.violetSoft, fontSize: 10)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _FallbackArt extends StatelessWidget {
  const _FallbackArt();
  @override
  Widget build(BuildContext context) => Container(width: 62, height: 62, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [AppColors.violet, AppColors.amber])), child: const Icon(Icons.music_note_rounded, color: Colors.white));
}

class _CatalogOfflineCard extends StatelessWidget {
  const _CatalogOfflineCard();
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.bgElevated, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.violet.withValues(alpha: .16))), child: const Row(children: [Icon(Icons.cloud_off_rounded, color: AppColors.violetSoft, size: 25), SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Online catalog is offline', style: TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w700)), SizedBox(height: 4), Text('Local music stays available. Pull down to retry the online catalog when your connection returns.', style: TextStyle(color: AppColors.muted, fontSize: 10.5, height: 1.4))]))]));
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: AppColors.bgElevated, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.amber.withValues(alpha: .25))), child: const Row(children: [Icon(Icons.wifi_off_rounded, size: 15, color: AppColors.amber), SizedBox(width: 8), Expanded(child: Text('You are offline. Cached online music and device music remain available.', style: TextStyle(color: AppColors.muted, fontSize: 10.5)))]));
}

class _OfflineLocalCard extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _OfflineLocalCard({required this.count, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.bgElevated, borderRadius: BorderRadius.circular(18)), child: Row(children: [const Icon(Icons.phone_android_rounded, color: AppColors.violetSoft), const SizedBox(width: 12), Expanded(child: Text('$count local song${count == 1 ? '' : 's'} available offline', style: const TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.w600))), const Icon(Icons.chevron_right_rounded, color: AppColors.muted)])));
}
