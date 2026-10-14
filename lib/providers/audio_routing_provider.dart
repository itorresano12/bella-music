// lib/providers/audio_routing_provider.dart
//
// Hardened Hybrid Audio Routing Controller:
//   • Wi-Fi Output (Power Dynamics WCS50 / Linkplay A31):
//     Mobile acts exclusively as remote controller — phone calls, voice notes,
//     and local video audio remain isolated on the device and never route to the speaker.
//   • Local / Bluetooth Output (just_audio & AudioSession):
//     Direct on-device audio routed to phone speaker or paired Bluetooth receiver.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bella_music/models/audio_output_mode.dart';
import 'package:bella_music/services/discovery_service.dart';

enum AudioRouteType {
  wifiSpeaker,
  localDevice,
  bluetooth,
}

class AudioRoutingState {
  final AudioRouteType routeType;
  final AudioOutputMode outputMode;
  final String? activeSpeakerIp;
  final String activeDeviceName;
  final bool isRemoteControllerOnly; // true when mobile does not output sound locally

  const AudioRoutingState({
    required this.routeType,
    required this.outputMode,
    this.activeSpeakerIp,
    required this.activeDeviceName,
    required this.isRemoteControllerOnly,
  });

  bool get isWifi => routeType == AudioRouteType.wifiSpeaker;
  bool get isLocal => routeType == AudioRouteType.localDevice || routeType == AudioRouteType.bluetooth;

  AudioRoutingState copyWith({
    AudioRouteType? routeType,
    AudioOutputMode? outputMode,
    String? activeSpeakerIp,
    String? activeDeviceName,
    bool? isRemoteControllerOnly,
  }) =>
      AudioRoutingState(
        routeType: routeType ?? this.routeType,
        outputMode: outputMode ?? this.outputMode,
        activeSpeakerIp: activeSpeakerIp ?? this.activeSpeakerIp,
        activeDeviceName: activeDeviceName ?? this.activeDeviceName,
        isRemoteControllerOnly: isRemoteControllerOnly ?? this.isRemoteControllerOnly,
      );
}

class AudioRoutingNotifier extends StateNotifier<AudioRoutingState> {
  final Ref _ref;

  AudioRoutingNotifier(this._ref)
      : super(const AudioRoutingState(
          routeType: AudioRouteType.localDevice,
          outputMode: AudioOutputMode.localFallback,
          activeSpeakerIp: null,
          activeDeviceName: 'Altavoz del Teléfono / Bluetooth',
          isRemoteControllerOnly: false,
        )) {
    _bindDiscoveryListener();
  }

  void _bindDiscoveryListener() {
    _ref.listen<DiscoveryState>(discoveryServiceProvider, (previous, next) {
      if (next.mode == AudioOutputMode.wifiSpeaker && next.speakerIp != null) {
        state = AudioRoutingState(
          routeType: AudioRouteType.wifiSpeaker,
          outputMode: AudioOutputMode.wifiSpeaker,
          activeSpeakerIp: next.speakerIp,
          activeDeviceName: next.speakerFriendlyName ?? 'Altavoz Wi-Fi (${next.speakerIp})',
          isRemoteControllerOnly: true,
        );
      } else {
        state = const AudioRoutingState(
          routeType: AudioRouteType.localDevice,
          outputMode: AudioOutputMode.localFallback,
          activeSpeakerIp: null,
          activeDeviceName: 'Altavoz del Teléfono / Bluetooth',
          isRemoteControllerOnly: false,
        );
      }
    });
  }

  void switchToLocal() {
    _ref.read(discoveryServiceProvider.notifier).switchToLocal();
  }

  void switchToWifiSpeaker() {
    _ref.read(discoveryServiceProvider.notifier).switchToWifiSpeaker();
  }
}

final audioRoutingProvider =
    StateNotifierProvider<AudioRoutingNotifier, AudioRoutingState>((ref) {
  return AudioRoutingNotifier(ref);
});
