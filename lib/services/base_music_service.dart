// lib/services/base_music_service.dart
//
// Unified Music Streaming Architecture:
// Abstract contract defining multi-platform music providers (Deezer, Amazon, Spotify, Tidal).
// Cleanly decouples UI from concrete API implementations and eradicates all mock data.

import 'package:bella_music/models/playlist_model.dart';
import 'package:bella_music/services/deezer_service.dart';
import 'package:bella_music/services/amazon_music_service.dart';
import 'package:bella_music/services/spotify_service.dart';
import 'package:bella_music/services/tidal_service.dart';
import 'package:bella_music/services/secure_storage_service.dart';

export 'package:bella_music/services/deezer_service.dart';
export 'package:bella_music/services/amazon_music_service.dart';
export 'package:bella_music/services/spotify_service.dart';
export 'package:bella_music/services/tidal_service.dart';

abstract class BaseMusicService {
  /// Unique identifier ('deezer', 'amazon', 'spotify', 'tidal')
  String get serviceId;

  /// Human-readable brand name
  String get displayName;

  /// Representative icon or emoji
  String get icon;

  /// Primary brand color hex
  String get brandColorHex;

  /// Validates session or prompts authentication
  Future<bool> authenticate();

  /// A) Mis Playlists (Biblioteca personal del usuario autenticado)
  Future<List<Playlist>> getUserPlaylists();

  /// B) Playlists Recomendadas / Editoriales / Destacadas de la plataforma
  Future<List<Playlist>> getFeaturedPlaylists();

  /// Retrieves all tracks belonging to a given playlist
  Future<List<Track>> getPlaylistTracks(String playlistId);

  /// Backwards-compatible alias for getPlaylistTracks
  Future<List<Track>> getAllTracks(String playlistId);

  /// Resolves high-fidelity (320 kbps) stream URL with injected headers/tokens
  Future<String> resolveFullStreamUrl(Track track);

  /// Backwards-compatible alias for resolveFullStreamUrl
  Future<String> resolveStreamUrl(Track track);
}

// ─── Concrete Deezer Provider ─────────────────────────────────────────────────

class DeezerMusicService implements BaseMusicService {
  const DeezerMusicService();

  @override
  String get serviceId => 'deezer';

  @override
  String get displayName => 'Deezer Premium';

  @override
  String get icon => '🎵';

  @override
  String get brandColorHex => '#EF4444';

  @override
  Future<bool> authenticate() async {
    final token = await SecureStorageService.instance.getDeezerToken();
    return token != null && token.isNotEmpty;
  }

  @override
  Future<List<Playlist>> getUserPlaylists() async {
    return DeezerService.instance.getUserPlaylists();
  }

  @override
  Future<List<Playlist>> getFeaturedPlaylists() async {
    return DeezerService.instance.getFeaturedPlaylists();
  }

  @override
  Future<List<Track>> getPlaylistTracks(String playlistId) async {
    return DeezerService.instance.getAllPlaylistTracks(playlistId);
  }

  @override
  Future<List<Track>> getAllTracks(String playlistId) =>
      getPlaylistTracks(playlistId);

  @override
  Future<String> resolveFullStreamUrl(Track track) async {
    return DeezerService.instance.resolveFullStreamUrl(track);
  }

  @override
  Future<String> resolveStreamUrl(Track track) =>
      resolveFullStreamUrl(track);
}

// ─── Registry / Factory ───────────────────────────────────────────────────────

class MusicServiceRegistry {
  MusicServiceRegistry._();

  static const Map<String, BaseMusicService> _registry = {
    'deezer': DeezerMusicService(),
    'amazon': AmazonMusicService(),
    'spotify': SpotifyMusicService(),
    'tidal': TidalMusicService(),
  };

  static BaseMusicService get(String serviceId) {
    final key = serviceId.toLowerCase();
    if (key.contains('deezer')) return _registry['deezer']!;
    if (key.contains('amazon')) return _registry['amazon']!;
    if (key.contains('spotify')) return _registry['spotify']!;
    if (key.contains('tidal')) return _registry['tidal']!;
    return _registry['deezer']!;
  }

  static Future<BaseMusicService> getActiveService() async {
    final deezerToken = await SecureStorageService.instance.getDeezerToken();
    if (deezerToken != null && deezerToken.isNotEmpty) return _registry['deezer']!;

    final amazonToken = await SecureStorageService.instance.getAmazonToken();
    if (amazonToken != null && amazonToken.isNotEmpty) return _registry['amazon']!;

    final spotifyToken = await SecureStorageService.instance.getSpotifyToken();
    if (spotifyToken != null && spotifyToken.isNotEmpty) return _registry['spotify']!;

    final tidalToken = await SecureStorageService.instance.getTidalToken();
    if (tidalToken != null && tidalToken.isNotEmpty) return _registry['tidal']!;

    return _registry['deezer']!;
  }

  static List<BaseMusicService> getAll() => _registry.values.toList();
}
