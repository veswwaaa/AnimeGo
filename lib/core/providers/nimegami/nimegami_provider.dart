import 'dart:convert';

import 'package:animego/core/config/api_config.dart';
import 'package:animego/core/dto/anime_dto.dart';
import 'package:animego/core/dto/api_envelope.dart';
import 'package:animego/core/dto/api_v2_dto.dart';
import 'package:animego/core/dto/api_v2_mapper.dart';
import 'package:animego/core/dto/episode_dto.dart';
import 'package:animego/core/dto/stream_dto.dart';
import 'package:animego/core/providers/rest_provider_base.dart';
import 'package:animego/core/utils/http_client.dart';
import 'package:animego/core/utils/image_utils.dart';
import 'package:animego/core/providers/nimegami/nimegami_schedules.dart';

/// Provider Nimegami (REST canonical v2).
///
/// Migrasi (lihat `docs/NIMEGAMI_V2_MIGRATION.md`):
/// - search   -> `GET /api/v2/nimegami/search`
/// - detail   -> `GET /api/v2/nimegami/detail` (detail + episode list,
///   satu call)
/// - episode  -> `GET /api/v2/nimegami/episode?url=&eps=` (metadata episode
///   + streamUrl dalam satu envelope)
///
/// Fallback ke route legacy `/api/nimegami/*` otomatis kalau backend v2
/// belum ter-deploy (flag internal `_v2Unavailable`).
class NimegamiProvider extends RestProviderBase {
  NimegamiProvider({super.client, super.random});

  static const String providerId = 'nimegami';

  /// Cache episode list hasil `/detail` atau `/episodes`.
  /// Key = URL halaman anime.
  final Map<String, List<EpisodeDto>> _episodeCache = <String, List<EpisodeDto>>{};

  /// Cache detail anime (dipakai `getEpisodes` agar tidak memanggil
  /// backend dua kali saat user membuka halaman detail lalu episode list).
  final Map<String, AnimeDto> _detailCache = <String, AnimeDto>{};

  /// Cache stream per (animeUrl, nomor episode), TTL 5 menit.
  final Map<String, _CachedStream> _streamCache = <String, _CachedStream>{};

  /// True kalau endpoint v2 tidak tersedia di backend yang sedang dipakai.
  bool _v2Unavailable = false;

  @override
  String get id => providerId;

  @override
  String get displayName => 'Nimegami';

  @override
  bool get supportsSearch => true;

  @override
  bool get supportsDetail => true;

  @override
  bool get supportsEpisodes => true;

  @override
  bool get supportsStream => true;

  @override
  bool get supportsSchedules => true;

  @override
  Future<List<AnimeDto>> getSchedules() async {
    return fetchNimegamiSchedules(baseUrl: baseUrl);
  }

  @override
  String get baseUrl => apiBaseUrl;

  /// Legacy route nimegami masih memakai base64 untuk param `url`.
  @override
  ParamEncoding get paramEncoding => ParamEncoding.base64;

  @override
  Map<String, String> get extraHeaders => const <String, String>{};

  /* ------------------------------- Search ------------------------------- */

  @override
  Future<List<AnimeDto>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const <AnimeDto>[];

    if (!_v2Unavailable) {
      try {
        return await _searchV2(trimmed);
      } on _V2UnavailableException {
        // Turun ke legacy di bawah.
      }
    }

