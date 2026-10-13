// lib/screens/home_screen.dart
// Main application screen with interactive Riverpod state management:
//   • Dynamic 4-tab bottom navigation (Inicio, Buscar, Librería, Ajustes)
//   • Interactive search connected to Deezer API
//   • Live audio player bar and active profile/service gateway modal

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:bella_music/theme/app_theme.dart';
import 'package:bella_music/models/playlist_model.dart';
import 'package:bella_music/models/audio_output_mode.dart';
import 'package:bella_music/providers/playlist_provider.dart';
import 'package:bella_music/services/audio_service.dart';
import 'package:bella_music/services/discovery_service.dart';
import 'package:bella_music/services/deezer_service.dart';
import 'package:bella_music/widgets/playlist_carousel.dart';
import 'package:bella_music/widgets/services_grid.dart';
import 'package:bella_music/widgets/now_playing_bar.dart';
import 'package:bella_music/widgets/glass_container.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(currentTabProvider);
    final discovery  = ref.watch(discoveryServiceProvider);
    final audioState = ref.watch(audioServiceProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppTheme.background,
      appBar: _GlassAppBar(
        discoveryMode: discovery.mode,
        onSearchTap: () => ref.read(currentTabProvider.notifier).state = 1,
        onProfileTap: () => _openProfileModal(context, ref),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: switch (currentTab) {
            0 => const _HomeTab(key: ValueKey(0)),
            1 => const _SearchTab(key: ValueKey(1)),
            2 => const _LibraryTab(key: ValueKey(2)),
            3 => const _SettingsTab(key: ValueKey(3)),
            _ => const _HomeTab(key: ValueKey(0)),
          },
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (audioState.currentTrack != null) const NowPlayingBar(),
          _BottomNav(
            currentTab: currentTab,
            onTabSelected: (index) =>
                ref.read(currentTabProvider.notifier).state = index,
          ),
        ],
      ),
    );
  }

  void _openProfileModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(
            color: AppTheme.accentViolet.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppTheme.accentPink, AppTheme.accentViolet],
                    ),
                  ),
                  child: const Icon(Icons.person_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Perfil de Local — Bella Music',
                      style: TextStyle(
                        color: AppTheme.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Sesión de Control Multimedia',
                      style: TextStyle(color: AppTheme.onSurfaceSub, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Text('🎵', style: TextStyle(fontSize: 24)),
              title: const Text('Configurar Cuenta Deezer (ARL)',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.onSurfaceSub),
              onTap: () {
                Navigator.pop(ctx);
                ServicesGrid.openAuthModal(context, ref, 'Deezer');
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Text('🎶', style: TextStyle(fontSize: 24)),
              title: const Text('Configurar Amazon Music',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.onSurfaceSub),
              onTap: () {
                Navigator.pop(ctx);
                ServicesGrid.openAuthModal(context, ref, 'Amazon Music');
              },
            ),
            const Divider(color: Colors.white12, height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.settings_rounded, color: AppTheme.accentBlue),
              title: const Text('Ir a Ajustes y Altavoces Wi-Fi',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.onSurfaceSub),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(currentTabProvider.notifier).state = 3;
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Glass AppBar ─────────────────────────────────────────────────────────────

class _GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _GlassAppBar({
    required this.discoveryMode,
    required this.onSearchTap,
    required this.onProfileTap,
  });

  final AudioOutputMode discoveryMode;
  final VoidCallback onSearchTap;
  final VoidCallback onProfileTap;

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
              ShaderMask(
                shaderCallback: (bounds) =>
                    AppTheme.accentGradient.createShader(bounds),
                blendMode: BlendMode.srcIn,
                child: const Text(
                  'Bella Music',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.search_rounded, size: 24),
                color: AppTheme.onSurface,
                onPressed: onSearchTap,
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onProfileTap,
                child: Container(
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Tab 0: Inicio ────────────────────────────────────────────────────────────

class _HomeTab extends ConsumerWidget {
  const _HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists     = ref.watch(playlistsProvider);
    final services      = ref.watch(servicesProvider);
    final discovery     = ref.watch(discoveryServiceProvider);
    final audioNotifier = ref.read(audioServiceProvider.notifier);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 100)),

        // Playlists
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Tus Playlists',
                    style: Theme.of(context).textTheme.titleLarge),
                TextButton(
                  onPressed: () =>
                      ref.read(currentTabProvider.notifier).state = 2,
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

        // Servicios Conectados
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
            child: Text('Servicios Conectados',
                    style: Theme.of(context).textTheme.titleLarge)
                .animate()
                .fadeIn(delay: 200.ms),
          ),
        ),
        SliverToBoxAdapter(
          child: ServicesGrid(services: services)
              .animate()
              .fadeIn(delay: 250.ms),
        ),

        // Reproducción Reciente
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
            child: Text('Reproducción Reciente',
                    style: Theme.of(context).textTheme.titleLarge)
                .animate()
                .fadeIn(delay: 300.ms),
          ),
        ),
        SliverToBoxAdapter(
          child: _RecentTracks(audioNotifier: audioNotifier)
              .animate()
              .fadeIn(delay: 350.ms),
        ),

        // Estado del altavoz
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
            child: _ConnectionCard(discovery: discovery),
          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3, end: 0),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }
}

