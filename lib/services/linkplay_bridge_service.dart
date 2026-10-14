// lib/services/linkplay_bridge_service.dart
//
// Dedicated hardware bridge service for Linkplay A31 / Power Dynamics WCS50.
// Handles high-speed HTTP GET commands (port 80):
//   • Hardware volume controls (relative +/-2 and absolute 0-100)
//   • Playback lifecycle commands (play, pause, resume, stop, next, prev)
//   • Dynamic Gain Normalization (setPlayerCmd:Equalizer:gain:...)
//   • Heartbeat status telemetry (getPlayerStatus) with LinkplayPlayerStatus model

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:bella_music/utils/network_validator.dart';
import 'package:logger/logger.dart';

// ─── Remote Player Status Model ───────────────────────────────────────────────

class LinkplayPlayerStatus {
  final String status; // 'play', 'pause', 'stop', 'load'
  final int currentPositionSeconds;
  final int totalDurationSeconds;
  final int volume;

  const LinkplayPlayerStatus({
    required this.status,
    required this.currentPositionSeconds,
    required this.totalDurationSeconds,
    this.volume = 50,
  });

  bool get isPlaying => status.toLowerCase() == 'play';
  bool get isPaused  => status.toLowerCase() == 'pause';
  bool get isStopped => status.toLowerCase() == 'stop';

  /// Detects when track has finished or is within 2 seconds of completion
  bool get isNearEnd =>
      totalDurationSeconds > 0 && currentPositionSeconds >= (totalDurationSeconds - 2);
}

// ─── Linkplay Hardware Bridge Service ─────────────────────────────────────────

class LinkplayBridgeService {
  LinkplayBridgeService._();
  static final LinkplayBridgeService instance = LinkplayBridgeService._();

  final _logger = Logger(printer: PrettyPrinter(methodCount: 0));
  static const Duration _httpTimeout = Duration(seconds: 3);

  /// Relative volume adjustment (+step or -step)
  Future<bool> adjustRelativeVolume(String speakerIp, int delta) async {
    if (!NetworkValidator.isPrivateIp(speakerIp)) return false;
    final sign = delta >= 0 ? '+$delta' : '$delta';
    try {
      final uri = Uri.parse('http://$speakerIp/httpapi.asp?command=setPlayerCmd:vol:$sign');
      final res = await http.get(uri).timeout(_httpTimeout);
      if (res.statusCode == 200 && (res.body.contains('OK') || res.body.contains('success'))) {
        _logger.i('Linkplay Hardware: Volumen relativo $sign despachado a $speakerIp.');
        return true;
      }
    } catch (e) {
      _logger.d('Error al ajustar volumen relativo Linkplay: $e');
    }
    return false;
  }

  Future<bool> volumeUp(String speakerIp, {int step = 2}) =>
      adjustRelativeVolume(speakerIp, step.abs());

  Future<bool> volumeDown(String speakerIp, {int step = 2}) =>
      adjustRelativeVolume(speakerIp, -step.abs());

  /// Sets absolute volume (0 - 100)
  Future<bool> setVolume(String speakerIp, int volume) async {
    if (!NetworkValidator.isPrivateIp(speakerIp)) return false;
    final clamped = volume.clamp(0, 100);
    try {
      final uri = Uri.parse('http://$speakerIp/httpapi.asp?command=setPlayerCmd:vol:$clamped');
      final res = await http.get(uri).timeout(_httpTimeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Dispatches audio stream play command
  Future<bool> play(String speakerIp, String streamUrl) async {
    if (!NetworkValidator.isPrivateIp(speakerIp)) return false;
    try {
      final uri = Uri.parse(
        'http://$speakerIp/httpapi.asp?command=setPlayerCmd:play:${Uri.encodeComponent(streamUrl)}',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200 && (res.body.contains('OK') || res.body.contains('success'))) {
        _logger.i('Linkplay Hardware: Comando setPlayerCmd:play despachado a $speakerIp.');
        return true;
      }
    } catch (e) {
      _logger.w('Error despachando play en Linkplay: $e');
    }
    return false;
  }

  /// Dispatches pause command
  Future<bool> pause(String speakerIp) async {
    if (!NetworkValidator.isPrivateIp(speakerIp)) return false;
    try {
      final uri = Uri.parse('http://$speakerIp/httpapi.asp?command=setPlayerCmd:pause');
      final res = await http.get(uri).timeout(_httpTimeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Dispatches resume command
  Future<bool> resume(String speakerIp) async {
    if (!NetworkValidator.isPrivateIp(speakerIp)) return false;
    try {
      final uri = Uri.parse('http://$speakerIp/httpapi.asp?command=setPlayerCmd:resume');
      final res = await http.get(uri).timeout(_httpTimeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Dispatches stop command
  Future<bool> stop(String speakerIp) async {
    if (!NetworkValidator.isPrivateIp(speakerIp)) return false;
    try {
      final uri = Uri.parse('http://$speakerIp/httpapi.asp?command=setPlayerCmd:stop');
      final res = await http.get(uri).timeout(_httpTimeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Dispatches skip to next command
  Future<bool> skipToNext(String speakerIp) async {
    if (!NetworkValidator.isPrivateIp(speakerIp)) return false;
    try {
      final uri = Uri.parse('http://$speakerIp/httpapi.asp?command=setPlayerCmd:next');
      final res = await http.get(uri).timeout(_httpTimeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Dispatches skip to previous command
  Future<bool> skipToPrevious(String speakerIp) async {
    if (!NetworkValidator.isPrivateIp(speakerIp)) return false;
    try {
      final uri = Uri.parse('http://$speakerIp/httpapi.asp?command=setPlayerCmd:prev');
      final res = await http.get(uri).timeout(_httpTimeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Normalizes dynamic gain / loudness on Linkplay chip
  Future<bool> setEqualizerGain(String speakerIp, double gainDb) async {
    if (!NetworkValidator.isPrivateIp(speakerIp)) return false;
    try {
      final gainStr = gainDb.toStringAsFixed(1);
      final uri = Uri.parse('http://$speakerIp/httpapi.asp?command=setPlayerCmd:Equalizer:gain:$gainStr');
      final res = await http.get(uri).timeout(const Duration(seconds: 2));
      _logger.i('Linkplay Normalización: Ganancia ecualizada a $gainStr dB en $speakerIp.');
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Status telemetry polling
  Future<LinkplayPlayerStatus?> getPlayerStatus(String speakerIp) async {
    if (!NetworkValidator.isPrivateIp(speakerIp)) return null;
    try {
      final uri = Uri.parse('http://$speakerIp/httpapi.asp?command=getPlayerStatus');
      final res = await http.get(uri).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200 && res.body.isNotEmpty) {
        final data = jsonDecode(res.body);
        if (data is Map) {
          final statusStr = data['status']?.toString() ?? 'stop';
          int curpos = (int.tryParse(data['curpos']?.toString() ?? '0')) ?? 0;
          int totlen = (int.tryParse(data['totlen']?.toString() ?? '0')) ?? 0;
          int vol = (int.tryParse(data['vol']?.toString() ?? '50')) ?? 50;

          if (curpos > 10000 || totlen > 10000) {
            curpos = curpos ~/ 1000;
            totlen = totlen ~/ 1000;
          }

          return LinkplayPlayerStatus(
            status: statusStr,
            currentPositionSeconds: curpos,
            totalDurationSeconds: totlen,
            volume: vol,
          );
        }
      }
    } catch (_) {
      // Return null on socket failure or timeout
    }
    return null;
  }
}

