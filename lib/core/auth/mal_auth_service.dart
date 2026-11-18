import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../mappers/mal_mapper.dart';
import 'mal_config.dart';
import 'mal_http_client.dart';
import 'mal_models.dart';
import 'mal_pkce.dart';
import 'mal_token_store.dart';

/// Fungsi pembuka browser OAuth. Dipisah agar bisa di-fake saat test.
typedef MalBrowserLauncher = Future<String> Function({
  required String url,
  required String callbackUrlScheme,
});

/// Hasil parsing callback OAuth.
class MalCallback {
  const MalCallback._({this.code, this.error, this.state});

  final String? code;
  final String? error;
  final String? state;

  bool get hasError => error != null;
}

/// Orkestrasi alur OAuth2 MyAnimeList.
///
/// Tahapan:
/// 1. `login()` membuat code_verifier + state, menyimpan keduanya di secure
///    storage, lalu membuka browser OAuth.
/// 2. Callback `animego://mal/cb?code=...&state=...` ditangkap, diverifikasi
///    terhadap state, lalu ditukar menjadi access_token + refresh_token.
/// 3. `getValidAccessToken()` otomatis me-refresh bila access token expire.
/// 4. `getCurrentUser()` mengambil profil dari `/v2/users/@me`.
class MalAuthService {
  MalAuthService({
    MalTokenStore? tokenStore,
    MalHttpClient? httpClient,
    MalBrowserLauncher? launcher,
    Random? random,
  })  : _store = tokenStore ?? MalSecureTokenStore(),
        _http = httpClient ?? MalHttpClient(),
        _launcher = launcher ?? _defaultLauncher,
        _random = random ?? Random.secure();

  final MalTokenStore _store;
  final MalHttpClient _http;
  final MalBrowserLauncher _launcher;
  final Random _random;

  static Future<String> _defaultLauncher({
    required String url,
    required String callbackUrlScheme,
  }) async {
    return FlutterWebAuth2.authenticate(
      url: url,
      callbackUrlScheme: callbackUrlScheme,
    );
  }

