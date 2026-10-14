// lib/screens/home_screen.dart
// Main application screen with interactive Riverpod state management:
//   • Dynamic 4-tab bottom navigation (Inicio, Buscar, Librería, Ajustes)
//   • Interactive search connected to Deezer API
//   • Live audio player bar and active profile/service gateway modal

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:bella_music/theme/app_theme.dart';
import 'package:bella_music/models/playlist_model.dart';
import 'package:bella_music/models/audio_output_mode.dart';
import 'package:bella_music/providers/playlist_provider.dart';
import 'package:bella_music/providers/kiosk_mode_provider.dart';
import 'package:bella_music/services/audio_service.dart';
import 'package:bella_music/services/discovery_service.dart';
import 'package:bella_music/services/emergency_audio_service.dart';
import 'package:bella_music/services/deezer_service.dart';
import 'package:bella_music/widgets/playlist_carousel.dart';
import 'package:bella_music/widgets/services_grid.dart';
import 'package:bella_music/widgets/now_playing_bar.dart';
import 'package:bella_music/widgets/glass_container.dart';
import 'package:bella_music/screens/auth_webview_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(currentTabProvider);
    final discovery  = ref.watch(discoveryServiceProvider);
    final audioState = ref.watch(audioServiceProvider);
    final isKioskLocked = ref.watch(kioskModeProvider);
    final isEmergencyOffline = ref.watch(emergencyModeProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppTheme.background,
      appBar: _GlassAppBar(
        discoveryMode: discovery.mode,
        isKioskLocked: isKioskLocked,
        onKioskLockTap: () => ref.read(kioskModeProvider.notifier).toggle(),
        onSearchTap: () {
          if (!isKioskLocked) {
            ref.read(currentTabProvider.notifier).state = 1;
          }
        },
        onProfileTap: () {
          if (!isKioskLocked) {
            _openProfileModal(context, ref);
          }
        },
      ),
      body: Stack(
        children: [
          AbsorbPointer(
            absorbing: isKioskLocked,
            child: Container(
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
          ),
          if (isEmergencyOffline)
            Positioned(
              top: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
              left: 0,
              right: 0,
              child: _EmergencyOfflineBanner(
                onDismiss: () => ref.read(emergencyModeProvider.notifier).state = false,
              ),
            ),
          if (isKioskLocked) ...[
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.35),
              ),
            ),
            Positioned(
              bottom: 110,
              right: 20,
              child: _KioskUnlockButton(
                onUnlocked: () {
                  HapticFeedback.heavyImpact();
                  ref.read(kioskModeProvider.notifier).unlock();
                },
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: AbsorbPointer(
        absorbing: isKioskLocked,
        child: Column(
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
              title: const Text('Iniciar Sesión Deezer Premium',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: const Text('Streaming comercial oficial a 320 kbps',
                  style: TextStyle(color: AppTheme.onSurfaceSub, fontSize: 11)),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.onSurfaceSub),
              onTap: () {
                Navigator.pop(ctx);
                ServicesGrid.openAuthModal(context, ref, 'Deezer');
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Text('🎶', style: TextStyle(fontSize: 24)),
              title: const Text('Iniciar Sesión Amazon Music',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: const Text('Acceso ilimitado de alta fidelidad',
                  style: TextStyle(color: AppTheme.onSurfaceSub, fontSize: 11)),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.onSurfaceSub),
              onTap: () {
                Navigator.pop(ctx);
                ServicesGrid.openAuthModal(context, ref, 'Amazon Music');
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Text('🟢', style: TextStyle(fontSize: 24)),
              title: const Text('Iniciar Sesión Spotify Premium',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: const Text('Streaming comercial oficial',
                  style: TextStyle(color: AppTheme.onSurfaceSub, fontSize: 11)),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.onSurfaceSub),
              onTap: () {
                Navigator.pop(ctx);
                ServicesGrid.openAuthModal(context, ref, 'Spotify');
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Text('⬛', style: TextStyle(fontSize: 24)),
              title: const Text('Iniciar Sesión Tidal HiFi',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: const Text('Streaming Lossless Master Audio',
                  style: TextStyle(color: AppTheme.onSurfaceSub, fontSize: 11)),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.onSurfaceSub),
              onTap: () {
                Navigator.pop(ctx);
                ServicesGrid.openAuthModal(context, ref, 'Tidal');
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
    this.isKioskLocked = false,
    this.onKioskLockTap,
  });

  final AudioOutputMode discoveryMode;
  final VoidCallback onSearchTap;
  final VoidCallback onProfileTap;
  final bool isKioskLocked;
  final VoidCallback? onKioskLockTap;

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
                icon: Icon(
                  isKioskLocked ? Icons.lock_rounded : Icons.lock_outline_rounded,
                  size: 22,
                ),
                color: isKioskLocked ? AppTheme.accentPink : AppTheme.onSurface,
                tooltip: isKioskLocked ? 'Modo Kiosco Bloqueado' : 'Bloquear Mostrador',
                onPressed: onKioskLockTap,
              ),
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

// ─── Emergency Offline Banner ─────────────────────────────────────────────────

class _EmergencyOfflineBanner extends StatelessWidget {
  const _EmergencyOfflineBanner({required this.onDismiss});
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF9A3412).withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF97316), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Modo Emergencia Offline Activo (Sin Internet)',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
          ),
        ],
      ),
    );
  }
}

