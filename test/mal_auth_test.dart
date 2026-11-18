import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:animego/core/auth/mal_auth_service.dart';
import 'package:animego/core/auth/mal_config.dart';
import 'package:animego/core/auth/mal_http_client.dart';
import 'package:animego/core/auth/mal_models.dart';
import 'package:animego/core/auth/mal_pkce.dart';
import 'package:animego/core/auth/mal_token_store.dart';

/// Penyimpanan token in-memory untuk test.
class _FakeTokenStore implements MalTokenStore {
  String? accessToken;
  String? refreshToken;
  DateTime? expiresAt;
  String? username;
  String? avatarUrl;
  String? pendingState;
  String? pendingVerifier;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required DateTime expiresAt,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
    this.expiresAt = expiresAt;
  }

  @override
  Future<String?> readAccessToken() async => accessToken;
  @override
  Future<String?> readRefreshToken() async => refreshToken;
  @override
  Future<DateTime?> readExpiresAt() async => expiresAt;
  @override
  Future<String?> readUsername() async => username;
  @override
  Future<String?> readAvatarUrl() async => avatarUrl;

  @override
  Future<void> saveProfile({
    required String username,
    String? avatarUrl,
  }) async {
    this.username = username;
    if (avatarUrl != null) this.avatarUrl = avatarUrl;
  }

  @override
  Future<void> savePendingLogin({
    required String state,
    required String codeVerifier,
  }) async {
    pendingState = state;
    pendingVerifier = codeVerifier;
  }

  @override
  Future<String?> readPendingState() async => pendingState;
  @override
  Future<String?> readPendingVerifier() async => pendingVerifier;

  @override
  Future<void> clearPendingLogin() async {
    pendingState = null;
    pendingVerifier = null;
  }

  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    expiresAt = null;
    username = null;
    avatarUrl = null;
    pendingState = null;
    pendingVerifier = null;
  }
}

