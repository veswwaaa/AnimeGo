import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:animego/core/config/api_config.dart';
import 'package:animego/core/dto/anime_dto.dart';
import 'package:animego/core/dto/api_envelope.dart';
import 'package:animego/core/dto/api_v2_dto.dart';
import 'package:animego/core/dto/api_v2_mapper.dart';
import 'package:animego/core/dto/episode_dto.dart';
import 'package:animego/core/dto/stream_dto.dart';
import 'package:animego/core/providers/rest_provider_base.dart';
import 'package:animego/core/utils/http_client.dart';

/// Provider Nimegami, **hanya** lewat REST canonical v2.
///
/// Endpoint yang dipakai (semua `/api/v2/nimegami/*`):
/// - search   -> `GET /api/v2/nimegami/search?q=&page=1&limit=20`
/// - detail   -> `GET /api/v2/nimegami/detail?url=&includeEpisodes=true`
/// - episodes -> `GET /api/v2/nimegami/episodes?url=`
/// - episode  -> `GET /api/v2/nimegami/episode?url=&eps=N`
///
/// Tidak ada fallback ke route legacy `/api/nimegami/*`: jalur v1 sudah
/// dihapus supaya hanya ada satu sumber kebenaran.
class NimegamiProviderV2 extends RestProviderBase {
  NimegamiProviderV2({super.client, super.random});

  static const String providerId = 'nimegami';

  /// Cache episode list, key = `localId` anime.
  final Map<String, List<EpisodeDto>> _episodeCache = <String, List<EpisodeDto>>{};

  /// Cache detail anime, key = `localId` anime.
  final Map<String, AnimeDto> _detailCache = <String, AnimeDto>{};

  /// Cache stream, key = `localId#nomorEpisode`, TTL 5 menit.
  final Map<String, _CachedStream> _streamCache = <String, _CachedStream>{};

  /// Peta `localId -> URL halaman anime`, diisi dari hasil search/detail.
  ///
  /// Dipakai supaya `detail`/`episodes` tetap bisa dipanggil dengan
  /// `provider:localId` walau cache repository sudah hilang (mis. setelah
  /// app restart), tanpa mengubah kontrak repository.
  final Map<String, String> _urlByLocalId = <String, String>{};

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

  /// Kontrak v2 tidak menyediakan endpoint jadwal rilis.
  @override
  bool get supportsSchedules => false;

  @override
  String get baseUrl => apiBaseUrl;

  /// Parameter `url` pada v2 dikirim plain (di-encode oleh `Uri`).
  @override
  ParamEncoding get paramEncoding => ParamEncoding.plain;

  @override
  Map<String, String> get extraHeaders => const <String, String>{};

  /* ------------------------------- Search ------------------------------- */

  @override
  Future<List<AnimeDto>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const <AnimeDto>[];

    final json = await _v2Get(
      '/api/v2/$providerId/search',
      <String, String>{'q': trimmed, 'page': '1', 'limit': '20'},
      timeout: const Duration(seconds: 45),
    );

    final envelope = parseApiV2Envelope<ApiSearchResponse>(
      json,
      ApiSearchResponse.fromJson,
    );
    _throwIfEnvelopeFailed(envelope);

    final data = envelope.data;
    if (data == null) return const <AnimeDto>[];

