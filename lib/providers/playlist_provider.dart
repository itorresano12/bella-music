// lib/providers/playlist_provider.dart
// Reactive state management with Riverpod:
//   • Dynamic playlists & tracks connected to Deezer API
//   • Active navigation tab provider (0: Inicio, 1: Buscar, 2: Librería, 3: Ajustes)
//   • Real-time track search provider

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bella_music/models/playlist_model.dart';
import 'package:bella_music/services/deezer_service.dart';

// ─── Initial Fallback Data ──────────────────────────────────────────────────

final _initialPlaylists = [
  const Playlist(
    id: '15821465801',
    name: 'Tasty Santander',
    coverUrl: 'https://cdn-images.dzcdn.net/images/cover/08304eb172098540c635de98530d4929/250x250-000000-80-0-0.jpg',
    trackCount: 321,
    source: 'deezer',
  ),
  const Playlist(
    id: '2',
    name: 'Late Night Vibes',
    coverUrl: 'https://picsum.photos/seed/night/400/400',
    trackCount: 18,
    source: 'amazon',
  ),
  const Playlist(
    id: '3',
    name: 'Deep Focus',
    coverUrl: 'https://picsum.photos/seed/focus/400/400',
    trackCount: 45,
    source: 'deezer',
  ),
  const Playlist(
    id: '4',
    name: 'Electric Summer',
    coverUrl: 'https://picsum.photos/seed/summer/400/400',
    trackCount: 27,
    source: 'amazon',
  ),
];

final _initialTracks = [
  const Track(
    id: 't1',
    title: 'Neon Dreams',
    artist: 'Synthwave Collective',
    albumArt: 'https://picsum.photos/seed/neon/400/400',
    streamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
    durationSeconds: 214,
    source: 'deezer',
  ),
  const Track(
    id: 't2',
    title: 'Midnight City',
    artist: 'Echo Waves',
    albumArt: 'https://picsum.photos/seed/midnight/400/400',
    streamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
    durationSeconds: 183,
    source: 'amazon',
  ),
  const Track(
    id: 't3',
    title: 'Purple Horizon',
    artist: 'Violet Pulse',
    albumArt: 'https://picsum.photos/seed/purple/400/400',
    streamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
    durationSeconds: 267,
    source: 'deezer',
  ),
];

// ─── Playlists Notifier ─────────────────────────────────────────────────────

class PlaylistsNotifier extends StateNotifier<List<Playlist>> {
  PlaylistsNotifier() : super(_initialPlaylists) {
    _autoLoadRealPlaylists();
  }

  Future<void> _autoLoadRealPlaylists() async {
    try {
      final real = await DeezerService.instance.searchPlaylists('Tasty Santander');
      if (real.isNotEmpty) {
        state = real;
      }
    } catch (_) {}
  }

  void setPlaylists(List<Playlist> list) {
    state = list;
  }
}

final playlistsProvider =
    StateNotifierProvider<PlaylistsNotifier, List<Playlist>>(
  (ref) => PlaylistsNotifier(),
);

// ─── Tracks Notifier ────────────────────────────────────────────────────────

class RecentTracksNotifier extends StateNotifier<List<Track>> {
  RecentTracksNotifier() : super(_initialTracks) {
    _autoLoadRealTracks();
  }

  Future<void> _autoLoadRealTracks() async {
    try {
      final playlists = await DeezerService.instance.searchPlaylists('Tasty Santander');
      if (playlists.isNotEmpty) {
        final tracks = await DeezerService.instance.getAllPlaylistTracks(playlists.first.id);
        if (tracks.isNotEmpty) {
          state = tracks;
        }
      }
    } catch (_) {}
  }

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

// ─── Services Notifier ──────────────────────────────────────────────────────

class ServicesNotifier extends StateNotifier<List<Map<String, String>>> {
  ServicesNotifier()
      : super([
          {
            'name': 'Deezer',
            'icon': '🎵',
            'color': '#EF4444',
            'status': 'connected',
          },
          {
            'name': 'Amazon Music',
            'icon': '🎶',
            'color': '#F97316',
            'status': 'connected',
          },
          {
            'name': 'Spotify',
            'icon': '🟢',
            'color': '#1DB954',
            'status': 'connected',
          },
          {
            'name': 'Tidal',
            'icon': '⬛',
            'color': '#00FFFF',
            'status': 'connected',
          },
        ]);

  void updateStatus(String name, String status) {
    state = [
      for (final s in state)
        if (s['name'] == name) {...s, 'status': status} else s
    ];
  }
}

final servicesProvider =
    StateNotifierProvider<ServicesNotifier, List<Map<String, String>>>(
  (ref) => ServicesNotifier(),
);