void main() {
  group('MalPkce', () {
    test('verifier 64 karakter dan memakai alphabet URL-safe', () {
      final verifier = MalPkce.generateCodeVerifier();
      expect(verifier.length, 64);
      expect(
        RegExp(r'^[A-Za-z0-9\-._~]+$').hasMatch(verifier),
        isTrue,
      );
    });

    test('dua verifier berbeda (Random.secure dipakai)', () {
      final a = MalPkce.generateCodeVerifier();
      final b = MalPkce.generateCodeVerifier();
      expect(a, isNot(b));
    });

    test('challenge plain sama persis dengan verifier', () {
      final verifier = MalPkce.generateCodeVerifier();
      expect(MalPkce.codeChallenge(verifier), verifier);
    });
  });

  group('MalAuthService - konfigurasi', () {
    test('client id dan redirect URI sesuai permintaan admin', () {
      expect(MalConfig.clientId, 'ce597a0c988bf74f96472738fbb5e658');
      expect(MalConfig.redirectUri, 'animego://mal/cb');
    });

    test('authorize URL memakai plain PKCE dan redirect URI konsisten', () {
      final service = MalAuthService(
        tokenStore: _FakeTokenStore(),
        httpClient: MalHttpClient(client: MockClient((_) async => http.Response('{}', 200))),
      );
      final url = Uri.parse(
        service.buildAuthorizeUrl(codeVerifier: 'abc', state: 'st'),
      );
      expect(url.queryParameters['response_type'], 'code');
      expect(url.queryParameters['client_id'], MalConfig.clientId);
      expect(url.queryParameters['redirect_uri'], 'animego://mal/cb');
      expect(url.queryParameters['code_challenge_method'], 'plain');
      expect(url.queryParameters['code_challenge'], 'abc');
      expect(url.queryParameters['state'], 'st');
      expect(url.queryParameters['scope'], 'write:users');
    });
  });

  group('MalAuthService - parsing callback', () {
    test('menolak callback dengan state yang tidak cocok', () async {
      final store = _FakeTokenStore();
      final service = MalAuthService(
        tokenStore: store,
        httpClient: MalHttpClient(
          client: MockClient((_) async => http.Response('{}', 200)),
        ),
        launcher: ({required String url, required String callbackUrlScheme}) async {
          return 'animego://mal/cb?code=abc123&state=WRONG';
        },
      );

      await expectLater(
        service.login(),
        throwsA(
          isA<MalAuthException>().having(
            (e) => e.message,
            'message',
            contains('state tidak cocok'),
          ),
        ),
      );
      // Code tidak boleh ditukar bila state gagal validasi.
      expect(store.accessToken, isNull);
    });

    test('menolak callback error=access_denied', () async {
      final store = _FakeTokenStore();
      final service = MalAuthService(
        tokenStore: store,
        httpClient: MalHttpClient(
          client: MockClient((_) async => http.Response('{}', 200)),
        ),
        launcher: ({required String url, required String callbackUrlScheme}) async {
          return 'animego://mal/cb?error=access_denied&state=whatever';
        },
      );

      await expectLater(
        service.login(),
        throwsA(
          isA<MalAuthException>().having(
            (e) => e.message,
            'message',
            contains('ditolak'),
          ),
        ),
      );
      expect(store.accessToken, isNull);
    });

    test('parseCallback membaca code, state, dan error', () {
      final ok = MalAuthService.parseCallback(
        'animego://mal/cb?code=xyz&state=abc',
      );
      expect(ok.code, 'xyz');
      expect(ok.state, 'abc');
      expect(ok.hasError, isFalse);

      final denied = MalAuthService.parseCallback(
        'animego://mal/cb?error=access_denied',
      );
      expect(denied.hasError, isTrue);
      expect(denied.error, 'access_denied');
    });
  });

  group('MalAuthService - tukar code', () {
    test('pertukaran code menyimpan access dan refresh token', () async {
      final store = _FakeTokenStore();
      final requests = <http.Request>[];

      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.toString() == MalConfig.tokenUrl) {
          return http.Response(
            jsonEncode({
              'access_token': 'access-1',
              'refresh_token': 'refresh-1',
              'expires_in': 3600,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({
            'id': 42,
            'name': 'Anime Fan',
            'user_name': 'animefan',
            'picture': 'https://cdn.myanimelist.net/avatar.jpg',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = MalAuthService(
        tokenStore: store,
        httpClient: MalHttpClient(client: client),
        launcher: ({required String url, required String callbackUrlScheme}) async {
          return 'animego://mal/cb?code=code-1&state=${store.pendingState}';
        },
      );

      final user = await service.login();

      expect(user.username, 'animefan');
      expect(store.accessToken, 'access-1');
      expect(store.refreshToken, 'refresh-1');
      expect(store.username, 'animefan');

      final tokenRequest = requests.first;
      expect(tokenRequest.method, 'POST');
      expect(tokenRequest.bodyFields['grant_type'], 'authorization_code');
      expect(tokenRequest.bodyFields['client_id'], MalConfig.clientId);
      expect(tokenRequest.bodyFields['redirect_uri'], 'animego://mal/cb');
      expect(tokenRequest.bodyFields['code'], 'code-1');
      expect(tokenRequest.bodyFields['code_verifier'], isNotEmpty);

      // code hanya ditukar sekali
      expect(store.pendingVerifier, isNull);
    });
  });

  group('MalAuthService - refresh otomatis', () {
    test('access token expired di-refresh otomatis', () async {
      final store = _FakeTokenStore()
        ..accessToken = 'old-access'
        ..refreshToken = 'refresh-1'
        ..expiresAt = DateTime.now().subtract(const Duration(minutes: 5));

      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'access_token': 'new-access',
            'refresh_token': 'new-refresh',
            'expires_in': 3600,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = MalAuthService(
        tokenStore: store,
        httpClient: MalHttpClient(client: client),
      );

      final token = await service.getValidAccessToken();

      expect(token, 'new-access');
      expect(store.accessToken, 'new-access');
      expect(store.refreshToken, 'new-refresh');
    });

    test('access token yang masih dipakai apa adanya', () async {
      final store = _FakeTokenStore()
        ..accessToken = 'still-valid'
        ..refreshToken = 'refresh-1'
        ..expiresAt = DateTime.now().add(const Duration(hours: 1));

      final service = MalAuthService(
        tokenStore: store,
        httpClient: MalHttpClient(
          client: MockClient((_) async => http.Response('{}', 200)),
        ),
      );

      expect(await service.getValidAccessToken(), 'still-valid');
    });

    test('refresh gagal -&gt; error 401 agar UI mengarahkan login', () async {
      final store = _FakeTokenStore()
        ..accessToken = 'old-access'
        ..refreshToken = 'refresh-1'
        ..expiresAt = DateTime.now().subtract(const Duration(minutes: 5));

      final service = MalAuthService(
        tokenStore: store,
        httpClient: MalHttpClient(
          client: MockClient(
            (_) async => http.Response('{"error":"invalid_grant"}', 400),
          ),
        ),
      );

      await expectLater(
        service.getValidAccessToken(),
        throwsA(
          isA<MalAuthException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });
  });

  group('MalAuthService - profil', () {
    test('mengambil profil dari /v2/users/@me dengan bearer token', () async {
      final store = _FakeTokenStore()
        ..accessToken = 'access-1'
        ..expiresAt = DateTime.now().add(const Duration(hours: 1));

      Uri? seen;
      final client = MockClient((request) async {
        seen = request.url;
        expect(request.headers['Authorization'], 'Bearer access-1');
        return http.Response(
          jsonEncode({
            'id': 7,
            'name': 'Anime Fan',
            'user_name': 'animefan',
            'picture': 'https://cdn.myanimelist.net/avatar.jpg',
            'anime_statistics': {'count_anime': 12},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = MalAuthService(
        tokenStore: store,
        httpClient: MalHttpClient(client: client),
      );

      final user = await service.getCurrentUser();

      expect(
        seen.toString(),
        startsWith('https://api.myanimelist.net/v2/users/@me'),
      );
      expect(user.username, 'animefan');
      expect(user.id, 7);
      expect(user.animeCount, 12);
      expect(store.username, 'animefan');
    });

    test('logout menghapus seluruh credential', () async {
      final store = _FakeTokenStore()
        ..accessToken = 'access-1'
        ..refreshToken = 'refresh-1'
        ..expiresAt = DateTime.now()
        ..username = 'animefan';

      final service = MalAuthService(
        tokenStore: store,
        httpClient: MalHttpClient(
          client: MockClient((_) async => http.Response('{}', 200)),
        ),
      );

      await service.logout();

      expect(store.accessToken, isNull);
      expect(store.refreshToken, isNull);
      expect(store.username, isNull);
    });
  });
}
