// lib/services/secure_storage_service.dart
//
// SECURITY: All credentials and API tokens are stored exclusively in
// Android Keystore / iOS Keychain via flutter_secure_storage.
// Plain text and SharedPreferences are strictly FORBIDDEN for secrets.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

class SecureStorageService {
  SecureStorageService._();
  static final SecureStorageService instance = SecureStorageService._();

  final _logger = Logger(printer: PrettyPrinter(methodCount: 0));

  // Android: EncryptedSharedPreferences backed by Keystore AES-256
  // iOS    : Keychain Services
  static const _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
    keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
    storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
  );

  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
    synchronizable: false, // Do NOT sync secrets to iCloud
  );

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: _androidOptions,
    iOptions: _iosOptions,
  );

  // ─── Key Constants ────────────────────────────────────────────────────────
  static const String _kDeezerToken        = 'bella_deezer_token';
  static const String _kDeezerUserId       = 'bella_deezer_user_id';
  static const String _kDeezerApiToken     = 'bella_deezer_api_token';
  static const String _kDeezerLicenseToken = 'bella_deezer_license_token';
  static const String _kDeezerPlaylists    = 'bella_deezer_playlists';
  static const String _kDeezerCookies      = 'bella_deezer_cookies';
  static const String _kAmazonToken        = 'bella_amazon_token';
  static const String _kAmazonPlaylists    = 'bella_amazon_playlists';
  static const String _kSpotifyToken       = 'bella_spotify_token';
  static const String _kTidalToken         = 'bella_tidal_token';
  static const String _kDeviceKey          = 'bella_device_key';
  static const String _kLastSpeakerIp      = 'bella_last_speaker_ip';

  // ─── Deezer ──────────────────────────────────────────────────────────────
  Future<void> saveDeezerToken(String token) async {
    await _storage.write(key: _kDeezerToken, value: token);
    _logger.i('Deezer token saved to secure storage.');
  }

  Future<String?> getDeezerToken() => _storage.read(key: _kDeezerToken);

  Future<void> saveDeezerUserId(String userId) async {
    await _storage.write(key: _kDeezerUserId, value: userId);
    _logger.i('Deezer USER_ID ($userId) saved to secure storage.');
  }

  Future<String?> getDeezerUserId() => _storage.read(key: _kDeezerUserId);

  Future<void> saveDeezerApiToken(String apiToken) async {
    await _storage.write(key: _kDeezerApiToken, value: apiToken);
  }

  Future<String?> getDeezerApiToken() => _storage.read(key: _kDeezerApiToken);

  Future<void> saveDeezerLicenseToken(String licenseToken) async {
    await _storage.write(key: _kDeezerLicenseToken, value: licenseToken);
    _logger.i('Deezer license_token saved to secure storage.');
  }

  Future<String?> getDeezerLicenseToken() => _storage.read(key: _kDeezerLicenseToken);

  Future<void> saveDeezerPlaylists(String jsonStr) async {
    await _storage.write(key: _kDeezerPlaylists, value: jsonStr);
    _logger.i('Deezer playlists cache saved to secure storage.');
  }

  Future<String?> getDeezerPlaylists() => _storage.read(key: _kDeezerPlaylists);

  Future<void> saveDeezerCookies(String cookies) async {
    await _storage.write(key: _kDeezerCookies, value: cookies);
  }

  Future<String?> getDeezerCookies() => _storage.read(key: _kDeezerCookies);

  Future<void> clearDeezer() async {
    await _storage.delete(key: _kDeezerToken);
    await _storage.delete(key: _kDeezerUserId);
    await _storage.delete(key: _kDeezerApiToken);
    await _storage.delete(key: _kDeezerLicenseToken);
    await _storage.delete(key: _kDeezerPlaylists);
    await _storage.delete(key: _kDeezerCookies);
    _logger.i('Deezer session cleared from secure storage.');
  }

  // ─── Amazon Music ─────────────────────────────────────────────────────────
  Future<void> saveAmazonToken(String token) async {
    await _storage.write(key: _kAmazonToken, value: token);
    _logger.i('Amazon token saved to secure storage.');
  }

  Future<String?> getAmazonToken() => _storage.read(key: _kAmazonToken);

  Future<void> saveAmazonPlaylists(String jsonStr) async {
    await _storage.write(key: _kAmazonPlaylists, value: jsonStr);
    _logger.i('Amazon playlists cache saved to secure storage.');
  }

  Future<String?> getAmazonPlaylists() => _storage.read(key: _kAmazonPlaylists);

  Future<void> clearAmazon() async {
    await _storage.delete(key: _kAmazonToken);
    await _storage.delete(key: _kAmazonPlaylists);
    _logger.i('Amazon session cleared from secure storage.');
  }

  // ─── Spotify ──────────────────────────────────────────────────────────────
  Future<void> saveSpotifyToken(String token) async {
    await _storage.write(key: _kSpotifyToken, value: token);
    _logger.i('Spotify token saved to secure storage.');
  }

  Future<String?> getSpotifyToken() => _storage.read(key: _kSpotifyToken);

  Future<void> clearSpotify() async {
    await _storage.delete(key: _kSpotifyToken);
    _logger.i('Spotify session cleared from secure storage.');
  }

  // ─── Tidal ────────────────────────────────────────────────────────────────
  Future<void> saveTidalToken(String token) async {
    await _storage.write(key: _kTidalToken, value: token);
    _logger.i('Tidal token saved to secure storage.');
  }

  Future<String?> getTidalToken() => _storage.read(key: _kTidalToken);

  Future<void> clearTidal() async {
    await _storage.delete(key: _kTidalToken);
    _logger.i('Tidal session cleared from secure storage.');
  }

  // ─── Device pairing key ───────────────────────────────────────────────────
  Future<void> saveDeviceKey(String key) =>
      _storage.write(key: _kDeviceKey, value: key);
  Future<String?> getDeviceKey() => _storage.read(key: _kDeviceKey);

  // ─── Last known speaker IP (cache) ────────────────────────────────────────
  Future<void> saveLastSpeakerIp(String ip) =>
      _storage.write(key: _kLastSpeakerIp, value: ip);
  Future<String?> getLastSpeakerIp() => _storage.read(key: _kLastSpeakerIp);

  // ─── Purge (logout) ───────────────────────────────────────────────────────
  Future<void> clearAll() async {
    await _storage.deleteAll();
    _logger.w('All secure storage cleared (logout).');
  }
}

