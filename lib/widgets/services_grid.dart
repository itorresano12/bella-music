// lib/widgets/services_grid.dart
// Interactive grid for Deezer and Amazon Music authentication gateways.
// Saves real credentials encrypted with AES-GCM in hardware Keystore / Keychain.

import 'package:flutter/material.dart';
import 'package:bella_music/theme/app_theme.dart';
import 'package:bella_music/widgets/glass_container.dart';
import 'package:bella_music/services/secure_storage_service.dart';

class ServicesGrid extends StatefulWidget {
  const ServicesGrid({super.key, required this.services});
  final List<Map<String, String>> services;

  @override
  State<ServicesGrid> createState() => _ServicesGridState();
}

class _ServicesGridState extends State<ServicesGrid> {
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

  void _openAuthModal(BuildContext context, String serviceName) {
    final isDeezer = serviceName.toLowerCase().contains('deezer');
    final tokenController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
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
                Text(isDeezer ? '🎵' : '🎶', style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pasarela $serviceName',
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
              isDeezer
                  ? 'Introduce tu token de sesión oficial de Deezer (ARL / OAuth) para sincronizar las playlists de tu local:'
                  : 'Introduce tus credenciales de Amazon Music (User Token / OAuth2 Secret):',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.onSurfaceSub,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: tokenController,
              obscureText: true,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF222222),
                hintText: isDeezer ? 'Token Deezer ARL...' : 'Amazon Music Secret...',
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
                    onPressed: () async {
                      final token = tokenController.text.trim();
                      if (token.isEmpty) return;

                      if (isDeezer) {
                        await SecureStorageService.instance.saveDeezerToken(token);
                      } else {
                        await SecureStorageService.instance.saveAmazonToken(token);
                      }

                      await _checkSavedTokens();

                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF1E293B),
                            content: Row(
                              children: [
                                const Icon(Icons.shield_rounded, color: Color(0xFF22C55E)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '✅ Credenciales de $serviceName cifradas en Keystore.',
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
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
                    child: const Text(
                      'Guardar y Conectar con TLS',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
          onTap: () => _openAuthModal(context, name),
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
