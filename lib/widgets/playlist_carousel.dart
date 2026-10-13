// lib/widgets/playlist_carousel.dart
// Horizontal scrolling carousel with interactive playlist cards.
// Tapping a playlist loads its real tracks from Deezer/Amazon and starts playback.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import 'package:bella_music/models/playlist_model.dart';
import 'package:bella_music/providers/playlist_provider.dart';
import 'package:bella_music/services/audio_service.dart';
import 'package:bella_music/services/deezer_service.dart';
import 'package:bella_music/theme/app_theme.dart';

class PlaylistCarousel extends ConsumerWidget {
  const PlaylistCarousel({super.key, required this.playlists});

  final List<Playlist> playlists;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: playlists.length,
        itemBuilder: (context, index) {
          return _PlaylistCard(
            playlist: playlists[index],
            index: index,
          ).animate().fadeIn(delay: (80 * index).ms).slideX(begin: 0.3, end: 0);
        },
      ),
    );
  }
}

class _PlaylistCard extends ConsumerWidget {
  const _PlaylistCard({required this.playlist, required this.index});

  final Playlist playlist;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 16),
      child: GestureDetector(
        onTap: () async {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 1),
              backgroundColor: const Color(0xFF1E293B),
              content: Text(
                'Cargando canciones de ${playlist.name}...',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          );

          if (playlist.source == 'deezer' && playlist.id.isNotEmpty) {
            final tracks = await DeezerService.instance.getPlaylistTracks(playlist.id);
            if (tracks.isNotEmpty) {
              ref.read(recentTracksProvider.notifier).setTracks(tracks);
              ref.read(audioServiceProvider.notifier).playTrack(tracks.first);
              return;
            }
          }

          // Fallback: play existing tracks
          final currentTracks = ref.read(recentTracksProvider);
          if (currentTracks.isNotEmpty) {
            ref.read(audioServiceProvider.notifier).playTrack(currentTracks.first);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentViolet.withOpacity(0.2),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Cover art
                CachedNetworkImage(
                  imageUrl: playlist.coverUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Shimmer.fromColors(
                    baseColor: AppTheme.surface,
                    highlightColor: AppTheme.surfaceLight,
                    child: Container(color: AppTheme.surface),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: AppTheme.surface,
                    child: const Icon(Icons.music_note, size: 48,
                        color: AppTheme.accentViolet),
                  ),
                ),
                // Gradient overlay
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.85),
                      ],
                      stops: const [0.4, 1.0],
                    ),
                  ),
                ),
                // Text labels
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        playlist.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _SourceBadge(source: playlist.source),
                          const SizedBox(width: 6),
                          Text(
                            '${playlist.trackCount} tracks',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Play button overlay
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.accentViolet.withOpacity(0.9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.source});
  final String source;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (source) {
      'deezer'  => (const Color(0xFFEF4444), 'Deezer'),
      'amazon'  => (const Color(0xFFF97316), 'Amazon'),
      _         => (AppTheme.accentViolet, 'Local'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5), width: 0.5),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
    );
  }
}
