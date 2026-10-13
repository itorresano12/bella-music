# 🎵 BellaMusic

> **Premium Flutter music controller** — DLNA/Linkplay Wi-Fi speaker integration with intelligent local audio fallback, bank-grade security, and a glassmorphism dark UI.

---

## ✨ Features

| Feature | Description |
|---|---|
| 🎨 **Premium Dark UI** | Glassmorphism, Montserrat typography, violet-to-neon gradients |
| 🔊 **Wi-Fi Speaker Control** | SSDP/DLNA discovery → Linkplay SOAP commands to Forestream |
| 📱 **Local Audio Fallback** | Auto-switches to `just_audio` if no smart speaker found |
| 🔐 **Hardware Encryption** | Tokens in Android Keystore / iOS Keychain via `flutter_secure_storage` |
| 🛡️ **HTTPS-Only** | Network Security Config blocks all cleartext external traffic |
| 🔒 **R8 Obfuscation** | ProGuard rules + R8 full mode in release builds |
| 🚫 **SSRF Prevention** | IP validation ensures UPnP commands stay on private subnets |

---

## 🏗️ Architecture

```
lib/
├── main.dart                    # Entry point
├── theme/
│   └── app_theme.dart           # Dark palette, gradients, typography
├── models/
│   ├── playlist_model.dart      # Playlist & Track data classes
│   └── audio_output_mode.dart   # Enum: wifiSpeaker / localFallback / searching
├── services/
│   ├── discovery_service.dart   # SSDP/UPnP scanner (async, Riverpod)
│   ├── upnp_service.dart        # SOAP commands: SetAVTransportURI, Play, Pause
│   ├── audio_service.dart       # Unified audio controller (Wi-Fi ↔ Local)
│   └── secure_storage_service.dart # Keystore/Keychain credential vault
├── providers/
│   └── playlist_provider.dart   # Riverpod data providers
├── utils/
│   └── network_validator.dart   # SSRF mitigation — RFC-1918 IP validation
├── widgets/
│   ├── glass_container.dart     # BackdropFilter glassmorphism containers
│   ├── playlist_carousel.dart   # Horizontal playlist carousel
│   ├── now_playing_bar.dart     # Floating player bar with rotating art
│   └── services_grid.dart       # Deezer / Amazon service tiles
└── screens/
    └── home_screen.dart         # Main screen assembly
```

---

## 🔐 Security Architecture

### Storage
- **Zero plain-text secrets** — All API tokens encrypted at rest in hardware-backed Keystore/Keychain
- `flutter_secure_storage` with `AES_GCM_NoPadding` cipher on Android

### Network
- **TLS enforced** via `android/app/src/main/res/xml/network_security_config.xml`
- `cleartextTrafficPermitted="false"` globally (LAN-only exception for UPnP)

### Code Protection
- `minifyEnabled true` + `shrinkResources true` in release `build.gradle`
- `android.enableR8.fullMode=true` for aggressive class repackaging
- All `Log.*` calls stripped in release via ProGuard `assumenosideeffects`
- Classes repackaged to `com.bellamusic.obf`

### SSRF Prevention
- `NetworkValidator.isPrivateIp()` validates every UPnP target IP against RFC-1918 ranges before dispatching any packet

---

## 🚀 Getting Started

```bash
# Install dependencies
flutter pub get

# Run in debug mode
flutter run

# Build release APK (with full obfuscation)
flutter build apk --release

# Build release App Bundle
flutter build appbundle --release --obfuscate --split-debug-info=./debug-info
```

---

## 📡 Linkplay / SSDP Configuration

Edit `lib/services/discovery_service.dart` and set `_targetDeviceId` to match your device's SSDP/USN identifier:

```dart
static const String _targetDeviceId = 'smart-audio_4ADA'; // ← Your device
```

The app will:
1. Send an M-SEARCH multicast on `239.255.255.250:1900`
2. Parse responses for the target device name
3. If found → route audio via `SetAVTransportURI` SOAP command
4. If not found → fall back to on-device `just_audio` playback

---

## 🎨 Color Palette

| Token | Hex | Usage |
|---|---|---|
| Background | `#0D0D0D` | Scaffold background |
| Surface | `#1A1A1A` | Cards, panels |
| Accent Violet | `#8B5CF6` | Primary accent, gradient start |
| Accent Blue | `#06B6D4` | Gradient end, Wi-Fi indicator |
| Accent Pink | `#EC4899` | Highlights |

---

*Built with Flutter · Riverpod · just_audio · flutter_secure_storage*
