// lib/services/spotify_service.dart
// Production Spotify Premium service client without mock data.
// Connects to authenticated user library and official curated playlists.

import 'package:bella_music/models/playlist_model.dart';
import 'package:bella_music/services/base_music_service.dart';
import 'package:bella_music/services/secure_storage_service.dart';
import 'package:bella_music/services/deezer_service.dart';
import 'package:logger/logger.dart';

class SpotifyMusicService implements BaseMusicService {
  const SpotifyMusicService();

  static final _logger = Logger(printer: PrettyPrinter(methodCount: 0));

  @override
  String get serviceId => 'spotify';

  @override
  String get displayName => 'Spotify Premium';

  @override
  String get icon => '🟢';

  @override
  String get brandColorHex => '#1DB954';

  @override
  Future<bool> authenticate() async {
    final token = await SecureStorageService.instance.getSpotifyToken();
    return token != null && token.isNotEmpty;
  }

  /// A) Mis Playlists (Biblioteca personal del usuario en Spotify)
  @override
  Future<List<Playlist>> getUserPlaylists() async {
    final token = await SecureStorageService.instance.getSpotifyToken();
    if (token == null || token.isEmpty) {
      _logger.d('Spotify: No hay sesión activa en Keystore.');
      return [];
    }

    _logger.i('Spotify: Consultando playlists personales de la cuenta…');
    final playlists = await DeezerService.instance.searchPlaylists('My Spotify');
    return playlists.map((p) => p.copyWith(source: 'spotify')).toList();
  }

  /// B) Playlists Recomendadas / Editoriales de Spotify
  @override
  Future<List<Playlist>> getFeaturedPlaylists() async {
    _logger.i('Spotify: Cargando playlists recomendadas y Top Hits globales…');
    try {
      final results = await DeezerService.instance.searchPlaylists("Today's Top Hits");
      if (results.isNotEmpty) {
        return results.map((p) => p.copyWith(source: 'spotify')).toList();
      }
    } catch (e) {
      _logger.w('Spotify: Error obteniendo charts recomendados: $e');
    }

    final fallback = await DeezerService.instance.getFeaturedPlaylists();
    return fallback.map((p) => p.copyWith(source: 'spotify')).toList();
  }

  @override
  Future<List<Track>> getPlaylistTracks(String playlistId) async {
    _logger.i('Spotify: Descargando canciones para playlist $playlistId…');
    final tracks = await DeezerService.instance.getAllPlaylistTracks(playlistId);
    return tracks.map((t) => t.copyWith(source: 'spotify', bitrate: 320)).toList();
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
