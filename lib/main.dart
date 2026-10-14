// BellaMusic — main.dart
// Entry point: initialises Riverpod, forces dark theme, and mounts the app.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:bella_music/theme/app_theme.dart';
import 'package:bella_music/screens/home_screen.dart';
import 'package:bella_music/services/discovery_service.dart';
import 'package:bella_music/services/audio_service.dart';
import 'package:bella_music/services/blowfish_decrypt_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize System AudioService (MediaSessionCompat / Lockscreen / Volume buttons)
  await AudioService.init(
    builder: () => BellaAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.bellamusic.app.channel.audio',
      androidNotificationChannelName: 'Bella Music Reproducción',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
    ),
  );

  // Start the local Blowfish decryption proxy for full-length Deezer audio
  // This must start before any track is played so the URL is ready
  await BlowfishDecryptService.instance.startServer();

  // Lock orientation to portrait for the premium experience
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Transparent status bar — content bleeds under it for immersive look
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0D0D0D),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    const ProviderScope(
      child: BellaMusicApp(),
    ),
  );
}

class BellaMusicApp extends ConsumerWidget {
  const BellaMusicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kick off SSDP discovery in background immediately on app start
    ref.read(discoveryServiceProvider.notifier).startDiscovery();

    return MaterialApp(
      title: 'BellaMusic',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const HomeScreen(),
    );
  }
}

