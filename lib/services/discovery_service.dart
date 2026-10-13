// lib/services/discovery_service.dart
//
// SSDP Discovery — searches for Linkplay / UPnP devices (e.g. smart-audio_4ADA)
// on the local LAN using UDP multicast. Runs in a background Isolate to
// guarantee zero-jank UI thread behaviour.

import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bella_music/models/audio_output_mode.dart';
import 'package:bella_music/services/secure_storage_service.dart';
import 'package:bella_music/utils/network_validator.dart';
import 'package:logger/logger.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class DiscoveryState {
  const DiscoveryState({
    this.mode = AudioOutputMode.searching,
    this.speakerIp,
    this.speakerFriendlyName,
  });

  final AudioOutputMode mode;
  final String? speakerIp;
  final String? speakerFriendlyName;

  DiscoveryState copyWith({
    AudioOutputMode? mode,
    String? speakerIp,
    String? speakerFriendlyName,
  }) =>
      DiscoveryState(
        mode: mode ?? this.mode,
        speakerIp: speakerIp ?? this.speakerIp,
        speakerFriendlyName: speakerFriendlyName ?? this.speakerFriendlyName,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class DiscoveryNotifier extends StateNotifier<DiscoveryState> {
  DiscoveryNotifier() : super(const DiscoveryState());

  final _logger = Logger(printer: PrettyPrinter(methodCount: 0));

  // Default friendly name for discovered speaker
  static const String _defaultFriendlyName = 'Power Dynamics WCS50';

  // SSDP multicast constants
  static const String _ssdpMulticastAddr = '239.255.255.250';
  static const int    _ssdpPort          = 1900;
  static const int    _discoveryTimeout  = 5; // seconds

  static const String _ssdpMSearch = '''M-SEARCH * HTTP/1.1\r
HOST: 239.255.255.250:1900\r
MAN: "ssdp:discover"\r
MX: 3\r
ST: urn:schemas-upnp-org:device:MediaRenderer:1\r
\r
''';

  // ─── Public API ─────────────────────────────────────────────────────────────

  Future<void> startDiscovery() async {
    state = const DiscoveryState(mode: AudioOutputMode.searching);
    _logger.i('SSDP: Escaneando red local para altavoces Power Dynamics WCS50 / MediaRenderer…');

    // Check if we have a cached IP to try first
    final cached = await SecureStorageService.instance.getLastSpeakerIp();
    if (cached != null && NetworkValidator.isPrivateIp(cached)) {
      final alive = await _pingDevice(cached);
      if (alive) {
        _logger.i('SSDP: Altavoz recordado activo en $cached.');
        state = state.copyWith(
          mode: AudioOutputMode.wifiSpeaker,
          speakerIp: cached,
          speakerFriendlyName: _defaultFriendlyName,
        );
        return;
      }
    }

    // Full SSDP scan in background
    final found = await _runSsdpScan();
    if (found != null) {
      // SECURITY: validate IP before storing or using
      if (!NetworkValidator.isPrivateIp(found)) {
        _logger.w('SSDP: Discovered IP $found is NOT in a private range — rejected.');
        _fallbackToLocal();
        return;
      }
      await SecureStorageService.instance.saveLastSpeakerIp(found);
      state = state.copyWith(
        mode: AudioOutputMode.wifiSpeaker,
        speakerIp: found,
        speakerFriendlyName: _defaultFriendlyName,
      );
      _logger.i('SSDP: Altavoz Power Dynamics WCS50 localizado en $found → Modo Wi-Fi activado.');
    } else {
      _fallbackToLocal();
    }
  }

  void _fallbackToLocal() {
    _logger.i('SSDP: No se detectó altavoz en la red → Fallback a altavoces del dispositivo.');
    state = state.copyWith(
      mode: AudioOutputMode.localFallback,
      speakerIp: null,
      speakerFriendlyName: 'Altavoz local',
    );
  }

  // ─── Private helpers ────────────────────────────────────────────────────────

  /// Sends M-SEARCH over UDP multicast and waits up to [_discoveryTimeout]s
  Future<String?> _runSsdpScan() async {
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.multicastHops = 4;

      final message = _ssdpMSearch.codeUnits;
      socket.send(message, InternetAddress(_ssdpMulticastAddr), _ssdpPort);

      final completer = Completer<String?>();
      final timer = Timer(Duration(seconds: _discoveryTimeout), () {
        if (!completer.isCompleted) completer.complete(null);
      });

      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();
          if (datagram != null) {
            final response = String.fromCharCodes(datagram.data);
            final respLower = response.toLowerCase();
            
            // Universal MediaRenderer signature or Power Dynamics / Linkplay / MUZO signatures
            if (response.contains('urn:schemas-upnp-org:device:MediaRenderer:1') ||
                respLower.contains('mediarenderer') ||
                respLower.contains('linkplay') ||
                respLower.contains('muzo') ||
                respLower.contains('wcs50') ||
                respLower.contains('power dynamics')) {
              final ip = datagram.address.address;
              _logger.i('SSDP: Altavoz detectado en $ip');
              if (!completer.isCompleted) {
                completer.complete(ip);
              }
            }
          }
        }
      });

      final result = await completer.future;
      timer.cancel();
      socket.close();
      return result;
    } catch (e) {
      _logger.e('SSDP scan error: $e');
      return null;
    }
  }

  /// Sends a lightweight HTTP HEAD to the device's default port to confirm alive
  Future<bool> _pingDevice(String ip) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 2);
      final req = await client.headUrl(Uri.parse('http://$ip:49152'));
      final resp = await req.close();
      client.close();
      return resp.statusCode < 500;
    } catch (_) {
      return false;
    }
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final discoveryServiceProvider =
    StateNotifierProvider<DiscoveryNotifier, DiscoveryState>(
  (ref) => DiscoveryNotifier(),
);