// ─── Tab 1: Buscar ────────────────────────────────────────────────────────────

class _SearchTab extends ConsumerStatefulWidget {
  const _SearchTab({super.key});

  @override
  ConsumerState<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends ConsumerState<_SearchTab> {
  final _searchCtrl = TextEditingController();
  List<Track> _searchResults = [];
  bool _isSearching = false;

  Future<void> _performSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    final results = await DeezerService.instance.searchTracks(q);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioNotifier = ref.read(audioServiceProvider.notifier);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 110)),

        // Search Bar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              onSubmitted: _performSearch,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.surfaceLight,
                hintText: 'Buscar canciones, artistas o géneros en Deezer…',
                hintStyle: const TextStyle(color: AppTheme.onSurfaceSub, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.accentViolet),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white54),
                        onPressed: () {
                          _searchCtrl.clear();
                          _performSearch('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppTheme.accentViolet, width: 1.5),
                ),
              ),
            ),
          ),
        ),

        // Quick Suggestions
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _SearchChip(
                    label: 'Tasty Santander',
                    onTap: () {
                      _searchCtrl.text = 'Tasty Santander';
                      _performSearch('Tasty Santander');
                    },
                  ),
                  _SearchChip(
                    label: 'Pop en Español',
                    onTap: () {
                      _searchCtrl.text = 'Pop en Español';
                      _performSearch('Pop en Español');
                    },
                  ),
                  _SearchChip(
                    label: 'Chillout Lounge',
                    onTap: () {
                      _searchCtrl.text = 'Chillout';
                      _performSearch('Chillout');
                    },
                  ),
                  _SearchChip(
                    label: 'Rock Clásico',
                    onTap: () {
                      _searchCtrl.text = 'Rock';
                      _performSearch('Rock');
                    },
                  ),
                ],
              ),
            ),
          ),
        ),

        if (_isSearching)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.accentViolet),
              ),
            ),
          ),

        if (!_isSearching && _searchResults.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Resultados de búsqueda (${_searchResults.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),

        if (!_isSearching && _searchResults.isNotEmpty)
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final track = _searchResults[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        track.albumArt,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 52,
                          height: 52,
                          color: AppTheme.surface,
                          child: const Icon(Icons.music_note, color: AppTheme.accentViolet),
                        ),
                      ),
                    ),
                    title: Text(
                      track.title,
                      style: const TextStyle(
                        color: AppTheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      track.artist,
                      style: const TextStyle(color: AppTheme.onSurfaceSub, fontSize: 12),
                    ),
                    trailing: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.accentViolet.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow_rounded, color: AppTheme.accentViolet, size: 22),
                    ),
                    onTap: () {
                      audioNotifier.playTrack(track);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          duration: const Duration(seconds: 1),
                          backgroundColor: const Color(0xFF1E293B),
                          content: Text('Reproduciendo: ${track.title}'),
                        ),
                      );
                    },
                  ),
                );
              },
              childCount: _searchResults.length,
            ),
          ),

        if (!_isSearching && _searchResults.isEmpty && _searchCtrl.text.isNotEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text('No se encontraron canciones.',
                    style: TextStyle(color: AppTheme.onSurfaceSub)),
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }
}

