import 'package:animego/core/auth/mal_auth_service.dart';
import 'package:animego/core/auth/mal_gateway_impl.dart';
import 'package:animego/core/auth/mal_http_client.dart';
import 'package:animego/core/auth/mal_models.dart';
import 'package:animego/core/auth/mal_token_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Penyimpanan token in-memory untuk test.
class _FakeTokenStore implements MalTokenStore {
  String? accessToken = 'token';
  String? refreshToken = 'refresh';
  DateTime? expiresAt = DateTime.now().add(const Duration(hours: 1));

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required DateTime expiresAt,
  }) async {}

  @override
  Future<String?> readAccessToken() async => accessToken;
  @override
  Future<String?> readRefreshToken() async => refreshToken;
  @override
  Future<DateTime?> readExpiresAt() async => expiresAt;
  @override
  Future<String?> readUsername() async => null;
  @override
  Future<String?> readAvatarUrl() async => null;

  @override
  Future<void> saveProfile({
    required String username,
    String? avatarUrl,
  }) async {}

  @override
  Future<void> savePendingLogin({
    required String state,
    required String codeVerifier,
  }) async {}

  @override
  Future<String?> readPendingState() async => null;
  @override
  Future<String?> readPendingVerifier() async => null;
  @override
  Future<void> clearPendingLogin() async {}

  @override
  Future<void> clear() async {}
}

void main() {
  group('MalGatewayImpl - endpoint list MAL v2', () {
    late List<http.Request> requests;

    MalGatewayImpl buildGateway() {
      requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response('{}', 200);
      });
      final auth = MalAuthService(
        tokenStore: _FakeTokenStore(),
        httpClient: MalHttpClient(client: client),
      );
      return MalGatewayImpl(
        authService: auth,
        httpClient: MalHttpClient(client: client),
      );
    }

    test('upsert memakai PUT /v2/anime/{id}/my_list_status', () async {
      final gateway = buildGateway();

      await gateway.upsert(
        malAnimeId: 21,
        status: MalListStatus.watching,
        numWatchedEpisodes: 3,
      );

      expect(requests.length, 1);
      final request = requests.single;
      expect(request.method, 'PUT');
      expect(
        request.url.toString(),
        'https://api.myanimelist.net/v2/anime/21/my_list_status',
      );
      expect(request.body, contains('status=watching'));
      expect(request.body, contains('num_watched_episodes=3'));
    });

    test('upsert mengirim status sebagai string yang valid', () async {
      final gateway = buildGateway();

      await gateway.upsert(
        malAnimeId: 21,
        status: MalListStatus.completed,
      );

      expect(requests.single.body, contains('status=completed'));
    });

    test('delete memakai DELETE /v2/anime/{id}/my_list_status', () async {
      final gateway = buildGateway();

      await gateway.delete(21);

      expect(requests.length, 1);
      final request = requests.single;
      expect(request.method, 'DELETE');
      expect(
        request.url.toString(),
        'https://api.myanimelist.net/v2/anime/21/my_list_status',
      );
    });

    test('tidak lagi memakai route lama /v2/users/@me/animelist/{id}', () async {
      final gateway = buildGateway();

      await gateway.upsert(malAnimeId: 21, status: MalListStatus.watching);
      await gateway.delete(21);

      for (final request in requests) {
        expect(request.url.path, isNot(contains('/users/@me/animelist/')));
      }
    });
  });
}
