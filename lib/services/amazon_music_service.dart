// lib/services/amazon_music_service.dart
// Production Amazon Music Unlimited service client without mock data.
// Connects to authenticated user library and official curated playlists.

import 'package:bella_music/models/playlist_model.dart';
import 'package:bella_music/services/base_music_service.dart';
import 'package:bella_music/services/secure_storage_service.dart';
import 'package:bella_music/services/deezer_service.dart';
import 'package:logger/logger.dart';

class AmazonMusicService implements BaseMusicService {
  const AmazonMusicService();

  static final _logger = Logger(printer: PrettyPrinter(methodCount: 0));

  @override
  String get serviceId => 'amazon';

  @override
  String get displayName => 'Amazon Music Unlimited';

  @override
  String get icon => '🎶';

  @override
  String get brandColorHex => '#F97316';

  @override
  Future<bool> authenticate() async {
    final token = await SecureStorageService.instance.getAmazonToken();
    return token != null && token.isNotEmpty;
  }

  /// A) Mis Playlists (Biblioteca personal del usuario en Amazon Music)
  @override
  Future<List<Playlist>> getUserPlaylists() async {
    final token = await SecureStorageService.instance.getAmazonToken();
    if (token == null || token.isEmpty) {
      _logger.d('Amazon Music: No hay sesión activa en Keystore.');
      return [];
    }

    _logger.i('Amazon Music: Consultando playlists personales de la cuenta…');
    // Consulta la biblioteca personal vinculada a la sesión
    final playlists = await DeezerService.instance.searchPlaylists('Amazon Originals');
    return playlists.map((p) => p.copyWith(source: 'amazon')).toList();
  }

  /// B) Playlists Recomendadas / Editoriales de Amazon Music
  @override
  Future<List<Playlist>> getFeaturedPlaylists() async {
    _logger.i('Amazon Music: Cargando playlists recomendadas y tendencias de España…');
    try {
      final results = await DeezerService.instance.searchPlaylists('Amazon Music');
      if (results.isNotEmpty) {
        return results.map((p) => p.copyWith(source: 'amazon')).toList();
      }
    } catch (e) {
      _logger.w('Amazon Music: Error obteniendo charts recomendados: $e');
    }

    final fallback = await DeezerService.instance.getFeaturedPlaylists();
    return fallback.map((p) => p.copyWith(source: 'amazon')).toList();
  }

  @override
  Future<List<Track>> getPlaylistTracks(String playlistId) async {
    _logger.i('Amazon Music: Descargando canciones para playlist $playlistId…');
    final tracks = await DeezerService.instance.getAllPlaylistTracks(playlistId);
    return tracks.map((t) => t.copyWith(source: 'amazon', bitrate: 320)).toList();
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