// ─── Kiosk Unlock Button (3-Second Long Press) ────────────────────────────────

class _KioskUnlockButton extends StatefulWidget {
  const _KioskUnlockButton({required this.onUnlocked});
  final VoidCallback onUnlocked;

  @override
  State<_KioskUnlockButton> createState() => _KioskUnlockButtonState();
}

class _KioskUnlockButtonState extends State<_KioskUnlockButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onUnlocked();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _controller.forward(),
      onLongPressEnd: (_) {
        if (_controller.status != AnimationStatus.completed) {
          _controller.reverse();
        }
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E24).withOpacity(0.95),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: AppTheme.accentPink.withOpacity(0.4 + (_controller.value * 0.6)),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentPink.withOpacity(0.3 * _controller.value),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: _controller.value,
                        strokeWidth: 3.5,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentPink),
                      ),
                      const Icon(
                        Icons.lock_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _controller.value > 0
                      ? 'Desbloqueando (${(3 - (_controller.value * 3)).toStringAsFixed(1)}s)...'
                      : 'Mantén pulsado 3s para desbloquear',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Modal: Todas las Playlists (Catálogo Dual: Recomendadas + Personales) ────

void _openAllPlaylistsModal(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => const _AllPlaylistsModalContent(),
  );
}

class _AllPlaylistsModalContent extends ConsumerStatefulWidget {
  const _AllPlaylistsModalContent();

  @override
  ConsumerState<_AllPlaylistsModalContent> createState() =>
      _AllPlaylistsModalContentState();
}