    return _searchLegacy(trimmed);
  }

  Future<List<AnimeDto>> _searchV2(String query) async {
    final json = await _v2Get(
      '/api/v2/$providerId/search',
      <String, String>{'q': query, 'page': '1', 'limit': '20'},
      timeout: const Duration(seconds: 45),
    );

    final envelope = parseApiV2Envelope<ApiSearchResponse>(
      json,
      ApiSearchResponse.fromJson,
    );
    _throwIfEnvelopeFailed(envelope);

    final data = envelope.data;
    if (data == null) return const <AnimeDto>[];

    // Tidak ada N+1 lagi: item search sudah berisi url + metadata ringkas.
    return data.items
        .map(animeDtoFromApiSearchItem)
        .toList(growable: false);
  }

  Future<List<AnimeDto>> _searchLegacy(String query) async {
    final normalized = _normalizeQuery(query);
    final uri = Uri.parse(
      '$baseUrl/api/$providerId/search',
    ).replace(queryParameters: {'q': normalized});

    final response = await get(
      uri.toString(),
      timeout: const Duration(seconds: 45),
      maxAttempts: 2,
    );

    if (response.statusCode != 200) {
      throw ProviderHttpException(
        'Search Nimegami gagal dengan status ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);
    final items = _legacyItems(decoded);
    if (items.isEmpty) return const <AnimeDto>[];

    // Hindari N+1: ambil detail hanya jika data ringkas tidak cukup.
    final results = <AnimeDto>[];
    for (final item in items) {
      final sourceUrl = _firstNonEmpty(item, const <String>[
        'sourceUrl',
        'url',
      ]);
      final title = _titleOf(item);

      if (sourceUrl.isEmpty) {
        results.add(_fallbackDto(item, title));
        continue;
      }

      try {
        results.add(await getDetail(sourceUrl));
      } catch (_) {
        results.add(_fallbackDto(item, title));
      }
    }

    return results;
  }

  /* ------------------------------- Detail ------------------------------- */

  @override
  Future<AnimeDto> getDetail(String sourceUrl) async {
    final trimmed = sourceUrl.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('sourceUrl kosong');
    }

    final cached = _detailCache[trimmed];
    if (cached != null) return cached;

    if (!_v2Unavailable) {
      try {
        return await _getDetailV2(trimmed);
      } on _V2UnavailableException {
        // Turun ke legacy di bawah.
      }
    }

    return _getDetailLegacy(trimmed);
  }

  Future<AnimeDto> _getDetailV2(String sourceUrl) async {
    final json = await _v2Get(
      '/api/v2/$providerId/detail',
      <String, String>{
        'url': sourceUrl,
        'includeEpisodes': 'true',
      },
      timeout: const Duration(seconds: 45),
    );

    final envelope = parseApiV2Envelope<ApiAnimeDetail>(
      json,
      ApiAnimeDetail.fromJson,
    );
    _throwIfEnvelopeFailed(envelope);

    final detail = envelope.data;
    if (detail == null) {
      throw ProviderHttpException(
        'Detail Nimegami kosong',
        statusCode: 404,
        retryable: false,
      );
    }

    final dto = animeDtoFromApiDetail(detail);
    _detailCache[sourceUrl] = dto;

    final episodes = detail.episodes
        .map(episodeDtoFromApiEpisode)
        .toList(growable: false);
    if (episodes.isNotEmpty) {
      _episodeCache[sourceUrl] = episodes;
    }

    return dto;
  }

  Future<AnimeDto> _getDetailLegacy(String sourceUrl) async {
    final uri = Uri.parse(
      '$baseUrl/api/$providerId/anime',
    ).replace(queryParameters: {'url': encodeParam(sourceUrl)});

    final response = await get(
      uri.toString(),
      timeout: const Duration(seconds: 45),
      maxAttempts: 2,
    );

    if (response.statusCode != 200) {
      throw ProviderHttpException(
        'Detail Nimegami gagal dengan status ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Detail Nimegami response bukan object');
    }

    final payload = decoded['name'] is Map<String, dynamic>
        ? decoded['name'] as Map<String, dynamic>
        : decoded;

    final title = _titleOf(payload);
    final images = payload['images'];
    final image = images is Map<String, dynamic>
        ? extractBestImageUrl(images, fallbackTitle: title)
        : normalizeAnimeImageUrl(
            payload['imageUrl']?.toString(),
            fallbackTitle: title,
          );

    final score = payload['score'] ?? payload['rating'];
    final rating = score is num
        ? score.toDouble()
        : double.tryParse('$score') ?? 0.0;

    final totalEpisodes = parseEpisodeCount(
      payload['last_episode'] ?? payload['episodes'],
    );

    final resolvedUrl = _firstNonEmpty(payload, const <String>['sourceUrl']);
    final resolved = resolvedUrl.isEmpty ? sourceUrl : resolvedUrl;

    final dto = AnimeDto(
      id: AnimeId(providerId, resolved),
      provider: providerId,
      title: title,
      image: image,
      description: _firstNonEmpty(payload, const <String>['synopsis']),
      genres: _parseGenres(payload['genres']),
      status: _statusOf(payload),
      rating: rating,
      totalEpisodes: totalEpisodes,
      url: resolved,
      episodeListUrl: resolved,
      extra: <String, dynamic>{'source': providerId},
    );
    _detailCache[sourceUrl] = dto;
    return dto;
  }

  /* ------------------------------ Episodes ------------------------------ */

  @override
  Future<List<EpisodeDto>> getEpisodes(String sourceUrl) async {
    final trimmed = sourceUrl.trim();
    if (trimmed.isEmpty) return const <EpisodeDto>[];

    final cached = _episodeCache[trimmed];
    if (cached != null && cached.isNotEmpty) return cached;

    if (!_v2Unavailable) {
      try {
        final episodes = await _getEpisodesV2(trimmed);
        if (episodes.isNotEmpty) {
          _episodeCache[trimmed] = episodes;
          return episodes;
        }
      } on _V2UnavailableException {
        // Turun ke legacy di bawah.
      }
    }

    return _getEpisodesLegacy(trimmed);
  }

  Future<List<EpisodeDto>> _getEpisodesV2(String sourceUrl) async {
    final json = await _v2Get(
      '/api/v2/$providerId/episodes',
      <String, String>{'url': sourceUrl},
      timeout: const Duration(seconds: 45),
    );

    final envelope = parseApiV2Envelope<ApiEpisodeListResponse>(
      json,
      ApiEpisodeListResponse.fromJson,
    );
    _throwIfEnvelopeFailed(envelope);

    final data = envelope.data;
    if (data == null) return const <EpisodeDto>[];

    return data.episodes
        .map(episodeDtoFromApiEpisode)
        .toList(growable: false);
  }

  Future<List<EpisodeDto>> _getEpisodesLegacy(String sourceUrl) async {
    final detail = await getDetail(sourceUrl);
    final total = detail.totalEpisodes ?? 0;
    final animeId = detail.id;

    return List<EpisodeDto>.generate(
      total,
      (index) => EpisodeDto(
        id: AnimeId(providerId, '${animeId.localId}#${index + 1}'),
        animeId: animeId,
        number: index + 1,
        url: detail.url,
      ),
      growable: false,
    );
  }

  /* ------------------------------- Stream ------------------------------- */

  @override
  Future<StreamDto> getStreamUrl(EpisodeDto episode) async {
    final sourceUrl = (episode.url ?? '').trim();
    if (sourceUrl.isEmpty) {
      throw const FormatException('Episode tanpa URL tidak bisa diputar');
    }

    final cacheKey = '$sourceUrl#${episode.number}';
    final cached = _streamCache[cacheKey];
    if (cached != null && !cached.isExpired) return cached.value;

    if (!_v2Unavailable) {
      try {
        final stream = await _getStreamV2(sourceUrl, episode);
        _streamCache[cacheKey] = _CachedStream(stream);
        return stream;
      } on _V2UnavailableException {
        // Turun ke legacy di bawah.
      }
    }

    return _getStreamLegacy(sourceUrl, episode);
  }

  Future<StreamDto> _getStreamV2(String sourceUrl, EpisodeDto episode) async {
    final json = await _v2Get(
      '/api/v2/$providerId/episode',
      <String, String>{'url': sourceUrl, 'eps': '${episode.number}'},
      timeout: const Duration(seconds: 60),
    );

    final envelope = parseApiV2Envelope<ApiEpisodeDetail>(
      json,
      ApiEpisodeDetail.fromJson,
    );
    _throwIfEnvelopeFailed(envelope);

    final detail = envelope.data;
    if (detail == null) {
      throw ProviderHttpException(
        'Episode ${episode.number} tidak ditemukan',
        statusCode: 404,
        retryable: false,
      );
    }

    final streamUrl = detail.streamUrl ?? detail.streamUrl720pdefaultserver;
    if (streamUrl == null || streamUrl.isEmpty) {
      throw ProviderHttpException(
        'Stream tidak tersedia untuk episode ini',
        statusCode: 404,
        retryable: false,
      );
    }

    final animeId = AnimeId.parse(detail.animeId) ??
        AnimeId(providerId, _localIdFromUrl(sourceUrl));

    final mirrors = detail.server
        .map(
          (server) => StreamMirror(
            url: streamUrl,
            label: server.name.isEmpty ? null : server.name,
            quality: server.quality,
          ),
        )
        .toList(growable: false);

    return StreamDto(
      episodeId: AnimeId(providerId, '${animeId.localId}#${episode.number}'),
      type: streamUrl.contains('.m3u8') ? 'hls' : 'direct',
      url: streamUrl,
      mirrors: mirrors,
    );
  }

  Future<StreamDto> _getStreamLegacy(
    String sourceUrl,
    EpisodeDto episode,
  ) async {
    final uri = Uri.parse('$baseUrl/api/$providerId/media').replace(
      queryParameters: {
        'url': encodeParam(sourceUrl),
        'eps': '${episode.number}',
      },
    );

    final response = await get(
      uri.toString(),
      timeout: const Duration(seconds: 60),
      maxAttempts: 2,
    );

    if (response.statusCode != 200) {
      throw ProviderHttpException(
        'Media Nimegami gagal dengan status ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);
    final direct = _extractMediaUrl(decoded);
    if (direct.isEmpty) {
      throw ProviderHttpException('Media Nimegami tidak mengembalikan URL');
    }

    return StreamDto(
      episodeId: episode.id,
      type: direct.contains('.m3u8') ? 'hls' : 'direct',
      url: direct,
    );
  }

  /* --------------------------- HTTP v2 helper --------------------------- */

  /// GET endpoint v2 dan kembalikan JSON body.
  ///
  /// Melempar [_V2UnavailableException] kalau route v2 tidak ada (backend
  /// lama belum ter-deploy), supaya caller bisa fallback ke route legacy.
  Future<Map<String, dynamic>> _v2Get(
    String path,
    Map<String, String> query, {
    required Duration timeout,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);

    final response = await get(
      uri.toString(),
      timeout: timeout,
      maxAttempts: 2,
    );

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      decoded = null;
    }

    if (decoded is! Map<String, dynamic>) {
      // Body bukan JSON: route v2 belum ada di backend yang aktif.
      _v2Unavailable = true;
      throw _V2UnavailableException(
        'Endpoint v2 $path tidak tersedia (status ${response.statusCode})',
      );
    }

    final errorJson = decoded['error'];
    if (errorJson is Map<String, dynamic> &&
        errorJson['code']?.toString() == 'NOT_SUPPORTED') {
      _v2Unavailable = true;
      throw const _V2UnavailableException(
        'Provider nimegami belum mendukung endpoint v2 ini',
      );
    }

    if (response.statusCode >= 500) {
      _v2Unavailable = true;
      throw _V2UnavailableException(
        'Endpoint v2 $path gagal dengan status ${response.statusCode}',
      );
    }

    return decoded;
  }

  void _throwIfEnvelopeFailed<T>(ApiV2Envelope<T> envelope) {
    if (envelope.isSuccess) return;

    final error = envelope.error;
    throw ProviderHttpException(
      error?.message ?? 'Permintaan ke backend v2 gagal',
      statusCode: error?.status,
      retryable: error?.retryable ?? false,
    );
  }

  /* ------------------------------- Utils -------------------------------- */

  /// Ambil list item dari payload legacy (list polos ATAU envelope).
  List<Map<String, dynamic>> _legacyItems(dynamic decoded) {
    if (decoded is List) {
      return decoded.whereType<Map<String, dynamic>>().toList();
    }
    if (decoded is Map<String, dynamic>) {
      final data = decoded['data'];
      if (data is List) {
        return data.whereType<Map<String, dynamic>>().toList();
      }
      final items = decoded['items'];
      if (items is List) {
        return items.whereType<Map<String, dynamic>>().toList();
      }
    }
    return const <Map<String, dynamic>>[];
  }

  /// Turunkan `localId` dari URL anime, sama seperti backend
  /// (`anime-api/src/shared/identity.ts` -> `localIdFromUrl`).
  String _localIdFromUrl(String url) {
    var withoutFragment = url.split('#').first;
    withoutFragment = withoutFragment.split('?').first;

    var segment = '';
    try {
      final parsed = Uri.parse(withoutFragment);
      final parts = parsed.pathSegments.where((part) => part.isNotEmpty).toList();
      segment = parts.isNotEmpty ? parts.last : '';
    } catch (_) {
      final parts = withoutFragment.split('/').where((part) => part.isNotEmpty);
      segment = parts.isNotEmpty ? parts.last : '';
    }

    try {
      segment = Uri.decodeComponent(segment);
    } catch (_) {
      // biarkan segment apa adanya.
    }

    segment = segment
        .replaceFirst(RegExp(r'\.(html?|php|aspx?|jsp)$', caseSensitive: false), '')
        .replaceFirst(
          RegExp(r'[-_]?sub[-_]?(?:indo|indonesia)[-_]?\d*$', caseSensitive: false),
          '',
        )
        .trim()
        .toLowerCase();

    return segment.isEmpty ? url : segment;
  }

  AnimeDto _fallbackDto(Map<String, dynamic> item, String title) {
    final sourceUrl = _firstNonEmpty(item, const <String>['sourceUrl', 'url']);
    return AnimeDto(
      id: AnimeId(providerId, sourceUrl.isEmpty ? title : sourceUrl),
      provider: providerId,
      title: title,
      image: normalizeAnimeImageUrl(
        item['imageUrl']?.toString(),
        fallbackTitle: title,
      ),
      description: _firstNonEmpty(item, const <String>['synopsis']),
      genres: _parseGenres(item['genres']),
      rating: _parseRating(item['rating']),
      totalEpisodes: parseEpisodeCount(item['episodes']),
      url: sourceUrl.isEmpty ? null : sourceUrl,
      episodeListUrl: sourceUrl.isEmpty ? null : sourceUrl,
      extra: <String, dynamic>{'source': providerId, 'partial': true},
    );
  }

  double _parseRating(dynamic raw) {
    if (raw is num) return raw.toDouble();
    return double.tryParse('$raw') ?? 0.0;
  }

  List<String> _parseGenres(dynamic rawGenres) {
    if (rawGenres is! List) return const <String>['Unknown'];
    final genres = rawGenres
        .map((genre) {
          if (genre is Map<String, dynamic>) {
            return genre['name']?.toString().trim() ?? '';
          }
          return genre?.toString().trim() ?? '';
        })
        .where((genre) => genre.isNotEmpty)
        .toList();
    return genres.isEmpty ? const <String>['Unknown'] : genres;
  }

  String _titleOf(Map<String, dynamic> payload) {
    final value = _firstNonEmpty(payload, const <String>['title', 'name']);
    return value.isEmpty ? 'Untitled Anime' : value;
  }

  String _statusOf(Map<String, dynamic> payload) {
    final value = _firstNonEmpty(payload, const <String>['status']);
    return value.isEmpty ? 'Unknown' : value;
  }

  String _firstNonEmpty(Map<String, dynamic> payload, List<String> keys) {
    for (final key in keys) {
      final value = payload[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _normalizeQuery(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[\[\](){}]'), ' ')
        .replaceAllMapped(
          RegExp(r'\b(\d+)(st|nd|rd|th)\b'),
          (match) => match.group(1)!,
        )
        .replaceAll(RegExp(r'[-_]'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _extractMediaUrl(dynamic decoded) {
    if (decoded is String) return decoded.trim();
    if (decoded is! Map<String, dynamic>) return '';
    final direct = _firstNonEmpty(decoded, const <String>[
      'url',
      'videoUrl',
      'streamUrl',
    ]);
    if (direct.isNotEmpty) return direct;
    final data = decoded['data'];
    if (data is Map<String, dynamic>) {
      return _firstNonEmpty(data, const <String>[
        'url',
        'videoUrl',
        'streamUrl',
      ]);
    }
    return '';
  }
}

/// Penanda internal: endpoint v2 tidak tersedia -> fallback ke legacy.
class _V2UnavailableException implements Exception {
  const _V2UnavailableException(this.message);

  final String message;

  @override
  String toString() => 'V2Unavailable: $message';
}

/// Entry cache stream dengan TTL.
class _CachedStream {
  _CachedStream(this.value) : cachedAt = DateTime.now();

  final StreamDto value;
  final DateTime cachedAt;

  static const Duration ttl = Duration(minutes: 5);

  bool get isExpired => DateTime.now().difference(cachedAt) > ttl;
}
