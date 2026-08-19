import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player_state.dart';
import '../theme/app_theme.dart';
import '../screens/player_screen.dart';
import 'artwork_tile.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerState>(
      builder: (context, playerState, _) {
        final song = playerState.currentSong;
        if (song == null || !playerState.miniPlayerVisible) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PlayerScreen()),
            );
          },
          child: Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.card.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.violet.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                ArtworkTile(size: 40, radius: 10, amberAccent: true, song: song),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.skip_previous, color: AppColors.text),
                  onPressed: playerState.skipPrevious,
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    playerState.isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                    color: AppColors.text,
                    size: 28,
                  ),
                  onPressed: playerState.togglePlayPause,
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.skip_next, color: AppColors.text),
                  onPressed: playerState.skipNext,
                ),
                IconButton(
                  tooltip: 'Hide mini player',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.muted,
                    size: 20,
                  ),
                  onPressed: playerState.dismissMiniPlayer,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
