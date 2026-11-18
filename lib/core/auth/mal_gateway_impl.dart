import '../mappers/mal_mapper.dart';
import 'mal_auth_service.dart';
import 'mal_config.dart';
import 'mal_gateway.dart';
import 'mal_http_client.dart';
import 'mal_models.dart';

/// Implementasi [MalGateway] yang talks directly ke MyAnimeList API.
///
/// Hanya kelas ini yang tahu bentuk JSON vendor; seluruh feature cukup
/// bergantung pada DTO di [mal_models.dart].
class MalGatewayImpl implements MalGateway {
  MalGatewayImpl({required MalAuthService authService, MalHttpClient? httpClient})
      : _auth = authService,
        _http = httpClient ?? MalHttpClient();

  final MalAuthService _auth;
  final MalHttpClient _http;

  static const String _listUrl =
      'https://api.myanimelist.net/v2/users/@me/animelist';

  @override
  Future<MalUser> login() => _auth.login();

  @override
  Future<MalUser> me() => _auth.getCurrentUser();

  @override
  Future<List<MalListEntry>> getList({int limit = 100, int offset = 0}) async {
    final token = await _auth.getValidAccessToken();
    final uri = Uri.parse(_listUrl).replace(
      queryParameters: {
        'fields': 'list_status',
        'limit': '$limit',
        'offset': '$offset',
        'ns': 'false',
      },
    );
    final json = await _http.getJson(uri.toString(), MalConfig.apiHeaders(token));
    return MalMapper.list(json);
  }

  /// Update status/score list MAL memakai HTTP verb `PUT`.
  @override
  Future<void> upsert({
    required int malAnimeId,
    required int status,
    int? score,
    int? numWatchedEpisodes,
  }) async {
    final token = await _auth.getValidAccessToken();
    final body = <String, String>{
      'status': '$status',
      if (score != null) 'score': '$score',
      if (numWatchedEpisodes != null)
        'num_watched_episodes': '$numWatchedEpisodes',
    };
    await _http.putForm(
      '$_listUrl/$malAnimeId',
      body,
      headers: MalConfig.apiHeaders(token),
    );
  }

  /// Hapus anime dari list MAL memakai HTTP verb `DELETE`.
  @override
  Future<void> delete(int malAnimeId) async {
    final token = await _auth.getValidAccessToken();
    await _http.deleteJson(
      '$_listUrl/$malAnimeId',
      MalConfig.apiHeaders(token),
    );
  }

  @override
  Future<void> logout() => _auth.logout();

  @override
  Future<String?> cachedUsername() => _auth.cachedUsername();

  @override
  Future<bool> isLoggedIn() => _auth.isLoggedIn();
}
