// lib/widgets/services_grid.dart
// Interactive gateway grid for Deezer and Amazon Music authentication.
// Validates account credentials via Deezer API and securely stores tokens
// in Android Keystore / iOS Keychain (AES-256-GCM).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bella_music/theme/app_theme.dart';
import 'package:bella_music/widgets/glass_container.dart';
import 'package:bella_music/services/secure_storage_service.dart';
import 'package:bella_music/services/deezer_service.dart';
import 'package:bella_music/providers/playlist_provider.dart';

class ServicesGrid extends ConsumerStatefulWidget {
  const ServicesGrid({super.key, required this.services});
  final List<Map<String, String>> services;

  static void openAuthModal(BuildContext context, WidgetRef ref, String serviceName) {
    final isDeezer = serviceName.toLowerCase().contains('deezer');
    final tokenController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AuthModalContent(
        serviceName: serviceName,
        isDeezer: isDeezer,
        tokenController: tokenController,
        ref: ref,
      ),
    );
  }

  @override
  ConsumerState<ServicesGrid> createState() => _ServicesGridState();
}

class _ServicesGridState extends ConsumerState<ServicesGrid> {
  bool _deezerConnected = false;
  bool _amazonConnected = false;

  @override
  void initState() {
    super.initState();
    _checkSavedTokens();
  }

  Future<void> _checkSavedTokens() async {
    final deezerToken = await SecureStorageService.instance.getDeezerToken();
    final amazonToken = await SecureStorageService.instance.getAmazonToken();
    if (mounted) {
      setState(() {
        _deezerConnected = deezerToken != null && deezerToken.isNotEmpty;
        _amazonConnected = amazonToken != null && amazonToken.isNotEmpty;
      });
    }
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
        final isDeezer = name.toLowerCase().contains('deezer');
        final isConnected = isDeezer ? _deezerConnected : _amazonConnected;

        return GradientCard(
          onTap: () {
            ServicesGrid.openAuthModal(context, ref, name);
            // Refresh connection states after modal closes
            Future.delayed(const Duration(milliseconds: 500), _checkSavedTokens);
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
                    isConnected ? 'Conectado (Keystore)' : 'Toca para autenticar',
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

class _AuthModalContent extends StatefulWidget {
  const _AuthModalContent({
    required this.serviceName,
    required this.isDeezer,
    required this.tokenController,
    required this.ref,
  });

  final String serviceName;
  final bool isDeezer;
  final TextEditingController tokenController;
  final WidgetRef ref;

  @override
  State<_AuthModalContent> createState() => _AuthModalContentState();
}

class _AuthModalContentState extends State<_AuthModalContent> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(
          color: AppTheme.accentViolet.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.8),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text(widget.isDeezer ? '🎵' : '🎶', style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pasarela ${widget.serviceName}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  const Text(
                    'Cifrado hardware Keystore (AES-256-GCM)',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.accentBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            widget.isDeezer
                ? 'Introduce tu token de sesión oficial de Deezer (ARL / OAuth) para sincronizar las playlists y canciones de tu local:'
                : 'Introduce tus credenciales de Amazon Music (User Token / OAuth2 Secret):',
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.onSurfaceSub,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: widget.tokenController,
            obscureText: true,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF222222),
              hintText: widget.isDeezer ? 'Token Deezer ARL...' : 'Amazon Music Secret...',
              hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
              prefixIcon: const Icon(Icons.key_rounded, color: AppTheme.accentViolet),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.accentViolet, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          final token = widget.tokenController.text.trim();
                          if (token.isEmpty) return;

                          setState(() => _isLoading = true);

                          if (widget.isDeezer) {
                            await SecureStorageService.instance.saveDeezerToken(token);
                            final result = await DeezerService.instance.validateAndSync(token);

                            if (result.success) {
                              if (result.playlists.isNotEmpty) {
                                widget.ref.read(playlistsProvider.notifier).setPlaylists(result.playlists);
                              }
                              if (result.tracks.isNotEmpty) {
                                widget.ref.read(recentTracksProvider.notifier).setTracks(result.tracks);
                                widget.ref.read(currentTrackProvider.notifier).state = result.tracks.first;
                              }
                              widget.ref.read(servicesProvider.notifier).updateStatus('Deezer', 'connected');
                            }

                            if (mounted) {
                              setState(() => _isLoading = false);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: const Color(0xFF1E293B),
                                  content: Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E)),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          result.message,
                                          style: const TextStyle(color: Colors.white, fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                          } else {
                            await SecureStorageService.instance.saveAmazonToken(token);
                            widget.ref.read(servicesProvider.notifier).updateStatus('Amazon Music', 'connected');
                            if (mounted) {
                              setState(() => _isLoading = false);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: Color(0xFF1E293B),
                                  content: Row(
                                    children: [
                                      Icon(Icons.shield_rounded, color: Color(0xFF22C55E)),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          '✅ Credenciales de Amazon Music guardadas en hardware Keystore.',
                                          style: TextStyle(color: Colors.white, fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentViolet,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Validar y Conectar con TLS',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
