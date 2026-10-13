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
  static const String _kDeezerToken   = 'bella_deezer_token';
  static const String _kAmazonToken   = 'bella_amazon_token';
  static const String _kDeviceKey     = 'bella_device_key';
  static const String _kLastSpeakerIp = 'bella_last_speaker_ip';

  // ─── Deezer ──────────────────────────────────────────────────────────────
  Future<void> saveDeezerToken(String token) async {
    await _storage.write(key: _kDeezerToken, value: token);
    _logger.i('Deezer token saved to secure storage.');
  }

  Future<String?> getDeezerToken() => _storage.read(key: _kDeezerToken);

  // ─── Amazon Music ─────────────────────────────────────────────────────────
  Future<void> saveAmazonToken(String token) async {
    await _storage.write(key: _kAmazonToken, value: token);
    _logger.i('Amazon token saved to secure storage.');
  }

  Future<String?> getAmazonToken() => _storage.read(key: _kAmazonToken);

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

