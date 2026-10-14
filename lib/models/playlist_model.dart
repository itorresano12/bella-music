// lib/models/playlist_model.dart

import 'package:equatable/equatable.dart';

class Playlist extends Equatable {
  const Playlist({
    required this.id,
    required this.name,
    required this.coverUrl,
    required this.trackCount,
    this.source = 'local',
  });

  final String id;
  final String name;
  final String coverUrl;
  final int trackCount;
  final String source; // 'deezer' | 'amazon' | 'spotify' | 'tidal' | 'local'

  Playlist copyWith({
    String? id,
    String? name,
    String? coverUrl,
    int? trackCount,
    String? source,
  }) =>
      Playlist(
        id: id ?? this.id,
        name: name ?? this.name,
        coverUrl: coverUrl ?? this.coverUrl,
        trackCount: trackCount ?? this.trackCount,
        source: source ?? this.source,
      );

  @override
  List<Object?> get props => [id, name, coverUrl, trackCount, source];
}

class Track extends Equatable {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.albumArt,
    required this.streamUrl,
    this.durationSeconds = 0,
    this.source = 'local',
    this.bitrate = 320,
    this.isFullLength = true,
    this.gainDb = 0.0,
  });

  final String id;
  final String title;
  final String artist;
  final String albumArt;
  final String streamUrl;
  final int durationSeconds;
  final String source;
  final int bitrate; // 320 kbps High Quality
  final bool isFullLength;
  final double gainDb; // ReplayGain / Loudness normalization in dB

  Track copyWith({
    String? id,
    String? title,
    String? artist,
    String? albumArt,
    String? streamUrl,
    int? durationSeconds,
    String? source,
    int? bitrate,
    bool? isFullLength,
    double? gainDb,
  }) =>
      Track(
        id: id ?? this.id,
        title: title ?? this.title,
        artist: artist ?? this.artist,
        albumArt: albumArt ?? this.albumArt,
        streamUrl: streamUrl ?? this.streamUrl,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        source: source ?? this.source,
        bitrate: bitrate ?? this.bitrate,
        isFullLength: isFullLength ?? this.isFullLength,
        gainDb: gainDb ?? this.gainDb,
      );

  @override
  List<Object?> get props => [id, title, artist, streamUrl, bitrate, isFullLength, gainDb];
}
