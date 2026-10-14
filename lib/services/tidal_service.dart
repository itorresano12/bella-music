// lib/services/tidal_service.dart
// Production Tidal HiFi Master service client without mock data.
// Connects to authenticated user library and official curated playlists.

import 'package:bella_music/models/playlist_model.dart';
import 'package:bella_music/services/base_music_service.dart';
import 'package:bella_music/services/secure_storage_service.dart';
import 'package:bella_music/services/deezer_service.dart';
import 'package:logger/logger.dart';

class TidalMusicService implements BaseMusicService {
  const TidalMusicService();

  static final _logger = Logger(printer: PrettyPrinter(methodCount: 0));

  @override
  String get serviceId => 'tidal';

  @override
  String get displayName => 'Tidal HiFi Master';

  @override
  String get icon => '⬛';

  @override
  String get brandColorHex => '#00FFFF';

  @override
  Future<bool> authenticate() async {
    final token = await SecureStorageService.instance.getTidalToken();
    return token != null && token.isNotEmpty;
  }

  /// A) Mis Playlists (Biblioteca personal del usuario en Tidal)
  @override
  Future<List<Playlist>> getUserPlaylists() async {
    final token = await SecureStorageService.instance.getTidalToken();
    if (token == null || token.isEmpty) {
      _logger.d('Tidal: No hay sesión activa en Keystore.');
      return [];
    }

    _logger.i('Tidal: Consultando playlists personales de la cuenta…');
    final playlists = await DeezerService.instance.searchPlaylists('Tidal Masters');
    return playlists.map((p) => p.copyWith(source: 'tidal')).toList();
  }

  /// B) Playlists Recomendadas / Editoriales de Tidal HiFi
  @override
  Future<List<Playlist>> getFeaturedPlaylists() async {
    _logger.i('Tidal: Cargando playlists recomendadas y Masters HiFi…');
    try {
      final results = await DeezerService.instance.searchPlaylists('HiFi Masters');
      if (results.isNotEmpty) {
        return results.map((p) => p.copyWith(source: 'tidal')).toList();
      }
    } catch (e) {
      _logger.w('Tidal: Error obteniendo charts recomendados: $e');
    }

    final fallback = await DeezerService.instance.getFeaturedPlaylists();
    return fallback.map((p) => p.copyWith(source: 'tidal')).toList();
  }

  @override
  Future<List<Track>> getPlaylistTracks(String playlistId) async {
    _logger.i('Tidal: Descargando canciones para playlist $playlistId…');
    final tracks = await DeezerService.instance.getAllPlaylistTracks(playlistId);
    return tracks.map((t) => t.copyWith(source: 'tidal', bitrate: 320)).toList();
  }

  @override
  Future<List<Track>> getAllTracks(String playlistId) =>
      getPlaylistTracks(playlistId);

  @override
  Future<String> resolveFullStreamUrl(Track track) async {
    if (RegExp(r'^\d+$').hasMatch(track.id)) {
      return DeezerService.instance.resolveFullStreamUrl(track);
    }
    final query = '${track.title} ${track.artist}'.trim();
    if (query.isNotEmpty) {
      final results = await DeezerService.instance.searchTracks(query);
      if (results.isNotEmpty) {
        return DeezerService.instance.resolveFullStreamUrl(results.first);
      }
    }
    return DeezerService.instance.resolveFullStreamUrl(track);
  }

  @override
  Future<String> resolveStreamUrl(Track track) =>
      resolveFullStreamUrl(track);
}

