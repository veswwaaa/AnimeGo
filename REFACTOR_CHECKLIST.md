# AnimeGo — Refactor Checklist (Mobile / Flutter)

> Fase 1 (selesai): **Rapikan struktur folder & file** — tanpa mengubah logika bisnis.
> Fase 2 (berikutnya): Implementasi **Provider System** (REST + client-side scraper, DTO seragam).

Status legend: `[x]` selesai · `[ ]` belum · `[-]` ditunda

---

## Fase 1 — Struktur Folder & File

| # | Task | Status | Catatan |
|---|------|--------|---------|
| 1.1 | Audit struktur `lib/` + `test/` + dependensi import | [x] | 38 file dart, 17 dir |
| 1.2 | Tentukan target struktur folder | [x] | `app.dart` / `core/` / `features/` / `legacy/` |
| 1.3 | Pindahkan `lib/example-demo-apk/core` -> `lib/core` (git mv) | [x] | history git terjaga |
| 1.4 | Pindahkan `lib/example-demo-apk/features` -> `lib/features` (git mv) | [x] | |
| 1.5 | `ani-stream-app.dart` -> `lib/app.dart` | [x] | |
| 1.6 | File legacy root -> `lib/legacy/` (`api_config`, `api_sevice`, `home`, `media-kit-player`, `balsf.txt`) | [x] | tidak di-import app utama, aman diisolasi |
| 1.7 | Hapus folder `lib/example-demo-apk/` | [x] | prefix `example-demo-apk` hilang total |
| 1.8 | Rewrite import path `package:animego/example-demo-apk/...` -> `package:animego/...` | [x] | 18 file (15 lib + 2 test + app/main) |
| 1.9 | Verifikasi tidak ada sisa referensi `example-demo-apk` | [x] | grep bersih |
| 1.10 | Buat `lib/core/dto/` (api_envelope, anime_dto, episode_dto, stream_dto) | [x] | kontrak data canonical |
| 1.11 | Buat `lib/core/providers/` (anime_provider, provider_registry, barrel) | [x] | interface + manager, implementasi menyusul |
| 1.12 | Buat `lib/core/repositories/` (anime_repository, barrel) | [x] | kontrak REST-like |
| 1.13 | Update barrel `lib/core/utils/utils.dart` | [x] | export dto/providers/repositories |
| 1.14 | `flutter analyze` | [x] | 0 error, 70 info/warning (pre-existing) |
| 1.15 | `flutter test` | [x] | 14/14 lulus |
| 1.16 | Ganti `widget_test.dart` (counter default -> smoke test app root) | [x] | test lama memang sudah gagal pre-refactor |

---

## Struktur Folder Sekarang

```
lib/
├── main.dart
├── app.dart                    # root widget (dari ani-stream-app.dart)
├── core/
│   ├── config/                 # api_config.dart, logs.json
│   ├── dto/                    # BARU: kontrak data canonical
│   │   ├── api_envelope.dart
│   │   ├── anime_dto.dart
│   │   ├── episode_dto.dart
│   │   └── stream_dto.dart
│   ├── models/                 # anime.dart, watch_history_item.dart
│   ├── providers/              # BARU: kontrak provider + registry
│   │   ├── anime_provider.dart
│   │   ├── provider_registry.dart
│   │   └── providers.dart
│   ├── repositories/           # BARU: kontrak repository
│   │   ├── anime_repository.dart
│   │   └── repositories.dart
│   ├── services/               # anime_api_service.dart (legacy REST)
│   └── utils/                  # http_client, logger, image, hive, utils(barrel)
├── features/                   # screen per fitur (data/ + presentation/)
│   ├── anime-detail-screen/
│   ├── anime-video-player-screen/
│   ├── developer-screen/
│   ├── history-screen/
│   ├── home-screen/
│   ├── main-navigation/
│   ├── profile-screen/
│   └── search-screen/
└── legacy/                     # file lama yang tidak dipakai app
    ├── api_config.dart
    ├── api_sevice.dart
    ├── home.dart
    ├── media-kit-player.dart
    └── balsf.txt
```

---

## Temuan Audit (untuk Fase 2)