class _SearchChip extends StatelessWidget {
  const _SearchChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        backgroundColor: AppTheme.surfaceLight,
        label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        onPressed: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.accentViolet.withOpacity(0.2)),
        ),
      ),
    );
  }
}

// ─── Tab 2: Librería ──────────────────────────────────────────────────────────

class _LibraryTab extends ConsumerWidget {
  const _LibraryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists     = ref.watch(playlistsProvider);
    final audioNotifier = ref.read(audioServiceProvider.notifier);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 110)),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tu Librería', style: Theme.of(context).textTheme.titleLarge),
                    Text(
                      '${playlists.length} Playlists disponibles',
                      style: const TextStyle(color: AppTheme.onSurfaceSub, fontSize: 13),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.sync_rounded, color: AppTheme.accentViolet),
                  onPressed: () async {
                    final res = await DeezerService.instance.searchPlaylists('Tasty Santander');
                    if (res.isNotEmpty) {
                      ref.read(playlistsProvider.notifier).setPlaylists(res);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Color(0xFF1E293B),
                          content: Text('Librería sincronizada con Deezer.'),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),

        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final pl = playlists[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: ListTile(
                  tileColor: AppTheme.surfaceLight.withOpacity(0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  contentPadding: const EdgeInsets.all(8),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      pl.coverUrl,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 56,
                        height: 56,
                        color: AppTheme.surface,
                        child: const Icon(Icons.music_note, color: AppTheme.accentViolet),
                      ),
                    ),
                  ),
                  title: Text(
                    pl.name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  subtitle: Text(
                    '${pl.trackCount} canciones • ${pl.source.toUpperCase()}',
                    style: const TextStyle(color: AppTheme.onSurfaceSub, fontSize: 12),
                  ),
                  trailing: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      gradient: AppTheme.accentGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
                  ),
                  onTap: () async {
                    final tracks = await DeezerService.instance.getPlaylistTracks(pl.id);
                    if (tracks.isNotEmpty) {
                      ref.read(recentTracksProvider.notifier).setTracks(tracks);
                      audioNotifier.playTrack(tracks.first);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          duration: const Duration(seconds: 1),
                          backgroundColor: const Color(0xFF1E293B),
                          content: Text('Reproduciendo lista: ${pl.name}'),
                        ),
                      );
                    }
                  },
                ),
              );
            },
            childCount: playlists.length,
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }
}

// ─── Tab 3: Ajustes ───────────────────────────────────────────────────────────

