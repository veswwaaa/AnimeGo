# Migrasi Provider Nimegami ke REST v2 (search / detail / episode)

Diterbitkan oleh SystemDesign. Implementasi: @khususMobileApp.
Base URL backend: `apiBaseUrl` (`lib/core/config/api_config.dart`).

## 1. File yang diubah

| File | Perubahan |
|---|---|
| `lib/core/dto/api_v2_dto.dart` | Tambah `ApiEpisodeServer`, `ApiEpisodeDetail`, field additive `episodes` + `type` pada `ApiAnimeDetail`. |
| `lib/core/providers/nimegami/nimegami_provider.dart` | Ganti 3 call legacy ke v2. |

Dilarang mengubah bentuk `AnimeDto`, `EpisodeDto`, `StreamDto`, `ApiEnvelope`, `AnimeProvider`, `ProviderRegistry` (additive saja).

## 2. Kontrak endpoint

Base: `{apiBaseUrl}/api/v2/nimegami/...`

### 2.1 Search
`GET /api/v2/nimegami/search?q={query}&page=1&limit=20`
Response `ApiEnvelope<ApiSearchResponse>`:
- `data.items[]` = { id, provider, title, image, description, genres[], status, rating, year, totalEpisodes, url }
- `data.query` = query ternormalisasi
- `meta` = { provider, page, limit, totalItems, totalPages, hasNextPage, ... }

`id` komposit `nimegami:<localId>`; `url` = URL halaman anime (tanpa anchor).

### 2.2 Detail (+ daftar episode dalam 1 call)
`GET /api/v2/nimegami/detail?url={url anime}&includeEpisodes=true&refresh=false`
Response `ApiEnvelope<ApiAnimeDetail>`:
- `data` = { id, provider, title, alternativeTitle, image, description, genres[], status, type, rating, year, totalEpisodes, url, episodeListUrl, episodes[], extra{} }
- `data.episodes[]` = { id, animeId, provider, number, title, url, airingDate, extra{} }
- `data.extra.metadataSource` = jikan | scraped | unavailable (unavailable = Jikan down, success tetap true)

Error 4xx/5xx juga envelope: { success:false, data:null, meta, error:{ code, message, provider, retryable, status } }

### 2.3 Episode singular (metadata episode + streamUrl dalam 1 call)
`GET /api/v2/nimegami/episode?url={url anime}&eps={number}`
WAJIB kirim `eps`. Jangan andalkan anchor `#episode_N`.

Response `ApiEnvelope<ApiEpisodeDetail>`:
- `data` = ApiEpisode + additive: `animeUrl`, `streamUrl` (null itu NORMAL), `streamUrl720pdefaultserver`, `server[]` = { name, mediaId, quality }, `kualitas[]`

Episode tidak ada = HTTP 404 + `error.code = NOT_FOUND`, `retryable=false`.

## 3. Pemetaan ke DTO internal

- search items -> `animeDtoFromApiSearchItem()` (sudah ada di api_v2_mapper.dart). Hapus N+1 loop getDetail per item.
- detail -> `animeDtoFromApiDetail()` (sudah ada). Simpan `data.episodes` ke cache internal provider (animeUrl -> List<EpisodeDto>).
- episodes -> `episodeDtoFromApiEpisode()` (sudah ada). Fallback kalau `episodes` kosong: synthesais dari totalEpisodes (id `provider:localId#N`).
- episode+stream -> StreamDto:
  - episodeId = AnimeId(provider, '<animeLocalId>#<number>')
  - url = streamUrl, fallback streamUrl720pdefaultserver; dua-duanya null -> throw ProviderHttpException
  - type = url.contains('.m3u8') ? 'hls' : 'direct'
  - mirrors boleh dari server[] (label=name, quality=quality)
  - headers {}, expiresAt null

## 4. Aturan implementasi di NimegamiProvider

1. paramEncoding tetap base64 untuk param url (backend menerima plain & base64). Kalau ragu kirim plain.
2. Semua response dibaca lewat `parseApiV2Envelope<T>(json, decode)`.
   - envelope.isSuccess false -> throw ProviderHttpException(message, statusCode: error.status)
   - HTTP non-200 -> tetap coba parse envelope; gagal parse -> ProviderHttpException dengan status code.
3. getStreamUrl(episode): episode.url = URL anime. Panggil `/episode?url=<episode.url>&eps=<episode.number>`. Jangan panggil /stream lama untuk nimegami. Cache hasil stream per (animeUrl, eps) 5 menit.
4. getEpisodes(sourceUrl): pakai cache detail kalau ada; fallback `GET /api/v2/nimegami/episodes?url=` -> ApiEpisodeListResponse.
5. getDetail(sourceUrl): `GET /api/v2/nimegami/detail?url=` -> animeDtoFromApiDetail, lalu isi cache episode list.
6. search: `GET /api/v2/nimegami/search?q=` -> ApiSearchResponse -> map items.
7. Timeout: search 45s, detail 45s, episode 60s, maxAttempts 2.

## 5. Edge case

| Kasus | Perilaku |
|---|---|
| Jikan down | success:true, extra.metadataSource=unavailable, field metadata null, jangan error |
| Episode tidak ada | 404 NOT_FOUND -> ProviderHttpException "Episode N tidak ditemukan" |
| streamUrl null | Episode sukses; saat play pesan "Stream tidak tersedia untuk episode ini", jangan crash |
| Backend v2 belum deploy | Fallback ke route legacy /api/nimegami/*, guard flag v2Unavailable; parser legacy menerima list maupun envelope |
| url kosong | FormatException('sourceUrl kosong') |

Fallback legacy WAJIB ada karena v2 belum deploy ke kevinapienim.vercel.app (backend baru masih lokal).

## 6. Acceptance criteria

- flutter analyze bersih, flutter test hijau.
- Flow manual: search "naruto" -> detail -> episode list -> play episode 1.
- Provider otakudesu & zoronime tidak berubah.
- Semua field baru nullable/optional.

