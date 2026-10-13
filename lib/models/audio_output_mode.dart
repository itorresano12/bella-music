// lib/models/audio_output_mode.dart
// Represents whether audio is being routed to the smart speaker or locally.

enum AudioOutputMode {
  wifiSpeaker,   // DLNA/Linkplay altavoz Wi-Fi encontrado
  localFallback, // Altavoces del teléfono (modo prueba)
  searching,     // Descubrimiento en curso
}

extension AudioOutputModeLabel on AudioOutputMode {
  String get label {
    switch (this) {
      case AudioOutputMode.wifiSpeaker:
        return '🔊 Altavoz Wi-Fi';
      case AudioOutputMode.localFallback:
        return '📱 Modo de Prueba (Móvil)';
      case AudioOutputMode.searching:
        return '🔍 Buscando dispositivos…';
    }
  }

  bool get isWifi => this == AudioOutputMode.wifiSpeaker;
}