    // Tidak ada N+1: item search sudah membawa `id` komposit + `url` penuh.
    final results = <AnimeDto>[];
    for (final item in data.items) {
      final dto = animeDtoFromApiSearchItem(item);
      final url = dto.url;
      if (url != null && url.isNotEmpty) {
        _urlByLocalId[dto.id.localId] = url;
      }
      results.add(dto);
    }
    return results;
  }

  /* ------------------------------- Detail ------------------------------- */

  @override
  Future<AnimeDto> getDetail(String sourceUrl) async {
    final url = _resolveUrl(sourceUrl);
    final localId = _localIdFromUrl(url);

    final cached = _detailCache[localId];
    if (cached != null) return cached;

    final json = await _v2Get(
      '/api/v2/$providerId/detail',
      <String, String>{'url': url, 'includeEpisodes': 'true'},
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
    _detailCache[localId] = dto;

    final episodes = detail.episodes
        .map(episodeDtoFromApiEpisode)
        .toList(growable: false);
    if (episodes.isNotEmpty) {
      _episodeCache[localId] = episodes;
    }

    final detailUrl = dto.url;
    if (detailUrl != null && detailUrl.isNotEmpty) {
      _urlByLocalId[dto.id.localId] = detailUrl;
    }

    return dto;
  }

  /* ------------------------------ Episodes ------------------------------ */

  @override
  Future<List<EpisodeDto>> getEpisodes(String sourceUrl) async {
    final url = _resolveUrl(sourceUrl);
    final localId = _localIdFromUrl(url);

    final cached = _episodeCache[localId];
    if (cached != null && cached.isNotEmpty) return cached;

    final json = await _v2Get(
      '/api/v2/$providerId/episodes',
      <String, String>{'url': url},
      timeout: const Duration(seconds: 45),
    );

    final envelope = parseApiV2Envelope<ApiEpisodeListResponse>(
      json,
      ApiEpisodeListResponse.fromJson,
    );
    _throwIfEnvelopeFailed(envelope);

    final data = envelope.data;
    if (data == null) return const <EpisodeDto>[];

    final episodes = data.episodes
        .map(episodeDtoFromApiEpisode)
        .toList(growable: false);
    if (episodes.isNotEmpty) {
      _episodeCache[localId] = episodes;
    }
    return episodes;
  }

  /* ------------------------------- Stream ------------------------------- */

  @override
  Future<StreamDto> getStreamUrl(EpisodeDto episode) async {
    final url = _resolveUrl(episode.url ?? '');
    final localId = _localIdFromUrl(url);
    final eps = episode.number <= 0 ? 1 : episode.number;

    final cacheKey = '$localId#$eps';
    final cached = _streamCache[cacheKey];
    if (cached != null && !cached.isExpired) return cached.value;

    final json = await _v2Get(
      '/api/v2/$providerId/episode',
      <String, String>{'url': url, 'eps': '$eps'},
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
        'Episode $eps tidak ditemukan',
        statusCode: 404,
        retryable: false,
      );
    }

    // Fallback berurutan: streamUrlDefaultServer -> streamUrl.
    final primary = (detail.streamUrlDefaultServer ?? '').trim();
    final fallback = (detail.streamUrl ?? '').trim();
    final resolvedUrl = primary.isNotEmpty
        ? primary
        : (fallback.isNotEmpty ? fallback : '');

    if (resolvedUrl.isEmpty) {
      throw ProviderHttpException(
        'Stream tidak tersedia untuk episode $eps',
        statusCode: 404,
        retryable: false,
      );
    }

    final defaultLabel = (detail.defaultServerName ?? '').trim();
    final defaultQuality = (detail.defaultQuality ?? '').trim();
    final mirrors = detail.server
        .map(
          (server) => StreamMirror(
            url: resolvedUrl,
            label: server.name.isNotEmpty
                ? server.name
                : (defaultLabel.isNotEmpty ? defaultLabel : null),
            quality: (server.quality ?? '').isNotEmpty
                ? server.quality
                : (defaultQuality.isNotEmpty ? defaultQuality : null),
          ),
        )
        .toList(growable: false);

    final stream = StreamDto(
      episodeId: AnimeId(providerId, '$localId#$eps'),
      type: resolvedUrl.contains('.m3u8') ? 'hls' : 'direct',
      url: resolvedUrl,
      mirrors: mirrors,
    );

    _streamCache[cacheKey] = _CachedStream(stream);
    return stream;
  }

  /* --------------------------- HTTP v2 helper --------------------------- */

  /// GET endpoint v2 dan kembalikan body JSON sebagai map.
  ///
  /// Semua kegagalan dinormalisasi jadi [ProviderHttpException] supaya
  /// layer UI bisa menampilkan pesan yang jelas (tidak pernah blank).
  Future<Map<String, dynamic>> _v2Get(
    String path,
    Map<String, String> query, {
    required Duration timeout,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);

    final http.Response response;
    try {
      response = await get(
        uri.toString(),
        timeout: timeout,
        maxAttempts: 2,
      );
    } on ProviderHttpException {
      rethrow;
    } on SocketException {
      throw const ProviderHttpException(
        'Tidak bisa menghubungi server Nimegami. Periksa koneksi internet Anda.',
        retryable: true,
      );
    } on http.ClientException {
      throw const ProviderHttpException(
        'Tidak bisa menghubungi server Nimegami. Periksa koneksi internet Anda.',
        retryable: true,
      );
    } on TimeoutException {
      throw const ProviderHttpException(
        'Server Nimegami terlalu lama merespons. Silakan coba lagi.',
        retryable: true,
      );
    } catch (error) {
      throw ProviderHttpException(
        'Gagal memuat data dari server Nimegami: $error',
        retryable: true,
      );
    }

    Map<String, dynamic> decoded;
    try {
      final raw = jsonDecode(response.body);
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Body bukan object');
      }
      decoded = raw;
    } catch (_) {
      throw ProviderHttpException(
        'Respons server Nimegami tidak valid (status ${response.statusCode}).',
        statusCode: response.statusCode,
        retryable: response.statusCode >= 500,
      );
    }

    // Pesan error dari envelope dipakai apa adanya bila ada.
    final errorJson = decoded['error'];
    if (errorJson is Map<String, dynamic>) {
      final code = errorJson['code']?.toString() ?? '';
      final message = errorJson['message']?.toString() ?? '';
      final status = _asInt(errorJson['status']) ?? response.statusCode;

      if (code == ApiErrorCode.notFound || status == 404) {
        throw ProviderHttpException(
          message.isEmpty ? 'Anime tidak ditemukan' : message,
          statusCode: 404,
          retryable: false,
        );
      }

      throw ProviderHttpException(
        message.isEmpty ? 'Permintaan ke server Nimegami gagal' : message,
        statusCode: status,
        retryable: errorJson['retryable'] == true,
      );
    }

    if (response.statusCode >= 400) {
      throw ProviderHttpException(
        'Server Nimegami merespons status ${response.statusCode}.',
        statusCode: response.statusCode,
        retryable: response.statusCode >= 500,
      );
    }

    return decoded;
  }

  void _throwIfEnvelopeFailed<T>(ApiV2Envelope<T> envelope) {
    if (envelope.isSuccess) return;

    final error = envelope.error;
    throw ProviderHttpException(
      error?.message ?? 'Permintaan ke server Nimegami gagal',
      statusCode: error?.status,
      retryable: error?.retryable ?? false,
    );
  }

  /* ------------------------------- Utils -------------------------------- */

  /// Ubah input (URL penuh atau `localId`) menjadi URL halaman anime.
  String _resolveUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('URL anime kosong');
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    final known = _urlByLocalId[trimmed];
    if (known != null && known.isNotEmpty) return known;

    throw ProviderHttpException(
      'URL anime tidak ditemukan untuk id "$trimmed".',
      statusCode: 404,
      retryable: false,
    );
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
        .replaceFirst(
          RegExp(r'\.(html?|php|aspx?|jsp)$', caseSensitive: false),
          '',
        )
        .replaceFirst(
          RegExp(
            r'[-_]?sub[-_]?(?:indo|indonesia)[-_]?\d*$',
            caseSensitive: false,
          ),
          '',
        )
        .trim()
        .toLowerCase();

    return segment.isEmpty ? url : segment;
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}

/// Entry cache stream dengan TTL.
class _CachedStream {
  _CachedStream(this.value) : cachedAt = DateTime.now();

  final StreamDto value;
  final DateTime cachedAt;

  static const Duration ttl = Duration(minutes: 5);

  bool get isExpired => DateTime.now().difference(cachedAt) > ttl;
}