| Temuan | Dampak | Ticket |
|--------|--------|--------|
| 3 pola sumber data tanpa kontrak bersama (REST nimegami, REST zoronime, scraping otakudesu) | source of utama "berantakan" | F2.1 |
| `Anime` model tidak punya penanda provider | UI tak tahu anime dari provider mana | F2.1 |
| `Anime` punya `synopsis` default hardcoded JJK + `dummyAnimes` di file model | data dummy bocor ke production | F2.2 |
| `searchAnime` melakukan N+1 (search -> detail per item) | 1 + N request | F2.3 |
| `http_client.dart` & `otakudesu-search.dart` punya 2 implementasi retry/header | inkonsistensi header | F2.4 |
| Parsing HTML jalan di UI thread (belum ada `compute()`/Isolate) | jank | F2.5 |
| `http.get` tanpa User-Agent browser | beberapa situs/CDN tolak | F2.6 |
| `anime-detail-screen/data/function.dart` punya `switch(server)` + fungsi duplikat | duplikasi | F2.7 |
| Streaming video bespoke per provider, tidak ada `StreamSource` unified | sulit tambah provider | F2.8 |
| `api_config.dart` masih hardcode ke Vercel | ketergantungan server | F2.9 |
| `anime-detail-screen/data/function.dart` duplicate import + unused variable | warning analyze | F2.10 |

---

## Fase 2 — Provider System (BELUM DIMULAI)

### F2.1 Kontrak & Model
- [x] `AnimeDto` dipakai di UI + mapper `anime_mapper.dart`
- [ ] `EpisodeDto` & `StreamDto` dipakai di detail screen & player
- [ ] Tambah `providerId` pada identitas anime (format `provider:localId`)
- [x] Field `Anime` lama tetap ada + `providerId`

### F2.2 Kebersihan Data
- [x] Dipindah ke `lib/core/models/dummy_animes.dart`
- [x] Synopsis default generik + file model bebas dummy
- [x] `Anime` jadi immutable

### F2.3 Performa
- [x] N+1 dihilangkan di Nimegami/Zoronime search (fallback ringkas)
- [ ] Cache hasil search di Hive

### F2.4 HTTP Layer
- [x] Disatukan di `http_client.dart`; helper duplikat di otakudesu-search dihapus
- [x] `kDefaultBrowserHeaders` dipakai semua request
- [x] Bungkus parsing HTML di `compute()` (Isolate) — `otakudesu-parse.dart` + `compute()` di search/episodes/detail/mirror

### F2.5 Implementasi Provider
- [x] `OtakudesuProvider` (bungkus `otakudesu-search/episodes/video` yang sudah ada)
- [x] `NimegamiProvider` (port dari `anime-api/src/nimegami`)
- [x] `ZoronimeProvider` (port dari `anime-api/src/zoronime`)
- [ ] `AnimapleProvider` (HTTP ke API luar)
- [x] Registry default + urutan prioritas + fallback berurutan

### F2.6 Repository
- [ ] `RestAnimeRepository` (HTTP ke `anime-api`)
- [x] `ProviderAnimeRepository` (adapter registry -> `ApiEnvelope`)
- [ ] `HybridAnimeRepository` (fallback REST <-> scrap)
- [x] UI pakai repository, bukan fungsi dataa langsung

### F2.7 Anti-Break
- [ ] Remote Config (GitHub Gist JSON) untuk CSS selector
- [ ] Fallback ke selector bawaan saat fetch config gagal

### F2.8 Kualitas
- [ ] Test unit per provider (fixture HTML)
- [ ] Test repository fallback
- [ ] Hilangkan warning analyze yang tersisa
- [x] Rapikan indentasi (2-space -> 4-space di `otakudesu-*.dart`) — `dart format` full project


---

## Fase 2 — Status Update (terakhir)

- `flutter analyze` → **0 error, 0 warning** (71 info pre-existing).
- `flutter test` → **19/19 lulus** (termasuk `test/provider_system_test.dart`).
- `lib/core/services/anime_api_service.dart` → dipensiunkan ke `lib/legacy/` (import diperbaiki).
- Duplicate HTTP helper `_httpGetWithHeaders` di `otakudesu-search.dart` dihapus, kini pakai `httpGetWithRetry`.
- `provider_container.dart` & `utils.dart` dibersihkan dari unused import / dangling doc comment.