class _AllPlaylistsModalContentState
    extends ConsumerState<_AllPlaylistsModalContent> {
  int _activeCategoryIndex = 0; // 0: Recomendadas, 1: Mis Playlists

  @override
  Widget build(BuildContext context) {
    final userPlaylists = ref.watch(userPlaylistsProvider);
    final featuredPlaylists = ref.watch(featuredPlaylistsProvider);
    final selected = ref.watch(selectedPlaylistProvider);
    final isLoading = ref.watch(isPlaylistLoadingProvider);

    final displayList = _activeCategoryIndex == 0 ? featuredPlaylists : userPlaylists;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Explorador de Catálogo',
                    style: TextStyle(
                      color: AppTheme.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    '${displayList.length} listas en ${_activeCategoryIndex == 0 ? "Recomendadas" : "Mis Playlists"} • Audio HQ 320k',
                    style: const TextStyle(
                      color: AppTheme.onSurfaceSub,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (isLoading)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppTheme.accentViolet,
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: AppTheme.accentViolet, size: 24),
                  tooltip: 'Actualizar listas',
                  onPressed: () {
                    ref.read(userPlaylistsProvider.notifier).fetchUserPlaylists();
                    ref.read(featuredPlaylistsProvider.notifier).fetchFeaturedPlaylists();
                  },
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Segmented Category Tabs: [✨ Recomendadas] | [👤 Mis Playlists]
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _activeCategoryIndex = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _activeCategoryIndex == 0 ? AppTheme.accentViolet : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '✨ Recomendadas (${featuredPlaylists.length})',
                          style: TextStyle(
                            color: _activeCategoryIndex == 0 ? Colors.white : AppTheme.onSurfaceSub,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _activeCategoryIndex = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _activeCategoryIndex == 1 ? AppTheme.accentPink : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '👤 Mis Playlists (${userPlaylists.length})',
                          style: TextStyle(
                            color: _activeCategoryIndex == 1 ? Colors.white : AppTheme.onSurfaceSub,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 8),

          if (displayList.isEmpty && _activeCategoryIndex == 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.library_music_rounded, color: AppTheme.accentPink, size: 42),
                    const SizedBox(height: 12),
                    const Text(
                      'No se encontraron playlists en tu cuenta',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Inicia sesión con tu portal oficial en Ajustes para sincronizar automáticamente tu biblioteca.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.onSurfaceSub, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        AuthWebViewScreen.open(context, ref, 'Deezer');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentPink,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.login_rounded, size: 16),
                      label: const Text('Conectar Servicio', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
            )
          else if (displayList.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'Cargando catálogo…',
                  style: TextStyle(color: AppTheme.onSurfaceSub, fontSize: 13),
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: displayList.length,
                separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 10),
                itemBuilder: (context, index) {
                  final pl = displayList[index];
                  final isSelected = selected?.id == pl.id;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        pl.coverUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 50,
                          height: 50,
                          color: AppTheme.surfaceLight,
                          child: const Icon(Icons.album_rounded, color: AppTheme.accentViolet, size: 28),
                        ),
                      ),
                    ),
                    title: Text(
                      pl.name,
                      style: TextStyle(
                        color: isSelected ? AppTheme.accentPink : Colors.white,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          PlaylistSourceBadge(source: pl.source),
                          const SizedBox(width: 8),
                          Text(
                            '${pl.trackCount} canciones',
                            style: const TextStyle(color: AppTheme.onSurfaceSub, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded, color: AppTheme.accentPink, size: 24)
                        : const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.onSurfaceSub, size: 16),
                    onTap: () async {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          duration: const Duration(seconds: 1),
                          backgroundColor: const Color(0xFF1E293B),
                          content: Text('Cargando catálogo completo de "${pl.name}"...'),
                        ),
                      );
                      await ref.read(userPlaylistsProvider.notifier).selectPlaylist(
                        pl,
                        autoPlay: false,
                        switchToLibrary: true,
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Tab 0: Inicio ────────────────────────────────────────────────────────────

class _HomeTab extends ConsumerWidget {
  const _HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userPlaylists     = ref.watch(userPlaylistsProvider);
    final featuredPlaylists = ref.watch(featuredPlaylistsProvider);
    final services          = ref.watch(servicesProvider);
    final discovery         = ref.watch(discoveryServiceProvider);
    final audioNotifier     = ref.read(audioServiceProvider.notifier);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 100)),

        // Playlists Recomendadas & Tendencias
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recomendadas y Charts',
                    style: Theme.of(context).textTheme.titleLarge),
                TextButton(
                  onPressed: () => _openAllPlaylistsModal(context, ref),
                  child: const Text('Ver catálogo',
                      style: TextStyle(color: AppTheme.accentViolet)),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 100.ms),
        ),
        SliverToBoxAdapter(
          child: PlaylistCarousel(
            playlists: featuredPlaylists.isNotEmpty ? featuredPlaylists : userPlaylists,
          ).animate().fadeIn(delay: 150.ms),
        ),

        // Mis Playlists (si el usuario tiene listas personales)
        if (userPlaylists.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Tus Playlists',
                      style: Theme.of(context).textTheme.titleLarge),
                  TextButton(
                    onPressed: () => _openAllPlaylistsModal(context, ref),
                    child: const Text('Ver todas',
                        style: TextStyle(color: AppTheme.accentPink)),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 180.ms),
          ),
          SliverToBoxAdapter(
            child: PlaylistCarousel(playlists: userPlaylists)
                .animate()
                .fadeIn(delay: 200.ms),
          ),
        ],

        // Servicios Conectados
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
            child: Text('Servicios Conectados',
                    style: Theme.of(context).textTheme.titleLarge)
                .animate()
                .fadeIn(delay: 220.ms),
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

  static String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists       = ref.watch(userPlaylistsProvider);
    final featuredPlaylists = ref.watch(featuredPlaylistsProvider);
    final selectedPlaylist= ref.watch(selectedPlaylistProvider);
    final isLoading       = ref.watch(isPlaylistLoadingProvider);
    final tracks          = ref.watch(recentTracksProvider);
    final audioState      = ref.watch(audioServiceProvider);
    final audioNotifier   = ref.read(audioServiceProvider.notifier);

    final activePlaylist  = selectedPlaylist ??
        (playlists.isNotEmpty
            ? playlists.first
            : (featuredPlaylists.isNotEmpty ? featuredPlaylists.first : null));

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 110)),

        // Encabezado principal
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
                      isLoading
                          ? 'Descargando canciones de la lista…'
                          : '${tracks.length} canciones cargadas • Acceso Premium HQ',
                      style: const TextStyle(color: AppTheme.onSurfaceSub, fontSize: 13),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: 'Sincronizar canciones',
                  icon: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentViolet),
                        )
                      : const Icon(Icons.sync_rounded, color: AppTheme.accentViolet),
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (activePlaylist != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: const Color(0xFF1E293B),
                                content: Text('Sincronizando catálogo completo de "${activePlaylist.name}"...'),
                              ),
                            );
                            await ref.read(userPlaylistsProvider.notifier).selectPlaylist(
                              activePlaylist,
                              autoPlay: false,
                              switchToLibrary: false,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: const Color(0xFF1E293B),
                                  content: Text('Sincronizadas ${ref.read(recentTracksProvider).length} canciones con éxito.'),
                                ),
                              );
                            }
                          } else {
                            await ref.read(userPlaylistsProvider.notifier).fetchUserPlaylists();
                          }
                        },
                ),
              ],
            ),
          ),
        ),

        // Banner Playlist Activa
        if (activePlaylist != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF2E1065).withOpacity(0.85),
                      const Color(0xFF0F172A).withOpacity(0.95),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AppTheme.accentViolet.withOpacity(0.35),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            activePlaylist.coverUrl,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 80,
                              height: 80,
                              color: AppTheme.surfaceLight,
                              child: const Icon(Icons.album_rounded, color: AppTheme.accentPink, size: 36),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentPink.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.accentPink.withOpacity(0.4)),
                                ),
                                child: Text(
                                  'STREAMING OFICIAL ${activePlaylist.source.toUpperCase()} • HQ 320K',
                                  style: const TextStyle(
                                    color: AppTheme.accentPink,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                activePlaylist.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isLoading
                                    ? 'Cargando pistas…'
                                    : '${tracks.length} Pistas completas sin interrupciones',
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
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentViolet,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.play_arrow_rounded, size: 22),
                            label: const Text('Reproducir Todo', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            onPressed: () {
                              if (tracks.isNotEmpty) {
                                audioNotifier.playTrack(tracks.first);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(color: audioState.isShuffle ? AppTheme.accentPink : Colors.white24),
                              backgroundColor: audioState.isShuffle ? AppTheme.accentPink.withOpacity(0.15) : null,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: Icon(
                              Icons.shuffle_rounded,
                              size: 20,
                              color: audioState.isShuffle ? AppTheme.accentPink : Colors.white,
                            ),
                            label: Text(
                              audioState.isShuffle ? 'Aleatorio ON' : 'Aleatorio',
                              style: TextStyle(
                                color: audioState.isShuffle ? AppTheme.accentPink : Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            onPressed: () {
                              if (!audioState.isShuffle) {
                                audioNotifier.toggleShuffle();
                              }
                              audioNotifier.skipToNext();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Subtítulo de la lista
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Canciones (${tracks.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF065F46).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.high_quality_rounded, size: 14, color: Color(0xFF10B981)),
                      SizedBox(width: 4),
                      Text('320 KBPS HQ', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Lista vertical estilizada de las pistas
        if (isLoading)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(color: AppTheme.accentViolet),
                    const SizedBox(height: 16),
                    Text(
                      activePlaylist != null
                          ? 'Descargando canciones de "${activePlaylist.name}"...'
                          : 'Cargando playlist...',
                      style: const TextStyle(color: AppTheme.onSurfaceSub, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (tracks.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.queue_music_rounded, color: AppTheme.onSurfaceSub, size: 48),
                    SizedBox(height: 16),
                    Text(
                      'No hay canciones disponibles en esta playlist.',
                      style: TextStyle(color: AppTheme.onSurfaceSub, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final track = tracks[i];
                final isCurrent = audioState.currentTrack?.id == track.id;
                final isPlaying = isCurrent && audioState.isPlaying;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => audioNotifier.playTrack(track),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? AppTheme.accentViolet.withOpacity(0.18)
                              : AppTheme.surfaceLight.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isCurrent
                                ? AppTheme.accentViolet.withOpacity(0.5)
                                : Colors.white.withOpacity(0.04),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Número de pista
                            SizedBox(
                              width: 32,
                              child: Text(
                                '#${i + 1}',
                                style: TextStyle(
                                  color: isCurrent ? AppTheme.accentPink : AppTheme.onSurfaceSub,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Carátula
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                track.albumArt,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 44,
                                  height: 44,
                                  color: AppTheme.surface,
                                  child: const Icon(Icons.music_note, color: AppTheme.accentViolet, size: 20),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Título, Artista y Duración
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    track.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isCurrent ? AppTheme.accentPink : Colors.white,
                                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          track.artist,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppTheme.onSurfaceSub,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        _formatDuration(track.durationSeconds),
                                        style: const TextStyle(
                                          color: AppTheme.onSurfaceSub,
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          '320k',
                                          style: TextStyle(
                                            color: Color(0xFF10B981),
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Botón de reproducción directa
                            IconButton(
                              icon: Icon(
                                isPlaying
                                    ? Icons.pause_circle_filled_rounded
                                    : Icons.play_circle_filled_rounded,
                                color: isCurrent ? AppTheme.accentPink : AppTheme.accentViolet,
                                size: 32,
                              ),
                              onPressed: () {
                                if (isCurrent) {
                                  audioNotifier.togglePlayPause();
                                } else {
                                  audioNotifier.playTrack(track);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
              childCount: tracks.length,
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
                  title: const Text('Iniciar Sesión Deezer Premium', style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text('OAuth2 / Credenciales y audio HQ 320 kbps', style: TextStyle(color: AppTheme.onSurfaceSub, fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54),
                  onTap: () => ServicesGrid.openAuthModal(context, ref, 'Deezer'),
                ),
                const SizedBox(height: 10),
                ListTile(
                  tileColor: AppTheme.surfaceLight,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: const Text('🎶', style: TextStyle(fontSize: 24)),
                  title: const Text('Iniciar Sesión Amazon Music', style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text('Credenciales de streaming cifradas en Hardware Keystore', style: TextStyle(color: AppTheme.onSurfaceSub, fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54),
                  onTap: () => ServicesGrid.openAuthModal(context, ref, 'Amazon Music'),
                ),
                const SizedBox(height: 10),
                ListTile(
                  tileColor: AppTheme.surfaceLight,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: const Text('🟢', style: TextStyle(fontSize: 24)),
                  title: const Text('Iniciar Sesión Spotify Premium', style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text('Streaming comercial y playlists en la nube', style: TextStyle(color: AppTheme.onSurfaceSub, fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54),
                  onTap: () => ServicesGrid.openAuthModal(context, ref, 'Spotify'),
                ),
                const SizedBox(height: 10),
                ListTile(
                  tileColor: AppTheme.surfaceLight,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: const Text('⬛', style: TextStyle(fontSize: 24)),
                  title: const Text('Iniciar Sesión Tidal HiFi', style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text('Streaming Lossless Master Audio a 320+ kbps', style: TextStyle(color: AppTheme.onSurfaceSub, fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54),
                  onTap: () => ServicesGrid.openAuthModal(context, ref, 'Tidal'),
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
