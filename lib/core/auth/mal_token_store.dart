import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Kontrak penyimpanan token MAL.
///
/// Dipisah dari implementasi agar test bisa memakai penyimpanan in-memory
/// tanpa plugin native. Implementasi produksi HARUS memakai
/// [MalSecureTokenStore] (Android Keystore / iOS Keychain).
abstract class MalTokenStore {
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required DateTime expiresAt,
  });

  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<DateTime?> readExpiresAt();
  Future<String?> readUsername();
  Future<String?> readAvatarUrl();

  Future<void> saveProfile({required String username, String? avatarUrl});

  Future<void> savePendingLogin({
    required String state,
    required String codeVerifier,
  });

  Future<String?> readPendingState();
  Future<String?> readPendingVerifier();
  Future<void> clearPendingLogin();

  Future<void> clear();
}

/// Penyimpanan aman untuk token MAL.
///
/// Token TIDAK BOLEH disimpan di SharedPreferences maupun dicetak ke log.
class MalSecureTokenStore implements MalTokenStore {
  MalSecureTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions.defaultOptions,
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  final FlutterSecureStorage _storage;

  static const String _kAccessToken = 'mal_access_token';
  static const String _kRefreshToken = 'mal_refresh_token';
  static const String _kExpiresAt = 'mal_expires_at';
  static const String _kUsername = 'mal_username';
  static const String _kAvatarUrl = 'mal_avatar_url';
  static const String _kPendingState = 'mal_pending_state';
  static const String _kPendingVerifier = 'mal_pending_verifier';

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required DateTime expiresAt,
  }) async {
    await _storage.write(key: _kAccessToken, value: accessToken);
    await _storage.write(key: _kRefreshToken, value: refreshToken);
    await _storage.write(
      key: _kExpiresAt,
      value: expiresAt.millisecondsSinceEpoch.toString(),
    );
  }

  @override
  Future<String?> readAccessToken() => _storage.read(key: _kAccessToken);

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _kRefreshToken);

  @override
  Future<DateTime?> readExpiresAt() async {
    final raw = await _storage.read(key: _kExpiresAt);
    if (raw == null) return null;
    final ms = int.tryParse(raw);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  @override
  Future<String?> readUsername() => _storage.read(key: _kUsername);

  @override
  Future<String?> readAvatarUrl() => _storage.read(key: _kAvatarUrl);

  @override
  Future<void> saveProfile({
    required String username,
    String? avatarUrl,
  }) async {
    await _storage.write(key: _kUsername, value: username);
    if (avatarUrl != null) {
      await _storage.write(key: _kAvatarUrl, value: avatarUrl);
    }
  }

  @override
  Future<void> savePendingLogin({
    required String state,
    required String codeVerifier,
  }) async {
    await _storage.write(key: _kPendingState, value: state);
    await _storage.write(key: _kPendingVerifier, value: codeVerifier);
  }

  @override
  Future<String?> readPendingState() => _storage.read(key: _kPendingState);

  @override
  Future<String?> readPendingVerifier() =>
      _storage.read(key: _kPendingVerifier);

  @override
  Future<void> clearPendingLogin() async {
    await _storage.delete(key: _kPendingState);
    await _storage.delete(key: _kPendingVerifier);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
    await _storage.delete(key: _kExpiresAt);
    await _storage.delete(key: _kUsername);
    await _storage.delete(key: _kAvatarUrl);
    await _storage.delete(key: _kPendingState);
    await _storage.delete(key: _kPendingVerifier);
  }
}
