// lib/providers/playlist_provider.dart
// Mock data provider — replace with real Deezer/Amazon API calls
// using tokens from SecureStorageService.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bella_music/models/playlist_model.dart';

// ─── Mock Playlists ────────────────────────────────────────────────────────

final _mockPlaylists = [
  const Playlist(
    id: '1',
    name: 'Tasty Santander',
    coverUrl: 'https://picsum.photos/seed/tasty/400/400',
    trackCount: 32,
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
  const Playlist(
    id: '5',
    name: 'Chill Roots',
    coverUrl: 'https://picsum.photos/seed/chill/400/400',
    trackCount: 22,
    source: 'local',
  ),
];

final _mockTracks = [
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

// ─── Providers ─────────────────────────────────────────────────────────────

final playlistsProvider = Provider<List<Playlist>>((ref) => _mockPlaylists);

final currentTrackProvider = StateProvider<Track?>((ref) => _mockTracks.first);

final recentTracksProvider = Provider<List<Track>>((ref) => _mockTracks);

// Services available
final servicesProvider = Provider<List<Map<String, String>>>((ref) => [
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
]);

