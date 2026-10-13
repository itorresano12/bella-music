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

  // SSDP multicast constants
  static const String _ssdpMulticastAddr = '239.255.255.250';
  static const int    _ssdpPort          = 1900;
  static const int    _discoveryTimeout  = 6; // seconds

  // Universal UPnP M-SEARCH searching for ANY audio MediaRenderer on LAN
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
    _logger.i('SSDP: Radar universal activo — buscando cualquier reproductor de audio en red Wi-Fi…');

    // 1. Probar primero si hay un altavoz previamente recordado en la subred
    final cached = await SecureStorageService.instance.getLastSpeakerIp();
    if (cached != null && NetworkValidator.isPrivateIp(cached)) {
      final alive = await _pingDevice(cached);
      if (alive) {
        _logger.i('SSDP: Dispositivo de audio recordado activo en $cached.');
        state = state.copyWith(
          mode: AudioOutputMode.wifiSpeaker,
          speakerIp: cached,
          speakerFriendlyName: 'Altavoz Wi-Fi ($cached)',
        );
        return;
      }
    }

    // 2. Escaneo abierto universal en la red Wi-Fi
    final found = await _runUniversalSsdpScan();
    if (found != null) {
      // Mitigación SSRF: validar que la IP pertenezca a la subred privada local
      if (!NetworkValidator.isPrivateIp(found)) {
        _logger.w('SSDP: La IP detectada $found no es privada — ignorada por seguridad.');
        _fallbackToLocal();
        return;
      }

      await SecureStorageService.instance.saveLastSpeakerIp(found);
      final friendlyName = 'Altavoz Wi-Fi ($found)';
      state = state.copyWith(
        mode: AudioOutputMode.wifiSpeaker,
        speakerIp: found,
        speakerFriendlyName: friendlyName,
      );
      _logger.i('SSDP: ¡Reproductor de audio enlazado con éxito en $found! Modo Wi-Fi activo.');
    } else {
      _fallbackToLocal();
    }
  }

  void _fallbackToLocal() {
    _logger.i('SSDP: Sin altavoces Wi-Fi detectados → Conmutando a reproducción local en el teléfono.');
    state = state.copyWith(
      mode: AudioOutputMode.localFallback,
      speakerIp: null,
      speakerFriendlyName: 'Altavoz del Teléfono',
    );
  }

  // ─── Private helpers ────────────────────────────────────────────────────────

  /// Escucha el socket multicast y enlaza con el PRIMER MediaRenderer que responda
  Future<String?> _runUniversalSsdpScan() async {
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
            final respUpper = response.toUpperCase();
            
            // FILTRO UNIVERSAL: Acepta cualquier dispositivo multimedia UPnP/DLNA
            // que responda con la firma estándar de MediaRenderer o AVTransport
            final isMediaRenderer = respUpper.contains('MEDIARENDERER') ||
                respUpper.contains('AVTRANSPORT') ||
                respUpper.contains('RENDERINGCONTROL') ||
                respUpper.contains('LINKPLAY') ||
                respUpper.contains('UPNP:ROOTDEVICE');

            if (isMediaRenderer) {
              final ip = datagram.address.address;
              _logger.i('SSDP Radar: Detectado reproductor universal en $ip');
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
      _logger.e('SSDP radar error: $e');
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
