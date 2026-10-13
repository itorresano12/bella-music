// lib/services/audio_service.dart
// Unified audio controller with reactive StateNotifier:
//   • Wi-Fi mode  → routes commands to UpnpService (DLNA/Linkplay)
//   • Local mode  → drives just_audio for on-device playback
//   • Play/Pause/Skip with real-time UI synchronisation and auto-advance

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:bella_music/models/audio_output_mode.dart';
import 'package:bella_music/models/playlist_model.dart';
import 'package:bella_music/providers/playlist_provider.dart';
import 'package:bella_music/services/upnp_service.dart';
import 'package:bella_music/services/discovery_service.dart';
import 'package:bella_music/utils/network_validator.dart';
import 'package:logger/logger.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class AudioState {
  const AudioState({
    this.currentTrack,
    this.isPlaying = false,
    this.positionSeconds = 0,
    this.durationSeconds = 0,
    this.volume = 0.8,
  });

  final Track? currentTrack;
  final bool isPlaying;
  final int positionSeconds;
  final int durationSeconds;
  final double volume;

  AudioState copyWith({
    Track? currentTrack,
    bool? isPlaying,
    int? positionSeconds,
    int? durationSeconds,
    double? volume,
  }) =>
      AudioState(
        currentTrack: currentTrack ?? this.currentTrack,
        isPlaying: isPlaying ?? this.isPlaying,
        positionSeconds: positionSeconds ?? this.positionSeconds,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        volume: volume ?? this.volume,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class AudioNotifier extends StateNotifier<AudioState> {
  AudioNotifier(this._ref) : super(const AudioState()) {
    _initLocalPlayer();
  }

  final Ref _ref;
  final _logger = Logger(printer: PrettyPrinter(methodCount: 0));
  final AudioPlayer _localPlayer = AudioPlayer();

  Future<void> _initLocalPlayer() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      _localPlayer.positionStream.listen((pos) {
        state = state.copyWith(positionSeconds: pos.inSeconds);
      });

      _localPlayer.durationStream.listen((dur) {
        if (dur != null) state = state.copyWith(durationSeconds: dur.inSeconds);
      });

      _localPlayer.playingStream.listen((playing) {
        state = state.copyWith(isPlaying: playing);
      });

      // Auto-advance to next song upon completion
      _localPlayer.playerStateStream.listen((playerState) {
        if (playerState.processingState == ProcessingState.completed) {
          skipToNext();
        }
      });

      // Set initial track from provider if available
      final initial = _ref.read(currentTrackProvider);
      if (initial != null) {
        state = state.copyWith(
          currentTrack: initial,
          durationSeconds: initial.durationSeconds,
        );
      }
    } catch (e) {
      _logger.e('Error inicializando AudioSession: $e');
    }
  }

  // ─── Play a track ──────────────────────────────────────────────────────────

  Future<void> playTrack(Track track) async {
    state = state.copyWith(
      currentTrack: track,
      isPlaying: true,
      durationSeconds: track.durationSeconds,
      positionSeconds: 0,
    );
    _ref.read(currentTrackProvider.notifier).state = track;

    final discovery = _ref.read(discoveryServiceProvider);

    if (discovery.mode == AudioOutputMode.wifiSpeaker &&
        discovery.speakerIp != null &&
        NetworkValidator.isPrivateIp(discovery.speakerIp!)) {
      _logger.i('Audio: Transmitiendo a altavoz Wi-Fi UPnP ${discovery.speakerIp}');
      await _localPlayer.stop();
      final ok = await UpnpService.instance.setAvTransportUri(
        speakerIp: discovery.speakerIp!,
        port: 49152,
        streamUrl: track.streamUrl,
      );
      if (ok) {
        await UpnpService.instance.play(discovery.speakerIp!);
        state = state.copyWith(isPlaying: true);
      } else {
        _logger.w('Audio: Falló enlace UPnP — reproduciendo localmente.');
        await _playLocal(track);
      }
    } else {
      _logger.i('Audio: Reproducción directa en dispositivo móvil.');
      await _playLocal(track);
    }
  }

  Future<void> _playLocal(Track track) async {
    try {
      await _localPlayer.stop();
      await _localPlayer.setUrl(track.streamUrl);
      await _localPlayer.play();
      state = state.copyWith(isPlaying: true);
    } catch (e) {
      _logger.e('Error de reproducción local: $e');
      // Keep UI state playing so simulated controls still respond
    }
  }

  // ─── Play / Pause ──────────────────────────────────────────────────────────

  Future<void> pause() async {
    state = state.copyWith(isPlaying: false);
    final discovery = _ref.read(discoveryServiceProvider);
    if (discovery.mode == AudioOutputMode.wifiSpeaker &&
        discovery.speakerIp != null) {
      await UpnpService.instance.pause(discovery.speakerIp!);
    } else {
      try {
        await _localPlayer.pause();
      } catch (_) {}
    }
  }

  Future<void> resume() async {
    if (state.currentTrack == null) {
      final tracks = _ref.read(recentTracksProvider);
      if (tracks.isNotEmpty) {
        await playTrack(tracks.first);
        return;
      }
    }
    state = state.copyWith(isPlaying: true);
    final discovery = _ref.read(discoveryServiceProvider);
    if (discovery.mode == AudioOutputMode.wifiSpeaker &&
        discovery.speakerIp != null) {
      await UpnpService.instance.play(discovery.speakerIp!);
    } else {
      try {
        await _localPlayer.play();
      } catch (_) {}
    }
  }

  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await pause();
    } else {
      await resume();
    }
  }

  // ─── Skip Track (Next / Previous) ──────────────────────────────────────────

  Future<void> skipToNext() async {
    final tracks = _ref.read(recentTracksProvider);
    if (tracks.isEmpty) return;

    final current = state.currentTrack;
    int currentIndex = current != null
        ? tracks.indexWhere((t) => t.id == current.id)
        : -1;

    int nextIndex = (currentIndex + 1) % tracks.length;
    final nextTrack = tracks[nextIndex];
    await playTrack(nextTrack);
  }

  Future<void> skipToPrevious() async {
    final tracks = _ref.read(recentTracksProvider);
    if (tracks.isEmpty) return;

    final current = state.currentTrack;
    int currentIndex = current != null
        ? tracks.indexWhere((t) => t.id == current.id)
        : -1;

    int prevIndex = (currentIndex - 1 + tracks.length) % tracks.length;
    final prevTrack = tracks[prevIndex];
    await playTrack(prevTrack);
  }

  Future<void> seekTo(int seconds) async {
    state = state.copyWith(positionSeconds: seconds);
    try {
      await _localPlayer.seek(Duration(seconds: seconds));
    } catch (_) {}
  }

  Future<void> setVolume(double v) async {
    state = state.copyWith(volume: v);
    try {
      await _localPlayer.setVolume(v);
    } catch (_) {}
  }

  @override
  void dispose() {
    _localPlayer.dispose();
    super.dispose();
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final audioServiceProvider =
    StateNotifierProvider<AudioNotifier, AudioState>(
  (ref) => AudioNotifier(ref),
);
