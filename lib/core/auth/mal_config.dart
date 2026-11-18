/// Konfigurasi OAuth2 MyAnimeList (MAL).
///
/// Semua konstanta vendor dipusatkan di satu file sehingga perpindahan flow
/// (plain -> S256) atau peny和弦 ke backend BFF cukup mengubah file ini.
class MalConfig {
  const MalConfig._();

  /// Client ID aplikasi AnimeGo (public client, tanpa `client_secret`).
  static const String clientId = 'ce597a0c988bf74f96472738fbb5e658';

  /// Redirect URI yang didaftarkan di MAL Developer Console.
  /// Harus identik saat `authorize` DAN saat tukar `code`.
  static const String redirectUri = 'animego://mal/cb';

  /// Scheme untuk menangkap callback lewat flutter_web_auth_2.
  static const String callbackUrlScheme = 'animego';

  /// Scope `write:users` mencakup read profil + write list status/score.
  static const String scope = 'write:users';

  static const String authorizeUrl = 'https://myanimelist.net/v1/oauth2/authorize';
  static const String tokenUrl = 'https://myanimelist.net/v1/oauth2/token';
  static const String userInfoUrl =
      'https://api.myanimelist.net/v2/users/@me?fields=user_name';

  /// MAL API v2 memerlukan header `X-MAL-CLIENT-ID` selain Authorization.
  static Map<String, String> apiHeaders(String accessToken) => {
        'Authorization': 'Bearer $accessToken',
        'X-MAL-CLIENT-ID': clientId,
        'Accept': 'application/json',
      };

  /// Refresh diproses bila access token akan expire dalam window ini.
  static const Duration refreshLeeway = Duration(seconds: 60);
}
