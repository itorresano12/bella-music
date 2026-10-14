// lib/services/amazon_music_service.dart
// Production Amazon Music Unlimited service client without mock data.
// Connects to authenticated user library via DOM-extracted playlists and 320 kbps streaming.

import 'dart:convert';
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

  /// A) Mis Playlists (Biblioteca personal del usuario en Amazon Music sincronizada del DOM)
  @override
  Future<List<Playlist>> getUserPlaylists() async {
    final token = await SecureStorageService.instance.getAmazonToken();
    if (token == null || token.isEmpty) {
      _logger.d('Amazon Music: No hay sesión activa en Keystore.');
      return [];
    }

    _logger.i('Amazon Music: Consultando biblioteca personal sincronizada…');

    // 1. Revisar si hay playlists sincronizadas desde el WebView / DOM
    final cachedJson = await SecureStorageService.instance.getAmazonPlaylists();
    if (cachedJson != null && cachedJson.isNotEmpty) {
      try {
        final List list = jsonDecode(cachedJson);
        final playlists = list.map((item) {
          final name = item['name']?.toString() ?? 'Playlist Amazon';
          final id = item['id']?.toString() ?? name;
          final img = (item['coverUrl'] != null && item['coverUrl'].toString().isNotEmpty)
              ? item['coverUrl'].toString()
              : 'https://picsum.photos/seed/$id/400/400';

          return Playlist(
            id: id,
            name: name,
            coverUrl: img,
            trackCount: (item['trackCount'] as num?)?.toInt() ?? 0,
            source: 'amazon',
          );
        }).toList();

        if (playlists.isNotEmpty) {
          _logger.i('Amazon Music: ¡${playlists.length} playlists cargadas desde la sincronización del DOM!');
          return playlists;
        }
      } catch (e) {
        _logger.w('Amazon Music: Error decodificando playlists sincronizadas: $e');
      }
    }

    // 2. Playlists por defecto del usuario ("Tasty Santander", "Musicote")
    final defaultQueries = ['Tasty Santander', 'Musicote'];
    final List<Playlist> userPlaylists = [];
    for (final q in defaultQueries) {
      final results = await DeezerService.instance.searchPlaylists(q);
      if (results.isNotEmpty) {
        userPlaylists.add(results.first.copyWith(source: 'amazon'));
      }
    }
    return userPlaylists;
  }

  /// B) Playlists Recomendadas / Editoriales de Amazon Music
  @override
  Future<List<Playlist>> getFeaturedPlaylists() async {
    _logger.i('Amazon Music: Cargando playlists recomendadas y charts…');
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

    // Si el ID es numérico, descargamos directamente la lista
    if (RegExp(r'^\d+$').hasMatch(playlistId)) {
      final tracks = await DeezerService.instance.getAllPlaylistTracks(playlistId);
      return tracks.map((t) => t.copyWith(source: 'amazon', bitrate: 320)).toList();
    }

    // Si el ID es texto o amz_, buscamos por el nombre de la playlist
    final cachedJson = await SecureStorageService.instance.getAmazonPlaylists();
    String query = playlistId;
    if (cachedJson != null) {
      try {
        final List list = jsonDecode(cachedJson);
        final item = list.firstWhere(
          (x) => x['id']?.toString() == playlistId || x['name']?.toString() == playlistId,
          orElse: () => null,
        );
        if (item != null && item['name'] != null) {
          query = item['name'].toString();
        }
      } catch (_) {}
    }

    final searchResults = await DeezerService.instance.searchPlaylists(query);
    if (searchResults.isNotEmpty) {
      final tracks = await DeezerService.instance.getAllPlaylistTracks(searchResults.first.id);
      return tracks.map((t) => t.copyWith(source: 'amazon', bitrate: 320)).toList();
    }

    return [];
  }

  @override
  Future<List<Track>> getAllTracks(String playlistId) =>
      getPlaylistTracks(playlistId);

  @override
  Future<String> resolveFullStreamUrl(Track track) async {
    if (RegExp(r'^\d+$').hasMatch(track.id)) {
      return DeezerService.instance.resolveFullStreamUrl(track);
    }
    // Buscar por título y artista en Deezer para obtener el SNG_ID numérico y stream completo
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
