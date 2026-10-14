// lib/services/audio_service.dart
// Unified audio controller with reactive StateNotifier and AudioHandler:
//   • Wi-Fi mode  → Linkplay A31 HTTP (port 80) / UPnP SOAP with remote volume button mapping
//   • Local mode  → just_audio with high-fidelity (320 kbps) stream headers & AudioSession
//   • Background Lockscreen  → persistent MediaSessionCompat and PlaybackState
//   • Heartbeat & Auto-reconnect  → silent SSDP recovery on DHCP change
//   • Dynamic Gain Normalization  → setPlayerCmd:Equalizer:gain
//   • Emergency Offline Fallback  → local lounge buffer during WAN outage

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';
import 'package:bella_music/models/audio_output_mode.dart';
import 'package:bella_music/models/playlist_model.dart';
import 'package:bella_music/providers/playlist_provider.dart';
import 'package:bella_music/providers/audio_routing_provider.dart';
import 'package:bella_music/services/upnp_service.dart';
import 'package:bella_music/services/discovery_service.dart';
import 'package:bella_music/services/linkplay_bridge_service.dart';
import 'package:bella_music/services/emergency_audio_service.dart';
import 'package:bella_music/services/secure_storage_service.dart';
import 'package:bella_music/utils/network_validator.dart';
import 'package:logger/logger.dart';

// ─── Repeat Mode Enum ─────────────────────────────────────────────────────────

enum AudioRepeatMode { off, all, one }

// ─── State ────────────────────────────────────────────────────────────────────

class AudioState {
  const AudioState({
    this.currentTrack,
    this.isPlaying = false,
    this.positionSeconds = 0,
    this.durationSeconds = 0,
    this.volume = 0.8,
    this.isShuffle = false,
    this.repeatMode = AudioRepeatMode.off,
  });

  final Track? currentTrack;
  final bool isPlaying;
  final int positionSeconds;
  final int durationSeconds;
  final double volume;
  final bool isShuffle;
  final AudioRepeatMode repeatMode;

  AudioState copyWith({
    Track? currentTrack,
    bool? isPlaying,
    int? positionSeconds,
    int? durationSeconds,
    double? volume,
    bool? isShuffle,
    AudioRepeatMode? repeatMode,
  }) =>
      AudioState(
        currentTrack: currentTrack ?? this.currentTrack,
        isPlaying: isPlaying ?? this.isPlaying,
        positionSeconds: positionSeconds ?? this.positionSeconds,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        volume: volume ?? this.volume,
        isShuffle: isShuffle ?? this.isShuffle,
        repeatMode: repeatMode ?? this.repeatMode,
      );
}

// ─── System AudioHandler Implementation ───────────────────────────────────────

class BellaAudioHandler extends BaseAudioHandler with SeekHandler {
  static BellaAudioHandler? instance;
  AudioNotifier? _notifier;
  String? _speakerIp;
  bool _isWifiMode = false;

  final _logger = Logger(printer: PrettyPrinter(methodCount: 0));

  BellaAudioHandler() {
    instance = this;
    _setLocalAudioSession();
  }

  void attachNotifier(AudioNotifier notifier) {
    _notifier = notifier;
  }

  void setRemoteWifiMode(String? speakerIp) {
    _speakerIp = speakerIp;
    _isWifiMode = speakerIp != null;
    if (_isWifiMode) {
      androidPlaybackInfo.add(
        RemoteAndroidPlaybackInfo(
          volumeControlType: AndroidVolumeControlType.relative,
          maxVolume: 100,
          volume: 50,
        ),
      );
      _logger.i('AudioHandler: Modo Wi-Fi activado con proveedor de volumen remoto (AndroidVolumeControlType.relative).');
    } else {
      _setLocalAudioSession();
    }
  }

  void setLocalMode() {
    _speakerIp = null;
    _isWifiMode = false;
    _setLocalAudioSession();
  }

  void _setLocalAudioSession() {
    androidPlaybackInfo.add(LocalAndroidPlaybackInfo());
  }

  // ─── Hardware Volume Buttons Interception (Physical Xiaomi Buttons) ──────────

