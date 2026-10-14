// lib/providers/playlist_provider.dart
// Reactive state management with Riverpod:
//   • Dual catalog architecture: User Personal Playlists & Recommended/Chart Playlists
//   • Eradication of mock data & real stream resolution
//   • Active navigation tab provider (0: Inicio, 1: Buscar, 2: Librería, 3: Ajustes)
//   • Dynamic connection status backed by hardware Keystore

import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        _logger.d('Playlists: Sin listas personales de usuario aún, sincronizando recomendadas.');
        await _ref.read(featuredPlaylistsProvider.notifier).fetchFeaturedPlaylists(serviceId: serviceId);
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
        _ref.read(currentTrackProvider.notifier).state = tracks.first;

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
  FeaturedPlaylistsNotifier(this._ref) : super(const []) {
    fetchFeaturedPlaylists();
  }

  final Ref _ref;
  final _logger = Logger(printer: PrettyPrinter(methodCount: 0));

  Future<void> fetchFeaturedPlaylists({String? serviceId}) async {
    _logger.i('Playlists: Consultando catálogo de recomendadas y charts oficiales…');
    try {
      final service = serviceId != null
          ? MusicServiceRegistry.get(serviceId)
          : await MusicServiceRegistry.getActiveService();

      final playlists = await service.getFeaturedPlaylists();
      if (playlists.isNotEmpty) {
        state = playlists;
        _logger.i('Playlists: ${playlists.length} playlists recomendadas de ${service.displayName}.');

        // Si aún no hay ninguna seleccionada y el usuario no tiene personales, activar la primera
        if (_ref.read(selectedPlaylistProvider) == null && _ref.read(userPlaylistsProvider).isEmpty) {
          await _ref.read(userPlaylistsProvider.notifier).selectPlaylist(
            playlists.first,
            autoPlay: false,
            switchToLibrary: false,
          );
        }
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

// ─── Currently Selected Track ───────────────────────────────────────────────

final currentTrackProvider = StateProvider<Track?>((ref) {
  final tracks = ref.watch(recentTracksProvider);
  return tracks.isNotEmpty ? tracks.first : null;
});

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
    final amazonToken = await SecureStorageService.instance.getAmazonToken();
    final spotifyToken = await SecureStorageService.instance.getSpotifyToken();
    final tidalToken = await SecureStorageService.instance.getTidalToken();

    state = [
      {
        'name': 'Deezer',
        'icon': '🎵',
        'color': '#EF4444',
        'status': (deezerToken != null && deezerToken.isNotEmpty) ? 'connected' : 'disconnected',
      },
      {
        'name': 'Amazon Music',
        'icon': '🎶',
        'color': '#F97316',
        'status': (amazonToken != null && amazonToken.isNotEmpty) ? 'connected' : 'disconnected',
      },
      {
        'name': 'Spotify',
        'icon': '🟢',
        'color': '#1DB954',
        'status': (spotifyToken != null && spotifyToken.isNotEmpty) ? 'connected' : 'disconnected',
      },
      {
        'name': 'Tidal',
        'icon': '⬛',
        'color': '#00FFFF',
        'status': (tidalToken != null && tidalToken.isNotEmpty) ? 'connected' : 'disconnected',
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
      _ref.read(featuredPlaylistsProvider.notifier).fetchFeaturedPlaylists(serviceId: name);
    }
  }
}

final servicesProvider =
    StateNotifierProvider<ServicesNotifier, List<Map<String, String>>>(
  (ref) => ServicesNotifier(ref),
);
