import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player_state.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import 'song_card.dart';

class SongShelf extends StatelessWidget {
  final String title;
  final List<Song> songs;

  const SongShelf({super.key, required this.title, required this.songs});

  @override
  Widget build(BuildContext context) {
    final playerState = context.read<PlayerState>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const Text(
                'See all',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.violetSoft,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: songs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final song = songs[i];
              return SongCard(
                song: song,
                onTap: () => playerState.playSong(song, fromQueue: songs),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
