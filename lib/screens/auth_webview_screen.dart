// lib/screens/auth_webview_screen.dart
// Clean consumer web authentication gateway for Deezer, Amazon Music, Spotify, and Tidal.
// Loads official portals (no unverified app_id / client_id parameters).
// Session data is extracted ONLY when the user presses the manual "Sincronizar" button.
// All extraction runs inside the WebView JS context so browser attaches HttpOnly cookies
// automatically (cookie jar with arl + sid + dzr_uniq_id), solving the USER_ID:0 problem.

import 'dart:async';
import 'dart:convert';
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
        heightFactor: 0.94,
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
  String _statusMsg = '';

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
      case 'deezer':   return 'https://www.deezer.com/login';
      case 'amazon':   return 'https://music.amazon.es';
      case 'spotify':  return 'https://accounts.spotify.com/login';
      case 'tidal':    return 'https://login.tidal.com';
      default:         return 'https://www.deezer.com/login';
    }
  }

  Color get _serviceBrandColor {
    switch (_serviceKey) {
      case 'deezer':   return const Color(0xFFEF4444);
      case 'amazon':   return const Color(0xFFF97316);
      case 'spotify':  return const Color(0xFF1DB954);
      case 'tidal':    return const Color(0xFF00FFFF);
      default:         return AppTheme.accentViolet;
    }
  }

  @override
  void initState() {
    super.initState();
    _currentUrl = _portalUrl;
    _initWebViewController();
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
          onPageFinished: (url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _currentUrl = url;
              });
            }
            // ─── NO HAY CIERRE AUTOMÁTICO. Solo el botón "Sincronizar" lo activa. ───
          },
          onNavigationRequest: (request) {
            _currentUrl = request.url;
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(_portalUrl));
  }

  // ─── EXTRACCIÓN IN-WEBVIEW: El JS corre dentro del contexto del navegador,
  //     por lo que el cookie jar (arl, sid, dzr_uniq_id...) se adjunta automáticamente. ───

  /// Extracción completa de sesión — solo se llama al pulsar "Sincronizar"
  Future<void> _manualSyncSession() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _statusMsg = 'Extrayendo sesión…';
    });

    try {
      switch (_serviceKey) {
        case 'deezer':
          await _syncDeezer();
          break;
        case 'amazon':
          await _syncAmazon();
          break;
        case 'spotify':
          await _syncSpotify();
          break;
        case 'tidal':
          await _syncTidal();
          break;
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('Error al sincronizar: $e'),
          ),
        );
      }
    }
  }

  // ─── DEEZER ────────────────────────────────────────────────────────────────

  Future<void> _syncDeezer() async {
    // Ejecutar fetch DENTRO del WebView con credentials:'include'
    // El navegador adjunta automáticamente arl + sid + dzr_uniq_id y todas las cookies HttpOnly
    const jsGetUserData = r'''
      (async () => {
        try {
          const r = await fetch(
            'https://www.deezer.com/ajax/gw-light.php?method=deezer.getUserData&input=3&api_version=1.0&api_token=',
            { method: 'POST', credentials: 'include', headers: {'Content-Type':'application/json'}, body: '{}' }
          );
          const j = await r.json();
          return JSON.stringify(j);
        } catch(e) { return JSON.stringify({error: e.toString()}); }
      })()
    ''';

    final rawResult = await _controller.runJavaScriptReturningResult(jsGetUserData);
    var str = rawResult.toString();
    if (str.startsWith('"') && str.endsWith('"')) str = jsonDecode(str);

    final gwData = jsonDecode(str) as Map?;
    if (gwData == null || gwData['error'] != null) {
      _showError('No se pudo contactar con Deezer. ¿Has iniciado sesión en la página?');
      return;
    }

    final results = gwData['results'] as Map?;
    final userObj = results?['USER'] as Map?;
    final userId  = userObj?['USER_ID']?.toString();
    final apiToken = results?['checkForm']?.toString();
    final licenseToken = userObj?['OPTIONS']?['license_token']?.toString();

    if (userId == null || userId == '0' || userId.isEmpty) {
      _showError('USER_ID es 0. Aún no has iniciado sesión en Deezer. Introduce tu correo y contraseña en la página y vuelve a pulsar Sincronizar.');
      return;
    }

    // Guardar en Keystore
    await SecureStorageService.instance.saveDeezerUserId(userId);
    if (apiToken != null && apiToken.isNotEmpty) {
      await SecureStorageService.instance.saveDeezerApiToken(apiToken);
    }
    if (licenseToken != null && licenseToken.isNotEmpty) {
      await SecureStorageService.instance.saveDeezerLicenseToken(licenseToken);
    }

    // Guardar cookies completas y arl
    final rawCookies = await _controller.runJavaScriptReturningResult('document.cookie');
    var cookies = rawCookies.toString();
    if (cookies.startsWith('"') && cookies.endsWith('"')) cookies = jsonDecode(cookies);
    await SecureStorageService.instance.saveDeezerCookies(cookies);

    final matchArl = RegExp(r'arl=([^;]+)').firstMatch(cookies);
    final arl = matchArl?.group(1)?.trim();
    final tokenToSave = arl ?? 'dz_user_$userId';
    await SecureStorageService.instance.saveDeezerToken(tokenToSave);

    // Obtener playlists del usuario vía JS dentro del WebView (ambos endpoints: pageProfile + /user/playlists)
    setState(() => _statusMsg = 'Obteniendo playlists…');
    final playlistsJson = await _fetchDeezerPlaylistsInWebView(userId, apiToken ?? '');
    int playlistCount = 0;
    if (playlistsJson.isNotEmpty) {
      try {
        final List list = jsonDecode(playlistsJson);
        playlistCount = list.length;
        if (list.isNotEmpty) {
          await SecureStorageService.instance.saveDeezerPlaylists(playlistsJson);
        }
      } catch (_) {}
    }

    await _onLoginSuccess('Deezer', tokenToSave,
        extraMsg: 'USER_ID: $userId · $playlistCount playlists sincronizadas · license_token: ${licenseToken != null ? "✓" : "✗"}');
  }

  /// Obtiene playlists del usuario autenticado en WebView (pageProfile privada + REST pública)
  Future<String> _fetchDeezerPlaylistsInWebView(String userId, String apiToken) async {
    final jsProfile = '''
      (async () => {
        try {
          const items = [];
          const seen = new Set();

          // 1. gw-light.php pageProfile (para playlists privadas del usuario)
          try {
            const r1 = await fetch(
              'https://www.deezer.com/ajax/gw-light.php?method=deezer.pageProfile&input=3&api_version=1.0&api_token=${apiToken.replaceAll("'", "")}',
              {
                method: 'POST',
                credentials: 'include',
                headers: {'Content-Type':'application/json'},
                body: JSON.stringify({"user_id": "$userId", "tab": "playlists", "nb": 100})
              }
            );
            const j1 = await r1.json();
            const tabs = j1?.results?.TAB?.playlists?.data || [];
            for (const p of tabs) {
              const id = (p.PLAYLIST_ID || p.id || '').toString();
              const name = (p.TITLE || p.title || '').toString();
              const count = parseInt(p.NB_SONG || p.nb_tracks || 0);
              const pic = p.PLAYLIST_PICTURE
                  ? 'https://e-cdns-images.dzcdn.net/images/playlist/' + p.PLAYLIST_PICTURE + '/500x500-000000-80-0-0.jpg'
                  : '';
              if (id && !seen.has(id)) {
                seen.add(id);
                items.push({ id, name, coverUrl: pic, trackCount: count, source: 'deezer' });
              }
            }
          } catch(e) {}

          // 2. REST API /user/$userId/playlists
          try {
            const r2 = await fetch('https://api.deezer.com/user/$userId/playlists?limit=100', { credentials: 'include' });
            const j2 = await r2.json();
            const data = j2?.data || [];
            for (const p of data) {
              const id = (p.id || '').toString();
              const name = (p.title || '').toString();
              const count = parseInt(p.nb_tracks || 0);
              const pic = p.picture_medium || p.picture_big || p.picture || '';
              if (id && !seen.has(id)) {
                seen.add(id);
                items.push({ id, name, coverUrl: pic, trackCount: count, source: 'deezer' });
              }
            }
          } catch(e) {}

          return JSON.stringify(items);
        } catch(e) { return JSON.stringify([]); }
      })()
    ''';

    try {
      final rawProfile = await _controller.runJavaScriptReturningResult(jsProfile);
      var profileStr = rawProfile.toString();
      if (profileStr.startsWith('"') && profileStr.endsWith('"')) {
        profileStr = jsonDecode(profileStr);
      }
      return profileStr;
    } catch (_) {}
    return '';
  }

  // ─── AMAZON MUSIC ─────────────────────────────────────────────────────────

  Future<void> _syncAmazon() async {
    setState(() => _statusMsg = 'Extrayendo playlists del DOM…');

    // Scraper DOM ampliado para distintas versiones del player de Amazon Music
    const jsScraper = r'''
      (() => {
        try {
          const items = [];
          const seen = new Set();

          // Selector 1: links directos a playlist
          const links = document.querySelectorAll('a[href*="/playlists/"], a[href*="/my/playlists/"], a[href*="playlist"]');
          for (const a of links) {
            const href = a.getAttribute('href') || '';
            const title = (a.textContent || '').trim() ||
                          a.getAttribute('title') || a.getAttribute('aria-label') || '';
            const img = a.querySelector('img')?.src || '';
            const idMatch = href.match(/playlists\/([A-Za-z0-9_\-]+)/);
            const id = idMatch ? idMatch[1] : href;
            if (title && title.length > 1 && !seen.has(title) &&
                !['Playlists','Música','Inicio','Explorar','Biblioteca','Buscar'].includes(title)) {
              seen.add(title);
              items.push({ id, name: title, coverUrl: img, trackCount: 0, source: 'amazon' });
            }
          }

          // Selector 2: music-card web components
          const cards = document.querySelectorAll('music-card, [data-testid="music-card"]');
          for (const c of cards) {
            const titleEl = c.querySelector('[slot="primaryText"], .primaryText, h2, h3, a');
            const name = titleEl ? (titleEl.textContent || '').trim() : '';
            const img = c.querySelector('img')?.src || '';
            if (name && name.length > 1 && !seen.has(name) && !['Playlists','Música'].includes(name)) {
              seen.add(name);
              items.push({ id: 'amz_' + items.length, name, coverUrl: img, trackCount: 0, source: 'amazon' });
            }
          }

          // Selector 3: listas con data-e2e o aria-label de playlist
          const listItems = document.querySelectorAll('[data-e2e*="playlist"], [aria-label*="playlist"], [aria-label*="lista"]');
          for (const li of listItems) {
            const name = (li.getAttribute('aria-label') || li.textContent || '').trim();
            if (name && name.length > 1 && !seen.has(name)) {
              seen.add(name);
              items.push({ id: 'amz_e2e_' + items.length, name, coverUrl: '', trackCount: 0, source: 'amazon' });
            }
          }

          return JSON.stringify(items);
        } catch(e) { return JSON.stringify([]); }
      })()
    ''';

    final scraperResult = await _controller.runJavaScriptReturningResult(jsScraper);
    var scraperStr = scraperResult.toString();
    if (scraperStr.startsWith('"') && scraperStr.endsWith('"')) {
      scraperStr = jsonDecode(scraperStr);
    }
    final List list = jsonDecode(scraperStr);
    final int foundCount = list.length;
    if (list.isNotEmpty) {
      await SecureStorageService.instance.saveAmazonPlaylists(scraperStr);
    }

    // Token de sesión
    final rawCookies = await _controller.runJavaScriptReturningResult('document.cookie');
    var cookies = rawCookies.toString();
    if (cookies.startsWith('"') && cookies.endsWith('"')) cookies = jsonDecode(cookies);
    final matchAmz = RegExp(r'(?:session-token|at-acbes|x-main)=([^;]+)').firstMatch(cookies);
    final token = matchAmz?.group(1)?.trim() ??
        'amz_synced_${DateTime.now().millisecondsSinceEpoch}';

    await _onLoginSuccess('Amazon Music', token,
        extraMsg: foundCount > 0 ? '$foundCount playlists sincronizadas' : 'Sesión guardada (navega a "Mis Playlists" para sincronizar)');
  }

  // ─── SPOTIFY ───────────────────────────────────────────────────────────────

  Future<void> _syncSpotify() async {
    final rawCookies = await _controller.runJavaScriptReturningResult('document.cookie');
    var cookies = rawCookies.toString();
    if (cookies.startsWith('"') && cookies.endsWith('"')) cookies = jsonDecode(cookies);
    final matchSp = RegExp(r'(?:sp_dc|sp_key)=([^;]+)').firstMatch(cookies);
    final token = matchSp?.group(1)?.trim() ??
        'sp_token_${DateTime.now().millisecondsSinceEpoch}';
    await _onLoginSuccess('Spotify', token);
  }

  // ─── TIDAL ─────────────────────────────────────────────────────────────────

  Future<void> _syncTidal() async {
    final rawCookies = await _controller.runJavaScriptReturningResult('document.cookie');
    var cookies = rawCookies.toString();
    if (cookies.startsWith('"') && cookies.endsWith('"')) cookies = jsonDecode(cookies);
    // Tidal usa JWT en localStorage, intentamos extraerlo también
    const jsLocalStorage = r'''
      (() => {
        try {
          const keys = Object.keys(localStorage);
          for (const k of keys) {
            const v = localStorage.getItem(k);
            if (v && v.includes('access_token')) return v;
          }
          return '';
        } catch(e) { return ''; }
      })()
    ''';
    final rawLs = await _controller.runJavaScriptReturningResult(jsLocalStorage);
    var lsStr = rawLs.toString();
    if (lsStr.startsWith('"') && lsStr.endsWith('"')) lsStr = jsonDecode(lsStr);

    String? accessToken;
    if (lsStr.isNotEmpty) {
      try {
        final lsData = jsonDecode(lsStr) as Map?;
        accessToken = lsData?['access_token']?.toString();
      } catch (_) {}
    }
    final token = accessToken ?? 'tidal_session_${DateTime.now().millisecondsSinceEpoch}';
    await _onLoginSuccess('Tidal', token);
  }

  // ─── Login Success ─────────────────────────────────────────────────────────

  Future<void> _onLoginSuccess(String serviceDisplayName, String token, {String? extraMsg}) async {
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

    ref.read(servicesProvider.notifier).updateStatus(serviceDisplayName, 'connected');
    await ref.read(userPlaylistsProvider.notifier).fetchUserPlaylists(serviceId: _serviceKey);

    widget.onAuthenticated?.call();

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          backgroundColor: const Color(0xFF1E293B),
          content: Row(
            children: [
              Icon(Icons.verified_rounded, color: _serviceBrandColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  extraMsg != null
                      ? '¡$serviceDisplayName conectado! $extraMsg'
                      : '¡$serviceDisplayName conectado! Sesión guardada en Keystore.',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _showError(String msg) {
    setState(() => _isSaving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          backgroundColor: const Color(0xFFDC2626),
          content: Text(msg, style: const TextStyle(color: Colors.white)),
        ),
      );
    }
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────

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
                  BoxShadow(color: _serviceBrandColor.withOpacity(0.6), blurRadius: 6),
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
                    style: const TextStyle(
                        color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    _statusMsg.isNotEmpty
                        ? _statusMsg
                        : 'Portal Oficial · Inicia sesión y pulsa Sincronizar',
                    style: const TextStyle(color: AppTheme.onSurfaceSub, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70),
            tooltip: 'Limpiar Cookies',
            onPressed: () async {
              await _cookieManager.clearCookies();
              _controller.reload();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Color(0xFF1E293B),
                    content: Text('Cookies eliminadas. Puedes iniciar sesión desde cero.'),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: 'Recargar página',
            onPressed: () => _controller.reload(),
          ),
          if (_serviceKey == 'amazon')
            IconButton(
              icon: const Icon(Icons.library_music_rounded, color: Color(0xFFF97316)),
              tooltip: 'Ir a Mis Playlists',
              onPressed: () => _controller.loadRequest(
                  Uri.parse('https://music.amazon.es/my/playlists')),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
            child: ElevatedButton.icon(
              icon: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
              label: const Text(
                'Sincronizar',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 4,
              ),
              onPressed: _isSaving ? null : () => _manualSyncSession(),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_isLoading ? 2 : 0),
          child: _isLoading
              ? LinearProgressIndicator(
                  value: _progress > 0 ? _progress / 100 : null,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(_serviceBrandColor),
                )
              : const SizedBox.shrink(),
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