  /// Parse callback URL dari browser. Dipisah agar mudah diuji.
  static MalCallback parseCallback(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return const MalCallback._(error: 'invalid_callback');
    }
    final params = uri.queryParameters;
    return MalCallback._(
      code: params['code'],
      error: params['error'],
      state: params['state'],
    );
  }

  /// Alur login lengkap.
  ///
  /// Mengembalikan profil user MAL setelah token berhasil disimpan.
  Future<MalUser> login() async {
    final verifier = MalPkce.generateCodeVerifier(_random);
    final state = _randomState();

    await _store.savePendingLogin(state: state, codeVerifier: verifier);

    final authUrl = buildAuthorizeUrl(
      codeVerifier: verifier,
      state: state,
    );

    final callbackUrl = await _launcher(
      url: authUrl,
      callbackUrlScheme: MalConfig.callbackUrlScheme,
    );

    final callback = parseCallback(callbackUrl);

    if (callback.hasError) {
      await _store.clearPendingLogin();
      throw MalAuthException(
        callback.error == 'access_denied'
            ? 'Akses ditolak oleh MyAnimeList.'
            : 'Login MyAnimeList gagal: ${callback.error}',
      );
    }

    final code = callback.code;
    if (code == null || code.isEmpty) {
      await _store.clearPendingLogin();
      throw const MalAuthException('Kode otorisasi tidak ditemukan.');
    }

    final expectedState = await _store.readPendingState();
    if (expectedState == null || expectedState != callback.state) {
      await _store.clearPendingLogin();
      throw const MalAuthException(
        'Validasi login gagal (state tidak cocok). Silakan coba lagi.',
      );
    }

    final storedVerifier = await _store.readPendingVerifier();
    await _store.clearPendingLogin();
    if (storedVerifier == null || storedVerifier.isEmpty) {
      throw const MalAuthException('Sesi login tidak ditemukan. Coba lagi.');
    }

    await exchangeCode(code: code, codeVerifier: storedVerifier);
    return getCurrentUser();
  }

  /// Tukar authorization code menjadi access + refresh token.
  @visibleForTesting
  Future<void> exchangeCode({
    required String code,
    required String codeVerifier,
  }) async {
    final data = await _http.postForm(MalConfig.tokenUrl, {
      'client_id': MalConfig.clientId,
      'grant_type': 'authorization_code',
      'code': code,
      'code_verifier': codeVerifier,
      'redirect_uri': MalConfig.redirectUri,
    });

    final accessToken = data['access_token'];
    final refreshToken = data['refresh_token'];
    if (accessToken is! String || accessToken.isEmpty) {
      throw const MalAuthException('MyAnimeList tidak mengembalikan access token.');
    }

    final expiresIn = data['expires_in'] is num
        ? (data['expires_in'] as num).toInt()
        : 3600;

    await _store.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken is String ? refreshToken : '',
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
    );
  }

  /// Ambil access token yang valid; refresh otomatis bila perlu.
  Future<String> getValidAccessToken() async {
    final accessToken = await _store.readAccessToken();
    final expiresAt = await _store.readExpiresAt();

    final stillValid = accessToken != null &&
        accessToken.isNotEmpty &&
        expiresAt != null &&
        expiresAt.isAfter(DateTime.now().add(MalConfig.refreshLeeway));

    if (stillValid) return accessToken;

    final refreshed = await refreshAccessToken();
    if (refreshed != null && refreshed.isNotEmpty) return refreshed;

    throw const MalAuthException(
      'Sesi MyAnimeList berakhir. Silakan login kembali.',
      statusCode: 401,
    );
  }

  /// Refresh access token memakai refresh token.
  @visibleForTesting
  Future<String?> refreshAccessToken() async {
    final refreshToken = await _store.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return null;

    try {
      final data = await _http.postForm(MalConfig.tokenUrl, {
        'client_id': MalConfig.clientId,
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
      });

      final accessToken = data['access_token'];
      if (accessToken is! String || accessToken.isEmpty) return null;

      final expiresIn = data['expires_in'] is num
          ? (data['expires_in'] as num).toInt()
          : 3600;
      final newRefresh = data['refresh_token'] is String
          ? data['refresh_token'] as String
          : refreshToken;

      await _store.saveTokens(
        accessToken: accessToken,
        refreshToken: newRefresh,
        expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
      );
      return accessToken;
    } on MalAuthException {
      return null;
    }
  }

  /// Ambil profil user MAL (username dipakai sebagai display name di Profile).
  Future<MalUser> getCurrentUser() async {
    final token = await getValidAccessToken();
    final json = await _http.getJson(
      MalConfig.userInfoUrl,
      MalConfig.apiHeaders(token),
    );
    final user = MalMapper.user(json);
    await _store.saveProfile(
      username: user.username,
      avatarUrl: user.avatarUrl,
    );
    return user;
  }

  /// Hapus seluruh data MAL dari perangkat.
  Future<void> logout() => _store.clear();

  /// Username tersimpan (untuk render cepat tanpa memanggil API).
  Future<String?> cachedUsername() => _store.readUsername();

  /// Status login saat app dibuka.
  Future<bool> isLoggedIn() async {
    final token = await _store.readAccessToken();
    return token != null && token.isNotEmpty;
  }

  /// URL authorize OAuth2 MAL (ekspos untuk testing).
  @visibleForTesting
  String buildAuthorizeUrl({
    required String codeVerifier,
    required String state,
  }) {
    return Uri.parse(MalConfig.authorizeUrl).replace(
      queryParameters: {
        'response_type': 'code',
        'client_id': MalConfig.clientId,
        'code_challenge': MalPkce.codeChallenge(codeVerifier),
        'code_challenge_method':
            MalPkce.usePlainChallenge ? 'plain' : 'S256',
        'redirect_uri': MalConfig.redirectUri,
        'scope': MalConfig.scope,
        'state': state,
      },
    ).toString();
  }

  String _randomState() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
