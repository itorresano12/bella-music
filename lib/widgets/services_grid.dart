// lib/widgets/services_grid.dart
// Commercial Login Gateway for Deezer Premium, Amazon Music, Spotify, and Tidal.
// Opens the clean AuthWebViewScreen for direct, official web authentication,
// saving intercepted session tokens safely in hardware Keystore.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bella_music/theme/app_theme.dart';
import 'package:bella_music/widgets/glass_container.dart';
import 'package:bella_music/services/secure_storage_service.dart';
import 'package:bella_music/screens/auth_webview_screen.dart';

class ServicesGrid extends ConsumerStatefulWidget {
  const ServicesGrid({super.key, required this.services});
  final List<Map<String, String>> services;

  static void openAuthModal(BuildContext context, WidgetRef ref, String serviceName) {
    AuthWebViewScreen.open(context, ref, serviceName);
  }

  @override
  ConsumerState<ServicesGrid> createState() => _ServicesGridState();
}

class _ServicesGridState extends ConsumerState<ServicesGrid> {
  final Map<String, bool> _connectedServices = {
    'deezer': false,
    'amazon': false,
    'spotify': false,
    'tidal': false,
  };

  @override
  void initState() {
    super.initState();
    _checkSavedTokens();
  }

  Future<void> _checkSavedTokens() async {
    final deezerToken = await SecureStorageService.instance.getDeezerToken();
    final amazonToken = await SecureStorageService.instance.getAmazonToken();
    final spotifyToken = await SecureStorageService.instance.getSpotifyToken();
    final tidalToken = await SecureStorageService.instance.getTidalToken();
    if (mounted) {
      setState(() {
        _connectedServices['deezer'] = deezerToken != null && deezerToken.isNotEmpty;
        _connectedServices['amazon'] = amazonToken != null && amazonToken.isNotEmpty;
        _connectedServices['spotify'] = spotifyToken != null && spotifyToken.isNotEmpty;
        _connectedServices['tidal'] = tidalToken != null && tidalToken.isNotEmpty;
      });
    }
  }

  String _getServiceKey(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('deezer')) return 'deezer';
    if (lower.contains('amazon')) return 'amazon';
    if (lower.contains('spotify')) return 'spotify';
    if (lower.contains('tidal')) return 'tidal';
    return 'deezer';
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.6,
      ),
      itemCount: widget.services.length,
      itemBuilder: (context, i) {
        final s = widget.services[i];
        final name = s['name'] ?? '';
        final key = _getServiceKey(name);
        final isConnected = _connectedServices[key] ?? true;

        return GradientCard(
          onTap: () async {
            await AuthWebViewScreen.open(context, ref, name);
            if (mounted) _checkSavedTokens();
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(s['icon'] ?? '🎵', style: const TextStyle(fontSize: 24)),
                  const Spacer(),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isConnected ? const Color(0xFF22C55E) : AppTheme.onSurfaceSub,
                      boxShadow: isConnected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF22C55E).withOpacity(0.6),
                                blurRadius: 6,
                              )
                            ]
                          : null,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: AppTheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    isConnected ? 'Premium Activo (HQ 320k)' : 'Iniciar sesión comercial',
                    style: TextStyle(
                      fontSize: 10,
                      color: isConnected ? const Color(0xFF22C55E) : AppTheme.accentBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