  @override
  Future<void> androidAdjustRemoteVolume(AndroidVolumeDirection direction) async {
    if (_isWifiMode && _speakerIp != null) {
      if (direction == AndroidVolumeDirection.raise) {
        _logger.i('AudioHandler: Botón físico VOL+ interceptado → Despachando vol:+2 a WCS50.');
        await LinkplayBridgeService.instance.volumeUp(_speakerIp!, step: 2);
      } else if (direction == AndroidVolumeDirection.lower) {
        _logger.i('AudioHandler: Botón físico VOL- interceptado → Despachando vol:-2 a WCS50.');
        await LinkplayBridgeService.instance.volumeDown(_speakerIp!, step: 2);
      }
    } else {
      await super.androidAdjustRemoteVolume(direction);
    }
  }

  // ─── Lockscreen & Notification Controls ─────────────────────────────────────

  @override
  Future<void> play() async {
    if (_notifier != null) await _notifier!.resume();
  }

  @override
  Future<void> pause() async {
    if (_notifier != null) await _notifier!.pause();
  }

  @override
  Future<void> skipToNext() async {
    if (_notifier != null) await _notifier!.skipToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    if (_notifier != null) await _notifier!.skipToPrevious();
  }

  @override
  Future<void> seek(Duration position) async {
    if (_notifier != null) await _notifier!.seekTo(position.inSeconds);
  }

  @override
  Future<void> setVolume(double volume) async {
    if (_notifier != null) await _notifier!.setVolume(volume);
  }

  // ─── State & Metadata Synchronization ───────────────────────────────────────

  void updateTrackMetadata(Track track) {
    mediaItem.add(
      MediaItem(
        id: track.id,
        album: track.source.toUpperCase(),
        title: track.title,
        artist: track.artist,
        duration: Duration(seconds: track.durationSeconds),
        artUri: Uri.tryParse(track.albumArt),
      ),
    );
  }

  void updatePlaybackStatus({
    required bool isPlaying,
    required int positionSeconds,
    required int durationSeconds,
  }) {
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: AudioProcessingState.ready,
        playing: isPlaying,
        updatePosition: Duration(seconds: positionSeconds),
        bufferedPosition: Duration(seconds: durationSeconds),
        speed: 1.0,
      ),
    );
  }
}

// ─── Audio Notifier ───────────────────────────────────────────────────────────

class AudioNotifier extends StateNotifier<AudioState> {
  AudioNotifier(this._ref) : super(const AudioState()) {
    _initLocalPlayer();
    BellaAudioHandler.instance?.attachNotifier(this);
  }

  final Ref _ref;
  final _logger = Logger(printer: PrettyPrinter(methodCount: 0));
  final AudioPlayer _localPlayer = AudioPlayer();
  Timer? _remotePollingTimer;
  int _consecutivePollingFailures = 0;
  String? _activeSpeakerIp;

