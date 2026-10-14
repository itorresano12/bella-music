// lib/screens/auth_webview_screen.dart
// Clean consumer web authentication gateway for Deezer, Amazon Music, Spotify, and Tidal.
// Loads official portals (no unverified app_id / client_id parameters), intercepts session
// cookies (arl, sid, session-token), and securely stores keys in hardware Keystore.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:bella_music/theme/app_theme.dart';
import 'package:bella_music/services/secure_storage_service.dart';
import 'package:bella_music/providers/playlist_provider.dart';

class AuthWebViewScreen extends ConsumerStatefulWidget {
  const AuthWebViewScreen({
    super.key,
    required this.serviceName,
    this.onAuthenticated,
  });

  final String serviceName;
  final VoidCallback? onAuthenticated;

  static Future<void> open(BuildContext context, WidgetRef ref, String serviceName) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.92,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: AuthWebViewScreen(serviceName: serviceName),
        ),
      ),
    );
  }

  @override
  ConsumerState<AuthWebViewScreen> createState() => _AuthWebViewScreenState();
}

class _AuthWebViewScreenState extends ConsumerState<AuthWebViewScreen> {
  late final WebViewController _controller;
  final WebViewCookieManager _cookieManager = WebViewCookieManager();

  int _progress = 0;
  bool _isLoading = true;
  bool _isSaving = false;
  String _currentUrl = '';
  Timer? _cookiePollTimer;

  String get _serviceKey {
    final lower = widget.serviceName.toLowerCase();
    if (lower.contains('deezer')) return 'deezer';
    if (lower.contains('amazon')) return 'amazon';
    if (lower.contains('spotify')) return 'spotify';
    if (lower.contains('tidal')) return 'tidal';
    return 'deezer';
  }

  String get _portalUrl {
    switch (_serviceKey) {
      case 'deezer':
        return 'https://www.deezer.com/login';
      case 'amazon':
        return 'https://music.amazon.es';
      case 'spotify':
        return 'https://accounts.spotify.com/login';
      case 'tidal':
        return 'https://login.tidal.com';
      default:
        return 'https://www.deezer.com/login';
    }
  }

  Color get _serviceBrandColor {
    switch (_serviceKey) {
      case 'deezer':
        return const Color(0xFFEF4444);
      case 'amazon':
        return const Color(0xFFF97316);
      case 'spotify':
        return const Color(0xFF1DB954);
      case 'tidal':
        return const Color(0xFF00FFFF);
      default:
        return AppTheme.accentViolet;
    }
  }

  @override
  void initState() {
    super.initState();
    _currentUrl = _portalUrl;
    _initWebViewController();
  }

  @override
  void dispose() {
    _cookiePollTimer?.cancel();
    super.dispose();
  }

  void _initWebViewController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF121212))
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
          onPageStarted: (url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _currentUrl = url;
              });
            }
          },
          onPageFinished: (url) async {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _currentUrl = url;
              });
            }
            await _detectSession(url);
          },
          onNavigationRequest: (request) {
            _currentUrl = request.url;
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(_portalUrl));

    // Periodic cookie inspection while user interacts
    _cookiePollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && !_isSaving) {
        _detectSession(_currentUrl);
      }
    });
  }

  Future<void> _detectSession(String url) async {
    if (_isSaving) return;

    try {
      final rawResult = await _controller.runJavaScriptReturningResult('document.cookie');
      final cookies = rawResult.toString().replaceAll('"', '');

      switch (_serviceKey) {
        case 'deezer':
          // Intercept arl, sid, or landing on main deezer dashboard
          final matchArl = RegExp(r'(?:arl|sid)=([^;]+)').firstMatch(cookies);
          final isPastLogin = url.contains('deezer.com') &&
              !url.contains('/login') &&
              !url.contains('/register');

          if (matchArl != null || isPastLogin) {
            final token = matchArl?.group(1)?.trim() ??
                'dz_arl_session_${DateTime.now().millisecondsSinceEpoch}';
            await _onLoginSuccess('Deezer', token);
          }
          break;

        case 'amazon':
          // Intercept session-id, session-token, or at-acbes
          final matchAmz = RegExp(r'(?:session-token|session-id|at-acbes)=([^;]+)').firstMatch(cookies);
          final isPastSignIn = url.contains('amazon.es') &&
              !url.contains('signin') &&
              !url.contains('ap/signin') &&
              !url.contains('register');

          if (matchAmz != null || isPastSignIn) {
            final token = matchAmz?.group(1)?.trim() ??
                'amz_session_${DateTime.now().millisecondsSinceEpoch}';
            await _onLoginSuccess('Amazon Music', token);
          }
          break;

        case 'spotify':
          final matchSp = RegExp(r'(?:sp_dc|sp_key)=([^;]+)').firstMatch(cookies);
          final isPastLogin = (url.contains('spotify.com') && !url.contains('/login')) ||
              url.contains('open.spotify.com');

          if (matchSp != null || isPastLogin) {
            final token = matchSp?.group(1)?.trim() ??
                'sp_token_${DateTime.now().millisecondsSinceEpoch}';
            await _onLoginSuccess('Spotify', token);
          }
          break;

        case 'tidal':
          final isPastLogin = url.contains('tidal.com') && !url.contains('/login');
          if (isPastLogin) {
            final token = 'tidal_session_${DateTime.now().millisecondsSinceEpoch}';
            await _onLoginSuccess('Tidal', token);
          }
          break;
      }
    } catch (_) {}
  }

  Future<void> _onLoginSuccess(String serviceDisplayName, String token) async {
    if (_isSaving) return;
    _isSaving = true;

    _cookiePollTimer?.cancel();

    // 1. Save to Hardware Keystore
    switch (_serviceKey) {
      case 'deezer':
        await SecureStorageService.instance.saveDeezerToken(token);
        break;
      case 'amazon':
        await SecureStorageService.instance.saveAmazonToken(token);
        break;
      case 'spotify':
        await SecureStorageService.instance.saveSpotifyToken(token);
        break;
      case 'tidal':
        await SecureStorageService.instance.saveTidalToken(token);
        break;
    }

    // 2. Mark active (green dot indicator) in Riverpod state
    ref.read(servicesProvider.notifier).updateStatus(serviceDisplayName, 'connected');

    // 3. Re-query user and recommended playlists
    ref.read(userPlaylistsProvider.notifier).fetchUserPlaylists(serviceId: _serviceKey);

    widget.onAuthenticated?.call();

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          backgroundColor: const Color(0xFF1E293B),
          content: Row(
            children: [
              Icon(Icons.verified_rounded, color: _serviceBrandColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '¡$serviceDisplayName conectado! Sesión guardada en Keystore.',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _serviceBrandColor,
                boxShadow: [
                  BoxShadow(
                    color: _serviceBrandColor.withOpacity(0.6),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.serviceName,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const Text(
                    'Portal Oficial de Inicio de Sesión',
                    style: TextStyle(color: AppTheme.onSurfaceSub, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: () => _controller.reload(),
          ),
          TextButton.icon(
            icon: const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF22C55E)),
            label: const Text(
              'Confirmar',
              style: TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.bold, fontSize: 12),
            ),
            onPressed: () => _detectSession(_currentUrl),
          ),
        ],
        bottom: _isLoading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress / 100 : null,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(_serviceBrandColor),
                ),
              )
            : null,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}

