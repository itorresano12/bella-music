// lib/screens/home_screen.dart
// Main screen — assembles all UI sections with premium dark layout.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:bella_music/theme/app_theme.dart';
import 'package:bella_music/providers/playlist_provider.dart';
import 'package:bella_music/services/audio_service.dart';
import 'package:bella_music/services/discovery_service.dart';
import 'package:bella_music/widgets/playlist_carousel.dart';
import 'package:bella_music/widgets/services_grid.dart';
import 'package:bella_music/widgets/now_playing_bar.dart';
import 'package:bella_music/widgets/glass_container.dart';
import 'package:bella_music/models/audio_output_mode.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists    = ref.watch(playlistsProvider);
    final services     = ref.watch(servicesProvider);
    final discovery    = ref.watch(discoveryServiceProvider);
    final audioState   = ref.watch(audioServiceProvider);
    final audioNotifier = ref.read(audioServiceProvider.notifier);
    final currentTrack  = ref.watch(currentTrackProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppTheme.background,
      appBar: _GlassAppBar(discoveryMode: discovery.mode),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Top space for AppBar
            const SliverToBoxAdapter(child: SizedBox(height: 100)),

            // ── Section: Tus Playlists ─────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tus Playlists',
                        style: Theme.of(context).textTheme.titleLarge),
                    TextButton(
                      onPressed: () {},
                      child: const Text('Ver todo',
                          style: TextStyle(color: AppTheme.accentViolet)),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 100.ms),
            ),
            SliverToBoxAdapter(
              child: PlaylistCarousel(playlists: playlists)
                  .animate()
                  .fadeIn(delay: 150.ms),
            ),

            // ── Section: Servicios Conectados ─────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                child: Text('Servicios Conectados',
                    style: Theme.of(context).textTheme.titleLarge)
                    .animate().fadeIn(delay: 200.ms),
              ),
            ),
            SliverToBoxAdapter(
              child: ServicesGrid(services: services)
                  .animate().fadeIn(delay: 250.ms),
            ),

            // ── Section: Reproducción Reciente ────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                child: Text('Reproducción Reciente',
                    style: Theme.of(context).textTheme.titleLarge)
                    .animate().fadeIn(delay: 300.ms),
              ),
            ),
            SliverToBoxAdapter(
              child: _RecentTracks(ref: ref, audioNotifier: audioNotifier)
                  .animate().fadeIn(delay: 350.ms),
            ),

            // ── Connection status card ─────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                child: _ConnectionCard(discovery: discovery),
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3, end: 0),
            ),

            // Bottom padding for NowPlayingBar
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (audioState.currentTrack != null) const NowPlayingBar(),
          _BottomNav(),
        ],
      ),
    );
  }
}

// ─── Glass AppBar ─────────────────────────────────────────────────────────────

class _GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _GlassAppBar({required this.discoveryMode});
  final AudioOutputMode discoveryMode;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 20);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          height: preferredSize.height + MediaQuery.of(context).padding.top,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            left: 20,
            right: 20,
            bottom: 8,
          ),
          decoration: BoxDecoration(
            color: AppTheme.background.withOpacity(0.7),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.08),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              // Logo
              ShaderMask(
                shaderCallback: (bounds) =>
                    AppTheme.accentGradient.createShader(bounds),
                blendMode: BlendMode.srcIn,
                child: const Text(
                  'BellaMusic',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const Spacer(),
              // Search icon
              IconButton(
                icon: const Icon(Icons.search_rounded, size: 24),
                color: AppTheme.onSurface,
                onPressed: () {},
              ),
              // Profile avatar
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppTheme.accentPink, AppTheme.accentViolet],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.person_rounded,
                    color: Colors.white, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Recent Tracks List ───────────────────────────────────────────────────────

class _RecentTracks extends ConsumerWidget {
  const _RecentTracks({required this.ref, required this.audioNotifier});
  final WidgetRef ref;
  final AudioNotifier audioNotifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(recentTracksProvider);
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: tracks.length,
      itemBuilder: (context, i) {
        final track = tracks[i];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              track.albumArt,
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 52, height: 52, color: AppTheme.surface,
                child: const Icon(Icons.music_note, color: AppTheme.accentViolet),
              ),
            ),
          ),
          title: Text(track.title,
              style: const TextStyle(
                  color: AppTheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
          subtitle: Text(track.artist,
              style: const TextStyle(color: AppTheme.onSurfaceSub, fontSize: 12)),
          trailing: IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: AppTheme.onSurfaceSub),
            onPressed: () {},
          ),
          onTap: () => audioNotifier.playTrack(track),
        );
      },
    );
  }
}

// ─── Connection Status Card ───────────────────────────────────────────────────

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.discovery});
  final dynamic discovery; // DiscoveryState

  @override
  Widget build(BuildContext context) {
    final mode = discovery.mode as AudioOutputMode;
    final isWifi = mode == AudioOutputMode.wifiSpeaker;

    return GradientCard(
      gradient: LinearGradient(
        colors: isWifi
            ? [const Color(0xFF0D2137), const Color(0xFF0A1628)]
            : [const Color(0xFF1A0D37), const Color(0xFF130A28)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (isWifi ? AppTheme.accentBlue : AppTheme.accentViolet)
                  .withOpacity(0.2),
            ),
            child: Icon(
              isWifi ? Icons.wifi_rounded : Icons.smartphone_rounded,
              color: isWifi ? AppTheme.accentBlue : AppTheme.accentViolet,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mode == AudioOutputMode.searching
                      ? 'Buscando altavoz…'
                      : isWifi
                          ? 'Altavoz Wi-Fi activo'
                          : 'Modo de Prueba activado',
                  style: const TextStyle(
                    color: AppTheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  mode == AudioOutputMode.searching
                      ? 'Escaneando la red local…'
                      : isWifi
                          ? (discovery.speakerFriendlyName != null
                              ? '${discovery.speakerFriendlyName} (${discovery.speakerIp})'
                              : 'Power Dynamics WCS50 detectado')
                          : 'Audio por altavoces del móvil',
                  style: const TextStyle(
                    color: AppTheme.onSurfaceSub,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bottom Navigation ────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface.withOpacity(0.85),
            border: Border(
              top: BorderSide(
                color: Colors.white.withOpacity(0.06),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(icon: Icons.home_rounded, label: 'Inicio', active: true),
                _NavItem(icon: Icons.search_rounded, label: 'Buscar'),
                _NavItem(icon: Icons.library_music_rounded, label: 'Librería'),
                _NavItem(icon: Icons.settings_rounded, label: 'Ajustes'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    this.active = false,
  });
  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppTheme.accentViolet : AppTheme.onSurfaceSub;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 10,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
          if (active)
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentViolet,
              ),
            ),
        ],
      ),
    );
  }
}
