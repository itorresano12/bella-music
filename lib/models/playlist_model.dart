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
  final String source; // 'deezer' | 'amazon' | 'local'

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
  });

  final String id;
  final String title;
  final String artist;
  final String albumArt;
  final String streamUrl;
  final int durationSeconds;
  final String source;

  @override
  List<Object?> get props => [id, title, artist, streamUrl];
}