class _SettingsTab extends ConsumerWidget {
  const _SettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discovery = ref.watch(discoveryServiceProvider);
    final discoveryNotifier = ref.read(discoveryServiceProvider.notifier);
    final isWifi = discovery.mode == AudioOutputMode.wifiSpeaker;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 110)),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Ajustes y Red', style: Theme.of(context).textTheme.titleLarge),
          ),
        ),

        // Sección Salida de Audio
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text('Salida de Audio y Altavoces', style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        isWifi ? Icons.speaker_rounded : Icons.smartphone_rounded,
                        color: isWifi ? AppTheme.accentBlue : AppTheme.accentViolet,
                        size: 28,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isWifi ? 'Altavoces Wi-Fi UPnP Activos' : 'Altavoz Local del Móvil',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            Text(
                              discovery.speakerIp != null
                                  ? 'IP: ${discovery.speakerIp} (Power Dynamics WCS50)'
                                  : 'Reproduciendo por los altavoces de tu teléfono',
                              style: const TextStyle(color: AppTheme.onSurfaceSub, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => discoveryNotifier.switchToLocal(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: !isWifi ? AppTheme.accentViolet : Colors.white24,
                            ),
                            backgroundColor: !isWifi ? AppTheme.accentViolet.withOpacity(0.2) : null,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Altavoz Móvil', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => discoveryNotifier.switchToWifiSpeaker(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: isWifi ? AppTheme.accentBlue : Colors.white24,
                            ),
                            backgroundColor: isWifi ? AppTheme.accentBlue.withOpacity(0.2) : null,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Altavoces Wi-Fi', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      icon: const Icon(Icons.radar_rounded, size: 18, color: AppTheme.accentBlue),
                      label: const Text('Re-escanear altavoces en la red Wi-Fi',
                          style: TextStyle(color: AppTheme.accentBlue, fontSize: 12)),
                      onPressed: () {
                        discoveryNotifier.startDiscovery();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: Color(0xFF1E293B),
                            content: Text('Buscando altavoces UPnP en 239.255.255.250...'),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Sección Servicios y Seguridad
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Text('Cuentas y Streaming', style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                ListTile(
                  tileColor: AppTheme.surfaceLight,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: const Text('🎵', style: TextStyle(fontSize: 24)),
                  title: const Text('Pasarela Deezer (ARL)', style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text('Gestionar token y playlists sincronizadas', style: TextStyle(color: AppTheme.onSurfaceSub, fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54),
                  onTap: () => ServicesGrid.openAuthModal(context, ref, 'Deezer'),
                ),
                const SizedBox(height: 10),
                ListTile(
                  tileColor: AppTheme.surfaceLight,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: const Text('🎶', style: TextStyle(fontSize: 24)),
                  title: const Text('Pasarela Amazon Music', style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text('Credenciales de streaming cifradas', style: TextStyle(color: AppTheme.onSurfaceSub, fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54),
                  onTap: () => ServicesGrid.openAuthModal(context, ref, 'Amazon Music'),
                ),
              ],
            ),
          ),
        ),

        // Información de Criptografía
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF131B2A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.accentBlue.withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_rounded, color: Color(0xFF22C55E), size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hardware Keystore Activo',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        Text(
                          'Claves protegidas con AES-256-GCM y TLS 1.3 estricto.',
                          style: TextStyle(color: AppTheme.onSurfaceSub, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }
}

// ─── Recent Tracks List ───────────────────────────────────────────────────────

class _RecentTracks extends ConsumerWidget {
  const _RecentTracks({required this.audioNotifier});
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
                width: 52,
                height: 52,
                color: AppTheme.surface,
                child: const Icon(Icons.music_note, color: AppTheme.accentViolet),
              ),
            ),
          ),
          title: Text(
            track.title,
            style: const TextStyle(
              color: AppTheme.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            track.artist,
            style: const TextStyle(color: AppTheme.onSurfaceSub, fontSize: 12),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.play_circle_fill_rounded, color: AppTheme.accentViolet, size: 30),
            onPressed: () => audioNotifier.playTrack(track),
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
  final dynamic discovery;

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
              isWifi ? Icons.speaker_rounded : Icons.smartphone_rounded,
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
                          ? 'Altavoces Wi-Fi UPnP enlazados'
                          : 'Modo Local (Altavoces del Móvil)',
                  style: const TextStyle(
                    color: AppTheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  mode == AudioOutputMode.searching
                      ? 'Escaneando multicast 239.255.255.250…'
                      : isWifi
                          ? (discovery.speakerFriendlyName != null
                              ? '${discovery.speakerFriendlyName}'
                              : 'Altavoz Wi-Fi detectado')
                          : 'Audio sonando directamente en el teléfono',
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
  const _BottomNav({
    required this.currentTab,
    required this.onTabSelected,
  });

  final int currentTab;
  final ValueChanged<int> onTabSelected;

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
                _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Inicio',
                  active: currentTab == 0,
                  onTap: () => onTabSelected(0),
                ),
                _NavItem(
                  icon: Icons.search_rounded,
                  label: 'Buscar',
                  active: currentTab == 1,
                  onTap: () => onTabSelected(1),
                ),
                _NavItem(
                  icon: Icons.library_music_rounded,
                  label: 'Librería',
                  active: currentTab == 2,
                  onTap: () => onTabSelected(2),
                ),
                _NavItem(
                  icon: Icons.settings_rounded,
                  label: 'Ajustes',
                  active: currentTab == 3,
                  onTap: () => onTabSelected(3),
                ),
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
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppTheme.accentViolet : AppTheme.onSurfaceSub;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
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
      ),
    );
  }
}
