// lib/providers/playlist_provider.dart
// Reactive state management with Riverpod:
//   • Dual catalog architecture: User Personal Playlists & Recommended/Chart Playlists
//   • Eradication of mock data & real stream resolution
//   • Active navigation tab provider (0: Inicio, 1: Buscar, 2: Librería, 3: Ajustes)
//   • Dynamic connection status backed by hardware Keystore

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:bella_music/models/playlist_model.dart';
import 'package:bella_music/services/base_music_service.dart';
import 'package:bella_music/services/audio_service.dart';
import 'package:bella_music/services/secure_storage_service.dart';
import 'package:logger/logger.dart';

// ─── Selected Playlist & Loading State ────────────────────────────────────────

final selectedPlaylistProvider = StateProvider<Playlist?>((ref) => null);
final isPlaylistLoadingProvider = StateProvider<bool>((ref) => false);

// ─── User Playlists Notifier (Mis Playlists) ───────────────────────────────────

class UserPlaylistsNotifier extends StateNotifier<List<Playlist>> {
  UserPlaylistsNotifier(this._ref) : super(const []) {
    fetchUserPlaylists();
  }

  final Ref _ref;
  final _logger = Logger(printer: PrettyPrinter(methodCount: 0));

  /// Queries the active connected music service for the user's personal playlists
  Future<void> fetchUserPlaylists({String? serviceId}) async {
    _logger.i('Playlists: Consultando biblioteca personal del usuario…');
    try {
      final service = serviceId != null
          ? MusicServiceRegistry.get(serviceId)
          : await MusicServiceRegistry.getActiveService();

      final playlists = await service.getUserPlaylists();
      state = playlists;

      if (playlists.isNotEmpty) {
        _logger.i('Playlists: ${playlists.length} playlists personales cargadas de ${service.displayName}.');

        // Seleccionar automáticamente la primera lista si aún no hay ninguna activa
        if (_ref.read(selectedPlaylistProvider) == null) {
          await selectPlaylist(playlists.first, autoPlay: false, switchToLibrary: false);
        }
      } else {
        _logger.d('Playlists: Sin listas personales de usuario aún. No se cargan listas de relleno.');
      }
    } catch (e) {
      _logger.e('Error al obtener playlists de usuario: $e');
    }
  }

  /// Selects a playlist, fetches all its tracks (with full pagination),
  /// updates the playback queue and opens the Library tab.
  Future<void> selectPlaylist(
    Playlist playlist, {
    bool autoPlay = false,
    bool switchToLibrary = true,
  }) async {
    _logger.i('Playlists: Seleccionada playlist "${playlist.name}" (${playlist.trackCount} temas).');
    _ref.read(selectedPlaylistProvider.notifier).state = playlist;
    _ref.read(isPlaylistLoadingProvider.notifier).state = true;

    try {
      final service = MusicServiceRegistry.get(playlist.source);
      final tracks = await service.getPlaylistTracks(playlist.id);

      if (tracks.isNotEmpty) {
        _ref.read(recentTracksProvider.notifier).setTracks(tracks);
        _ref.read(currentTrackProvider.notifier).setTrack(tracks.first);

        if (autoPlay) {
          await _ref.read(audioServiceProvider.notifier).playTrack(tracks.first);
        }
      }
    } catch (e) {
      _logger.e('Error cargando canciones de playlist "${playlist.name}": $e');
    } finally {
      _ref.read(isPlaylistLoadingProvider.notifier).state = false;
      if (switchToLibrary) {
        _ref.read(currentTabProvider.notifier).state = 2; // Pestaña Librería
      }
    }
  }

  void setPlaylists(List<Playlist> list) {
    state = list;
    if (list.isNotEmpty && _ref.read(selectedPlaylistProvider) == null) {
      selectPlaylist(list.first, autoPlay: false, switchToLibrary: false);
    }
  }
}

final userPlaylistsProvider =
    StateNotifierProvider<UserPlaylistsNotifier, List<Playlist>>(
  (ref) => UserPlaylistsNotifier(ref),
);

// ─── Featured & Recommended Playlists Notifier ────────────────────────────────

class FeaturedPlaylistsNotifier extends StateNotifier<List<Playlist>> {
  FeaturedPlaylistsNotifier(this._ref) : super(const []);

  final Ref _ref;
  final _logger = Logger(printer: PrettyPrinter(methodCount: 0));

  Future<void> fetchFeaturedPlaylists({String? serviceId}) async {
    _logger.i('Playlists: Consultando catálogo de recomendadas bajo petición…');
    try {
      final service = serviceId != null
          ? MusicServiceRegistry.get(serviceId)
          : await MusicServiceRegistry.getActiveService();

      final playlists = await service.getFeaturedPlaylists();
      if (playlists.isNotEmpty) {
        state = playlists;
        _logger.i('Playlists: ${playlists.length} playlists recomendadas de ${service.displayName}.');
      }
    } catch (e) {
      _logger.e('Error al obtener playlists recomendadas: $e');
    }
  }

  void setPlaylists(List<Playlist> list) => state = list;
}

final featuredPlaylistsProvider =
    StateNotifierProvider<FeaturedPlaylistsNotifier, List<Playlist>>(
  (ref) => FeaturedPlaylistsNotifier(ref),
);

