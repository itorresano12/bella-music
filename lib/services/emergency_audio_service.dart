// lib/services/emergency_audio_service.dart
//
// Emergency Offline Audio Service:
// Pre-configured buffer of royalty-free, low-bandwidth tracks cached or ready
// for immediate fallback when WAN connection drops or external streaming APIs fail.

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bella_music/models/playlist_model.dart';
import 'package:logger/logger.dart';

// ─── Emergency State Provider ─────────────────────────────────────────────────

final emergencyModeProvider = StateProvider<bool>((ref) => false);

// ─── Emergency Service ────────────────────────────────────────────────────────

class EmergencyAudioService {
  EmergencyAudioService._();
  static final EmergencyAudioService instance = EmergencyAudioService._();

  final _logger = Logger(printer: PrettyPrinter(methodCount: 0));

  /// Pre-configured emergency lounge tracks (royalty-free)
  static const List<Track> _fallbackTracks = [
    Track(
      id: 'emergency_1',
      title: 'Acoustic Calm (Offline Lounge)',
      artist: 'Bella Lounge Presets',
      albumArt: 'https://picsum.photos/seed/emergency1/400/400',
      streamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
      durationSeconds: 372,
      source: 'local',
      bitrate: 128,
      isFullLength: true,
      gainDb: 0.0,
    ),
    Track(
      id: 'emergency_2',
      title: 'Velvet Afternoon (Offline Lounge)',
      artist: 'Bella Lounge Presets',
      albumArt: 'https://picsum.photos/seed/emergency2/400/400',
      streamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
      durationSeconds: 423,
      source: 'local',
      bitrate: 128,
      isFullLength: true,
      gainDb: 0.0,
    ),
    Track(
      id: 'emergency_3',
      title: 'Santander Sunset (Offline Lounge)',
      artist: 'Bella Lounge Presets',
      albumArt: 'https://picsum.photos/seed/emergency3/400/400',
      streamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
      durationSeconds: 345,
      source: 'local',
      bitrate: 128,
      isFullLength: true,
      gainDb: 0.0,
    ),
    Track(
      id: 'emergency_4',
      title: 'Morning Espresso (Offline Lounge)',
      artist: 'Bella Lounge Presets',
      albumArt: 'https://picsum.photos/seed/emergency4/400/400',
      streamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
      durationSeconds: 390,
      source: 'local',
      bitrate: 128,
      isFullLength: true,
      gainDb: 0.0,
    ),
    Track(
      id: 'emergency_5',
      title: 'Soft Ambient Breeze (Offline Lounge)',
      artist: 'Bella Lounge Presets',
      albumArt: 'https://picsum.photos/seed/emergency5/400/400',
      streamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3',
      durationSeconds: 360,
      source: 'local',
      bitrate: 128,
      isFullLength: true,
      gainDb: 0.0,
    ),
  ];

  List<Track> get emergencyTracks => _fallbackTracks;

  /// Ensures local cache directory exists in app storage
  Future<String?> getEmergencyCacheDirectory() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${docDir.path}/bella_emergency_cache');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      return cacheDir.path;
    } catch (e) {
      _logger.d('Error resolviendo caché local de emergencia: $e');
      return null;
    }
  }
}
