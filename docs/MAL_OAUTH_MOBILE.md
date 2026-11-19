# Integrasi OAuth2 MyAnimeList (MAL) - Mobile

Implementasi login MAL **langsung di aplikasi Flutter** (public client, tanpa
`client_secret`). Backend `anime-api` belum tersentuh pada fase ini.

## Konfigurasi

| Item | Nilai |
| --- | --- |
| Client ID | `ce597a0c988bf74f96472738fbb5e658` |
| Redirect URI | `animego://mal/cb` |
| Scope | `write:users` |
| Authorize | `https://myanimelist.net/v1/oauth2/authorize` |
| Token | `https://myanimelist.net/v1/oauth2/token` |
| User info | `https://api.myanimelist.net/v2/users/@me` |

## Flow

1. `MalAuthService.login()` membuat `code_verifier` 64 karakter memakai
   `Random.secure()` dan `state` acak.
2. PKCE memakai `code_challenge_method=plain` (MAL belum mendukung S256),
   sehingga `code_challenge` == `code_verifier`.
3. Browser dibuka lewat `flutter_web_auth_2` dengan callback scheme `animego`.
4. Callback `animego://mal/cb?code=...&state=...` divalidasi terhadap
   `state`; mismatch atau `error=access_denied` langsung ditolak.
5. Code ditukar sekali (`grant_type=authorization_code`) menjadi access token +
   refresh token, disimpan di `flutter_secure_storage`.
6. `getValidAccessToken()` me-refresh otomatis bila access token hampir
   expire; kegagalan refresh menghasilkan error 401 agar UI mengarahkan
   login ulang.
7. `getCurrentUser()` mengambil profil dari `/v2/users/@me`; username MAL
   dipakai sebagai display name di Profile dengan badge "MyAnimeList".
8. `logout()` menghapus seluruh credential dari secure storage.

## Struktur file

- `lib/core/auth/mal_config.dart` - konstanta vendor.
- `lib/core/auth/mal_pkce.dart` - generator verifier + challenge.
- `lib/core/auth/mal_token_store.dart` - interface `MalTokenStore` +
  implementasi `flutter_secure_storage`.
- `lib/core/auth/mal_http_client.dart` - HTTP client (POST/PUT/DELETE/GET).
- `lib/core/auth/mal_auth_service.dart` - orkestrasi OAuth.
- `lib/core/auth/mal_gateway.dart` - kontrak akses data MAL.
- `lib/core/auth/mal_gateway_impl.dart` - implementasi gateway.
- `lib/core/auth/mal_auth_provider.dart` - state UI login.
- `lib/core/auth/mal_auth_scope.dart` - provider scope.
- `lib/core/auth/mal_di.dart` - DI sederhana.
- `lib/core/mappers/mal_mapper.dart` - normalisasi response vendor.
- `lib/features/auth/presentation/mal-login-section.dart` - panel login di Profile.
- `lib/features/auth/presentation/mal-login-screen.dart` - halaman login penuh.

## Konfigurasi native

Android (`android/app/src/main/AndroidManifest.xml`) memakai intent-filter
`animego://mal/cb`. iOS (`ios/Runner/Info.plist`) mendaftarkan custom URL
scheme `animego`.

## Endpoint list (bukan OAuth)

- Update: `PUT https://api.myanimelist.net/v2/users/@me/animelist/{anime_id}`
- Delete: `DELETE https://api.myanimelist.net/v2/users/@me/animelist/{anime_id}`

## Validasi

- `flutter analyze lib test`: 0 error, 0 warning (74 info pre-existing).
- `flutter test`: 65/65 lulus, termasuk test callback state salah,
  `access_denied`, code exchange, automatic refresh, mapping `/v2/users/@me`,
  dan logout.

## Catatan

- Console MAL harus berada di mode **authorization code** (bukan implicit),
  dan redirect URI `animego://mal/cb` harus terdaftar.
- Token tidak pernah dicetak ke log dan tidak disimpan di SharedPreferences.

## Sinkronisasi progress tonton (80%)

Fitur otomatis: saat durasi video yang diputar mencapai **80%**, episode
tersebut otomatis masuk ke list MyAnimeList dengan `status=watching` dan
`num_watched_episodes` sesuai nomor episode.

Syarat:
- User sudah login MyAnimeList (sesi MAL valid).
- Anime punya `malId` dari backend kontrak v2 (kalau null, fitur dimatikan
  diam-diam tanpa error).

Implementasi:
- `lib/core/auth/mal_watch_sync_service.dart` — trigger + idempotensi per
  (anime, episode) agar tidak menembak rate limit 60 req/menit MAL.
- Memakai `MalGateway.upsert()` (HTTP `PUT`), tidak ada request HTTP
  langsung dari feature layer.
- Dipicu dari `_player.stream.position` di
  `anime-video-player-screen.dart`; tidak ada perubahan tampilan/UI.