// Backwards-compatible alias for existing consumers
final playlistsProvider = userPlaylistsProvider;

// ─── Tracks Notifier ────────────────────────────────────────────────────────

class RecentTracksNotifier extends StateNotifier<List<Track>> {
  RecentTracksNotifier() : super(const []);

  void setTracks(List<Track> list) {
    state = list;
  }
}

final recentTracksProvider =
    StateNotifierProvider<RecentTracksNotifier, List<Track>>(
  (ref) => RecentTracksNotifier(),
);

// ─── Currently Selected Track (independent StateNotifier — not derived) ───────
// Using StateNotifier instead of a derived StateProvider prevents reactivity
// breakage when audio_service.dart sets the resolved track directly.

class CurrentTrackNotifier extends StateNotifier<Track?> {
  CurrentTrackNotifier() : super(null);

  void setTrack(Track? track) {
    state = track;
  }
}

final currentTrackProvider =
    StateNotifierProvider<CurrentTrackNotifier, Track?>(
  (ref) {
    final notifier = CurrentTrackNotifier();
    // Seed with the first track from recentTracksProvider when it loads
    ref.listen<List<Track>>(recentTracksProvider, (prev, next) {
      if (next.isNotEmpty && notifier.state == null) {
        notifier.setTrack(next.first);
      }
    });
    return notifier;
  },
);


// ─── Navigation Tab Index (0: Inicio, 1: Buscar, 2: Librería, 3: Ajustes) ──

final currentTabProvider = StateProvider<int>((ref) => 0);

// ─── Search Tab State ───────────────────────────────────────────────────────

final searchQueryProvider = StateProvider<String>((ref) => '');
final searchTracksProvider = StateProvider<List<Track>>((ref) => []);
final isSearchingProvider = StateProvider<bool>((ref) => false);

// ─── Services Notifier (Keystore-backed Connection Indicators) ───────────────

class ServicesNotifier extends StateNotifier<List<Map<String, String>>> {
  ServicesNotifier(this._ref)
      : super(const [
          {
            'name': 'Deezer',
            'icon': '🎵',
            'color': '#EF4444',
            'status': 'checking',
          },
          {
            'name': 'Amazon Music',
            'icon': '🎶',
            'color': '#F97316',
            'status': 'checking',
          },
          {
            'name': 'Spotify',
            'icon': '🟢',
            'color': '#1DB954',
            'status': 'checking',
          },
          {
            'name': 'Tidal',
            'icon': '⬛',
            'color': '#00FFFF',
            'status': 'checking',
          },
        ]) {
    _initConnectionStatus();
  }

  final Ref _ref;

  Future<void> _initConnectionStatus() async {
    final deezerToken = await SecureStorageService.instance.getDeezerToken();
    final deezerUserId = await SecureStorageService.instance.getDeezerUserId();
    final amazonToken = await SecureStorageService.instance.getAmazonToken();
    final spotifyToken = await SecureStorageService.instance.getSpotifyToken();
    final tidalToken = await SecureStorageService.instance.getTidalToken();

    final isDeezer = (deezerToken != null && deezerToken.isNotEmpty) ||
        (deezerUserId != null && deezerUserId.isNotEmpty && deezerUserId != '0');
    final isAmazon = amazonToken != null && amazonToken.isNotEmpty;
    final isSpotify = spotifyToken != null && spotifyToken.isNotEmpty;
    final isTidal = tidalToken != null && tidalToken.isNotEmpty;

    state = [
      {
        'name': 'Deezer',
        'icon': '🎵',
        'color': '#EF4444',
        'status': isDeezer ? 'connected' : 'disconnected',
      },
      {
        'name': 'Amazon Music',
        'icon': '🎶',
        'color': '#F97316',
        'status': isAmazon ? 'connected' : 'disconnected',
      },
      {
        'name': 'Spotify',
        'icon': '🟢',
        'color': '#1DB954',
        'status': isSpotify ? 'connected' : 'disconnected',
      },
      {
        'name': 'Tidal',
        'icon': '⬛',
        'color': '#00FFFF',
        'status': isTidal ? 'connected' : 'disconnected',
      },
    ];
  }

  void updateStatus(String name, String status) {
    state = [
      for (final s in state)
        if (s['name'] == name) {...s, 'status': status} else s
    ];

    if (status == 'connected') {
      _ref.read(userPlaylistsProvider.notifier).fetchUserPlaylists(serviceId: name);
    }
  }

  Future<void> disconnectService(String name) async {
    final lower = name.toLowerCase();
    if (lower.contains('deezer')) {
      await SecureStorageService.instance.clearDeezer();
    } else if (lower.contains('amazon')) {
      await SecureStorageService.instance.clearAmazon();
    } else if (lower.contains('spotify')) {
      await SecureStorageService.instance.clearSpotify();
    } else if (lower.contains('tidal')) {
      await SecureStorageService.instance.clearTidal();
    }

    try {
      final cookieManager = WebViewCookieManager();
      await cookieManager.clearCookies();
    } catch (_) {}

    updateStatus(name, 'disconnected');
    await _ref.read(userPlaylistsProvider.notifier).fetchUserPlaylists();
  }
}

final servicesProvider =
    StateNotifierProvider<ServicesNotifier, List<Map<String, String>>>(
  (ref) => ServicesNotifier(ref),
);
