// lib/widgets/now_playing_bar.dart
// Persistent "Now Playing" bottom panel with:
//   • Rotating album art (AnimationController)
//   • Glassmorphism background
//   • Play/Pause controls
//   • Audio output mode indicator

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:bella_music/services/audio_service.dart';
import 'package:bella_music/services/discovery_service.dart';
import 'package:bella_music/models/audio_output_mode.dart';
import 'package:bella_music/theme/app_theme.dart';

class NowPlayingBar extends ConsumerStatefulWidget {
  const NowPlayingBar({super.key});

  @override
  ConsumerState<NowPlayingBar> createState() => _NowPlayingBarState();
}

class _NowPlayingBarState extends ConsumerState<NowPlayingBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationCtrl;

  @override
  void initState() {
    super.initState();
    _rotationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audioState   = ref.watch(audioServiceProvider);
    final discovery    = ref.watch(discoveryServiceProvider);
    final audioNotifier = ref.read(audioServiceProvider.notifier);

    final track = audioState.currentTrack;
    if (track == null) return const SizedBox.shrink();

    // Pause rotation when not playing
    if (audioState.isPlaying) {
      _rotationCtrl.forward();
    } else {
      _rotationCtrl.stop();
    }

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface.withOpacity(0.88),
            border: Border(
              top: BorderSide(
                color: AppTheme.accentViolet.withOpacity(0.25),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // ── Rotating album art ──────────────────────────────
                      AnimatedBuilder(
                        animation: _rotationCtrl,
                        builder: (_, child) => Transform.rotate(
                          angle: _rotationCtrl.value * 2 * math.pi,
                          child: child,
                        ),
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.accentViolet.withOpacity(0.6),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.accentViolet.withOpacity(0.4),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: track.albumArt,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                color: AppTheme.surface,
                                child: const Icon(Icons.music_note,
                                    color: AppTheme.accentViolet),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // ── Track info ──────────────────────────────────────
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              style: const TextStyle(
                                color: AppTheme.onSurface,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              track.artist,
                              style: const TextStyle(
                                color: AppTheme.onSurfaceSub,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _AudioOutputBadge(mode: discovery.mode),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // ── Controls ────────────────────────────────────────
                      IconButton(
                        icon: const Icon(Icons.skip_previous_rounded),
                        color: AppTheme.onSurface,
                        onPressed: () {},
                      ),
                      _PlayPauseButton(
                        isPlaying: audioState.isPlaying,
                        onTap: audioNotifier.togglePlayPause,
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next_rounded),
                        color: AppTheme.onSurface,
                        onPressed: () {},
                      ),
                    ],
                  ),

                  // ── Progress bar ──────────────────────────────────────────
                  const SizedBox(height: 8),
                  _ProgressBar(
                    position: audioState.positionSeconds,
                    duration: audioState.durationSeconds,
                    onSeek: audioNotifier.seekTo,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({required this.isPlaying, required this.onTap});
  final bool isPlaying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppTheme.accentGradient,
        ),
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.position,
    required this.duration,
    required this.onSeek,
  });
  final int position;
  final int duration;
  final void Function(int) onSeek;

  @override
  Widget build(BuildContext context) {
    final progress = duration > 0 ? position / duration : 0.0;
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        activeTrackColor: AppTheme.accentViolet,
        inactiveTrackColor: AppTheme.surfaceLight,
        thumbColor: AppTheme.accentBlue,
      ),
      child: Slider(
        value: progress.clamp(0.0, 1.0),
        onChanged: (v) => onSeek((v * duration).round()),
      ),
    );
  }
}

class _AudioOutputBadge extends StatelessWidget {
  const _AudioOutputBadge({required this.mode});
  final AudioOutputMode mode;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (mode) {
      AudioOutputMode.wifiSpeaker   => (AppTheme.accentBlue, Icons.speaker_rounded),
      AudioOutputMode.localFallback => (AppTheme.accentViolet, Icons.smartphone_rounded),
      AudioOutputMode.searching     => (AppTheme.onSurfaceSub, Icons.search_rounded),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(
          mode.label,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