  Future<void> _initLocalPlayer() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.none,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ));

      _localPlayer.positionStream.listen((pos) {
        state = state.copyWith(positionSeconds: pos.inSeconds);
        BellaAudioHandler.instance?.updatePlaybackStatus(
          isPlaying: state.isPlaying,
          positionSeconds: pos.inSeconds,
          durationSeconds: state.durationSeconds,
        );
      });

      _localPlayer.durationStream.listen((dur) {
        if (dur != null) {
          state = state.copyWith(durationSeconds: dur.inSeconds);
          BellaAudioHandler.instance?.updatePlaybackStatus(
            isPlaying: state.isPlaying,
            positionSeconds: state.positionSeconds,
            durationSeconds: dur.inSeconds,
          );
        }
      });

      _localPlayer.playingStream.listen((playing) {
        state = state.copyWith(isPlaying: playing);
        BellaAudioHandler.instance?.updatePlaybackStatus(
          isPlaying: playing,
          positionSeconds: state.positionSeconds,
          durationSeconds: state.durationSeconds,
        );
      });

      // Ciclo de vida y auto-avance local/Bluetooth
      _localPlayer.playerStateStream.listen((playerState) {
        if (playerState.processingState == ProcessingState.completed) {
          if (state.repeatMode == AudioRepeatMode.one) {
            seekTo(0);
            resume();
          } else {
            skipToNext();
          }
        }
      });

      final initial = _ref.read(currentTrackProvider);
      if (initial != null) {
        state = state.copyWith(
          currentTrack: initial,
          durationSeconds: initial.durationSeconds,
        );
        BellaAudioHandler.instance?.updateTrackMetadata(initial);
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

    // Actualiza metadatos y estado en la sesión del sistema (pantalla de bloqueo)
    BellaAudioHandler.instance?.updateTrackMetadata(track);
    BellaAudioHandler.instance?.updatePlaybackStatus(
      isPlaying: true,
      positionSeconds: 0,
      durationSeconds: track.durationSeconds,
    );

    final discovery = _ref.read(discoveryServiceProvider);

    if (discovery.mode == AudioOutputMode.wifiSpeaker &&
        discovery.speakerIp != null &&
        NetworkValidator.isPrivateIp(discovery.speakerIp!)) {
      _activeSpeakerIp = discovery.speakerIp!;
      _consecutivePollingFailures = 0;

      _logger.i('Audio Wi-Fi: Despachando a altavoz Power Dynamics WCS50 ($_activeSpeakerIp) en modo Controller');

      // MÓVIL COMO MANDO A DISTANCIA EXCLUSIVO:
      // Se detiene el reproductor local del teléfono para que llamadas, notas de voz o vídeos
      // no interfieran con el altavoz ni pausen la transmisión de red del WCS50.
      await _localPlayer.stop();

      // Configura la sesión multimedia del sistema con proveedor de volumen remoto (Xiaomi buttons)
      BellaAudioHandler.instance?.setRemoteWifiMode(_activeSpeakerIp);

      // Normalización de Ganancia Dinámica (Requisito F)
      if (track.gainDb != 0.0) {
        await LinkplayBridgeService.instance.setEqualizerGain(_activeSpeakerIp!, track.gainDb);
      }

      final ok = await UpnpService.instance.playOnLinkplayOrUpnp(
        speakerIp: _activeSpeakerIp!,
        streamUrl: track.streamUrl,
      );

      if (ok) {
        state = state.copyWith(isPlaying: true);
        BellaAudioHandler.instance?.updatePlaybackStatus(
          isPlaying: true,
          positionSeconds: 0,
          durationSeconds: track.durationSeconds,
        );
        _startRemotePolling(_activeSpeakerIp!);
      } else {
        _logger.w('Audio Wi-Fi: Falló enlace con altavoz — recurriendo a reproducción local.');
        _stopRemotePolling();
        BellaAudioHandler.instance?.setLocalMode();
        await _playLocal(track);
      }
    } else {
      _logger.i('Audio: Modo Local / Bluetooth activo en dispositivo móvil.');
      _stopRemotePolling();
      BellaAudioHandler.instance?.setLocalMode();
      await _playLocal(track);
    }
  }

  // ─── Polling de Estado para Altavoz Wi-Fi (Auto-Advance & Heartbeat) ────────

  void _startRemotePolling(String speakerIp) {
    _stopRemotePolling();
    _activeSpeakerIp = speakerIp;
    _consecutivePollingFailures = 0;

    _remotePollingTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!state.isPlaying || _activeSpeakerIp == null) return;
      try {
        final remote = await LinkplayBridgeService.instance.getPlayerStatus(_activeSpeakerIp!);
        if (remote != null) {
          _consecutivePollingFailures = 0;

          state = state.copyWith(
            positionSeconds: remote.currentPositionSeconds,
            durationSeconds: remote.totalDurationSeconds > 0
                ? remote.totalDurationSeconds
                : state.durationSeconds,
          );

          // Sincroniza posición en la barra de reproducción de la pantalla de bloqueo
          BellaAudioHandler.instance?.updatePlaybackStatus(
            isPlaying: state.isPlaying,
            positionSeconds: remote.currentPositionSeconds,
            durationSeconds: remote.totalDurationSeconds > 0
                ? remote.totalDurationSeconds
                : state.durationSeconds,
          );

          // Transición automática al detectar que la canción finalizó en el altavoz
          if (remote.isStopped || remote.isNearEnd) {
            _logger.i('Audio Wi-Fi Auto-Advance: Canción finalizada en WCS50 (${remote.status}) → Siguiente pista');
            _stopRemotePolling();
            await skipToNext();
          }
        } else {
          // Fallo de sondeo (socket error o timeout)
          _handlePollingFailure();
        }
      } catch (e) {
        _handlePollingFailure();
      }
    });
  }

  void _handlePollingFailure() async {
    _consecutivePollingFailures++;
    if (_consecutivePollingFailures >= 3) {
      _consecutivePollingFailures = 0;
      _logger.w('Heartbeat: 3 fallos consecutivos con WCS50 en $_activeSpeakerIp → Disparando auto-reconexión silenciosa...');

      // Heartbeat y Auto-Reconexión Silenciosa de Red (Requisito C)
      final newIp = await _ref.read(discoveryServiceProvider.notifier).reconnectSilently();
      if (newIp != null && NetworkValidator.isPrivateIp(newIp)) {
        _logger.i('Heartbeat: WCS50 detectado en nueva IP: $newIp. Actualizando polling en caliente.');
        _activeSpeakerIp = newIp;
        _ref.read(audioRoutingProvider.notifier).updateActiveSpeakerIp(newIp);
        BellaAudioHandler.instance?.setRemoteWifiMode(newIp);
      }
    }
  }

  void _stopRemotePolling() {
    _remotePollingTimer?.cancel();
    _remotePollingTimer = null;
  }

  Future<void> _playLocal(Track track) async {
    try {
      await _localPlayer.stop();

      final token = await SecureStorageService.instance.getDeezerToken();
      final headers = <String, String>{
        'User-Agent': 'Mozilla/5.0 (Android; Mobile; rv:109.0) Gecko/119.0 Firefox/119.0',
        'Accept': 'audio/mpeg, audio/*; q=0.9, */*; q=0.1',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        if (token != null && token.isNotEmpty) 'X-Deezer-Token': token,
      };

      final source = AudioSource.uri(
        Uri.parse(track.streamUrl),
        headers: headers,
      );

      await _localPlayer.setAudioSource(source);
      await _localPlayer.play();
      state = state.copyWith(isPlaying: true);

      BellaAudioHandler.instance?.updatePlaybackStatus(
        isPlaying: true,
        positionSeconds: 0,
        durationSeconds: track.durationSeconds,
      );
    } catch (e) {
      _logger.e('Error de reproducción local ($e) → Conmutando a búfer de emergencia offline.');
      // Búfer de Emergencia Offline (Requisito E)
      _ref.read(emergencyModeProvider.notifier).state = true;
      final emergency = EmergencyAudioService.instance.emergencyTracks;
      if (emergency.isNotEmpty && track.id != emergency.first.id) {
        await _playEmergencyOffline(emergency.first);
      } else {
        state = state.copyWith(isPlaying: true);
      }
    }
  }

  Future<void> _playEmergencyOffline(Track fallbackTrack) async {
    try {
      state = state.copyWith(
        currentTrack: fallbackTrack,
        isPlaying: true,
        durationSeconds: fallbackTrack.durationSeconds,
      );
      _ref.read(currentTrackProvider.notifier).state = fallbackTrack;
      BellaAudioHandler.instance?.updateTrackMetadata(fallbackTrack);

      final source = AudioSource.uri(Uri.parse(fallbackTrack.streamUrl));
      await _localPlayer.setAudioSource(source);
      await _localPlayer.play();
    } catch (_) {
      state = state.copyWith(isPlaying: true);
    }
  }

  // ─── Play / Pause ──────────────────────────────────────────────────────────

  Future<void> pause() async {
    state = state.copyWith(isPlaying: false);
    _stopRemotePolling();

    BellaAudioHandler.instance?.updatePlaybackStatus(
      isPlaying: false,
      positionSeconds: state.positionSeconds,
      durationSeconds: state.durationSeconds,
    );

    final discovery = _ref.read(discoveryServiceProvider);
    if (discovery.mode == AudioOutputMode.wifiSpeaker && _activeSpeakerIp != null) {
      await LinkplayBridgeService.instance.pause(_activeSpeakerIp!);
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

    BellaAudioHandler.instance?.updatePlaybackStatus(
      isPlaying: true,
      positionSeconds: state.positionSeconds,
      durationSeconds: state.durationSeconds,
    );

    final discovery = _ref.read(discoveryServiceProvider);
    if (discovery.mode == AudioOutputMode.wifiSpeaker && _activeSpeakerIp != null) {
      await LinkplayBridgeService.instance.resume(_activeSpeakerIp!);
      _startRemotePolling(_activeSpeakerIp!);
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

  // ─── Shuffle & Repeat Modes ────────────────────────────────────────────────

  void toggleShuffle() {
    final newShuffle = !state.isShuffle;
    state = state.copyWith(isShuffle: newShuffle);
    _logger.i('Audio: Modo Aleatorio ${newShuffle ? "ACTIVADO" : "DESACTIVADO"}');
  }

  void toggleRepeat() {
    final nextMode = switch (state.repeatMode) {
      AudioRepeatMode.off => AudioRepeatMode.all,
      AudioRepeatMode.all => AudioRepeatMode.one,
      AudioRepeatMode.one => AudioRepeatMode.off,
    };
    state = state.copyWith(repeatMode: nextMode);
    _logger.i('Audio: Modo Repetición cambiado a $nextMode');
  }

  // ─── Skip Track (Next / Previous) ──────────────────────────────────────────

  Future<void> skipToNext() async {
    final tracks = _ref.read(recentTracksProvider);
    if (tracks.isEmpty) return;

    if (state.repeatMode == AudioRepeatMode.one) {
      await seekTo(0);
      await resume();
      return;
    }

    if (state.isShuffle) {
      final current = state.currentTrack;
      final candidates = tracks.where((t) => t.id != current?.id).toList();
      final randomTrack = candidates.isNotEmpty
          ? candidates[math.Random().nextInt(candidates.length)]
          : tracks[math.Random().nextInt(tracks.length)];
      await playTrack(randomTrack);
      return;
    }

    final current = state.currentTrack;
    int currentIndex = current != null
        ? tracks.indexWhere((t) => t.id == current.id)
        : -1;

    int nextIndex = currentIndex + 1;
    if (nextIndex >= tracks.length) {
      if (state.repeatMode == AudioRepeatMode.all) {
        nextIndex = 0;
      } else {
        await pause();
        await seekTo(0);
        return;
      }
    }
    final nextTrack = tracks[nextIndex];
    await playTrack(nextTrack);
  }

  Future<void> skipToPrevious() async {
    final tracks = _ref.read(recentTracksProvider);
    if (tracks.isEmpty) return;

    if (state.positionSeconds > 3) {
      await seekTo(0);
      return;
    }

    if (state.isShuffle) {
      final randomTrack = tracks[math.Random().nextInt(tracks.length)];
      await playTrack(randomTrack);
      return;
    }

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
    BellaAudioHandler.instance?.updatePlaybackStatus(
      isPlaying: state.isPlaying,
      positionSeconds: seconds,
      durationSeconds: state.durationSeconds,
    );
    try {
      await _localPlayer.seek(Duration(seconds: seconds));
    } catch (_) {}
  }

  Future<void> setVolume(double v) async {
    state = state.copyWith(volume: v);
    try {
      await _localPlayer.setVolume(v);
    } catch (_) {}
    if (_activeSpeakerIp != null) {
      final linkplayVol = (v * 100).round();
      await LinkplayBridgeService.instance.setVolume(_activeSpeakerIp!, linkplayVol);
    }
  }

  @override
  void dispose() {
    _stopRemotePolling();
    _localPlayer.dispose();
    super.dispose();
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final audioServiceProvider =
    StateNotifierProvider<AudioNotifier, AudioState>(
  (ref) => AudioNotifier(ref),
);
