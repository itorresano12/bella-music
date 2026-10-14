// lib/widgets/playlist_carousel.dart
// Horizontal scrolling carousel with interactive playlist cards.
// Tapping a playlist marks it as active, loads all its full-length tracks,
// and smoothly transitions to the Library tab.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import 'package:bella_music/models/playlist_model.dart';
import 'package:bella_music/providers/playlist_provider.dart';
import 'package:bella_music/theme/app_theme.dart';

class PlaylistCarousel extends ConsumerWidget {
  const PlaylistCarousel({super.key, required this.playlists});

  final List<Playlist> playlists;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (playlists.isEmpty) {
      return Container(
        height: 160,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppTheme.surface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppTheme.accentViolet, strokeWidth: 2),
              SizedBox(height: 12),
              Text(
                'Sincronizando playlists de tu biblioteca…',
                style: TextStyle(color: AppTheme.onSurfaceSub, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

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
          ).animate().fadeIn(delay: (60 * index).ms).slideX(begin: 0.2, end: 0);
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
    final selectedPlaylist = ref.watch(selectedPlaylistProvider);
    final isSelected = selectedPlaylist?.id == playlist.id;

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

          await ref.read(userPlaylistsProvider.notifier).selectPlaylist(
            playlist,
            autoPlay: false,
            switchToLibrary: true,
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: isSelected
                ? Border.all(color: AppTheme.accentViolet, width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? AppTheme.accentViolet.withOpacity(0.4)
                    : AppTheme.accentViolet.withOpacity(0.15),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
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
                      stops: const [0.35, 1.0],
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
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          PlaylistSourceBadge(source: playlist.source),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${playlist.trackCount} temas',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Play indicator overlay
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.accentPink
                          : AppTheme.accentViolet.withOpacity(0.9),
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

class PlaylistSourceBadge extends StatelessWidget {
  const PlaylistSourceBadge({super.key, required this.source});
  final String source;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (source.toLowerCase()) {
      'deezer'  => (const Color(0xFFEF4444), 'Deezer'),
      'amazon'  => (const Color(0xFFF97316), 'Amazon'),
      'spotify' => (const Color(0xFF1DB954), 'Spotify'),
      'tidal'   => (const Color(0xFF00FFFF), 'Tidal'),
      _         => (AppTheme.accentViolet, 'Música'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.25),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
