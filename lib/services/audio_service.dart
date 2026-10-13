// lib/services/audio_service.dart
//
// Unified audio controller:
//   • Wi-Fi mode  → routes commands to UpnpService (DLNA/Linkplay)
//   • Local mode  → drives just_audio for on-device playback
//
// All processing is async/await — never blocks the UI thread.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:bella_music/models/audio_output_mode.dart';
import 'package:bella_music/models/playlist_model.dart';
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
    // Configure AudioSession for music (handles calls / BT routing)
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
  }

  // ─── Play a track (routes based on current output mode) ───────────────────

  Future<void> playTrack(Track track) async {
    state = state.copyWith(currentTrack: track);
    final discovery = _ref.read(discoveryServiceProvider);

    if (discovery.mode == AudioOutputMode.wifiSpeaker &&
        discovery.speakerIp != null &&
        NetworkValidator.isPrivateIp(discovery.speakerIp!)) {
      // ── Wi-Fi Speaker mode ────────────────────────────────────────────────
      _logger.i('Audio: Routing to Wi-Fi speaker ${discovery.speakerIp}');
      await _localPlayer.stop(); // stop local if anything was playing
      final ok = await UpnpService.instance.setAvTransportUri(
        speakerIp: discovery.speakerIp!,
        port: 49152,
        streamUrl: track.streamUrl,
      );
      if (ok) {
        await UpnpService.instance.play(discovery.speakerIp!);
        state = state.copyWith(isPlaying: true);
      } else {
        _logger.w('Audio: Wi-Fi routing failed — falling back to local.');
        await _playLocal(track);
      }
    } else {
      // ── Local Fallback mode ───────────────────────────────────────────────
      _logger.i('Audio: Playing locally on device.');
      await _playLocal(track);
    }
  }

  Future<void> _playLocal(Track track) async {
    try {
      await _localPlayer.setUrl(track.streamUrl);
      await _localPlayer.play();
      state = state.copyWith(isPlaying: true);
    } catch (e) {
      _logger.e('Local playback error: $e');
    }
  }

  // ─── Controls ─────────────────────────────────────────────────────────────

  Future<void> pause() async {
    final discovery = _ref.read(discoveryServiceProvider);
    if (discovery.mode == AudioOutputMode.wifiSpeaker &&
        discovery.speakerIp != null) {
      await UpnpService.instance.pause(discovery.speakerIp!);
      state = state.copyWith(isPlaying: false);
    } else {
      await _localPlayer.pause();
    }
  }

  Future<void> resume() async {
    final discovery = _ref.read(discoveryServiceProvider);
    if (discovery.mode == AudioOutputMode.wifiSpeaker &&
        discovery.speakerIp != null) {
      await UpnpService.instance.play(discovery.speakerIp!);
      state = state.copyWith(isPlaying: true);
    } else {
      await _localPlayer.play();
    }
  }

  Future<void> togglePlayPause() async {
    state.isPlaying ? await pause() : await resume();
  }

  Future<void> seekTo(int seconds) async {
    await _localPlayer.seek(Duration(seconds: seconds));
  }

  Future<void> setVolume(double v) async {
    await _localPlayer.setVolume(v);
    state = state.copyWith(volume: v);
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
