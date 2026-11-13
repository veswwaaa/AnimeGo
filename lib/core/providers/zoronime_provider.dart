import 'dart:convert';

import 'package:animego/core/config/api_config.dart';
import 'package:animego/core/dto/anime_dto.dart';
import 'package:animego/core/dto/api_envelope.dart';
import 'package:animego/core/dto/episode_dto.dart';
import 'package:animego/core/dto/stream_dto.dart';
import 'package:animego/core/providers/anime_provider.dart';
import 'package:animego/core/providers/rest_provider_base.dart';
import 'package:animego/core/utils/http_client.dart';
import 'package:animego/core/utils/image_utils.dart';

/// Provider Zoronime (REST).
///
/// Parameter URL di-encode dengan query encoding, sesuai kontrak API anime-api.
class ZoronimeProvider extends RestProviderBase implements AnimeProvider {
  ZoronimeProvider({super.client, super.random});

  static const String providerId = 'zoronime';

  @override
  String get id => providerId;

  @override
  String get displayName => 'Zoronime';

  @override
  bool get supportsSearch => true;

  @override
  bool get supportsDetail => true;

  @override
  bool get supportsEpisodes => true;

  @override
  bool get supportsStream => true;

  @override
  String get baseUrl => apiBaseUrl;

  @override
  ParamEncoding get paramEncoding => ParamEncoding.query;

  @override
  Map<String, String> get extraHeaders => const <String, String>{};

  @override
  Future<List<AnimeDto>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const <AnimeDto>[];

    final normalized = _normalizeQuery(trimmed);
    final uri = Uri.parse('$baseUrl/api/zoronime/search').replace(
      queryParameters: {'q': normalized},
    );

    final response = await get(
      uri.toString(),
      timeout: const Duration(seconds: 45),
      maxAttempts: 2,
    );

    if (response.statusCode != 200) {
      throw ProviderHttpException(
        'Search Zoronime gagal dengan status ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException('Search Zoronime response bukan list');
    }

    final items = decoded.whereType<Map<String, dynamic>>().toList();

    // Hindari N+1: ambil detail hanya jika data ringkas tidak cukup.
    final results = <AnimeDto>[];
    for (final item in items) {
      final sourceUrl = _firstNonEmpty(item, const <String>['sourceUrl', 'url']);
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

  @override
  Future<AnimeDto> getDetail(String sourceUrl) async {
    final trimmed = sourceUrl.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('sourceUrl kosong');
    }

    final uri = Uri.parse('$baseUrl/api/zoronime/anime').replace(
      queryParameters: {'url': encodeParam(trimmed)},
    );

    final response = await get(
      uri.toString(),
      timeout: const Duration(seconds: 45),
      maxAttempts: 2,
    );

    if (response.statusCode != 200) {
      throw ProviderHttpException(
        'Detail Zoronime gagal dengan status ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Detail Zoronime response bukan object');
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
    final resolved = resolvedUrl.isEmpty ? trimmed : resolvedUrl;

    return AnimeDto(
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
  }

  @override
  Future<List<EpisodeDto>> getEpisodes(String sourceUrl) async {
    final trimmed = sourceUrl.trim();
    if (trimmed.isEmpty) return const <EpisodeDto>[];

    final detail = await getDetail(trimmed);
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

  @override
  Future<StreamDto> getStreamUrl(EpisodeDto episode) async {
    final sourceUrl = (episode.url ?? '').trim();
    if (sourceUrl.isEmpty) {
      throw const FormatException('Episode tanpa URL tidak bisa diputar');
    }

    final uri = Uri.parse('$baseUrl/api/zoronime/media').replace(
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
        'Media Zoronime gagal dengan status ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);
    final direct = _extractMediaUrl(decoded);
    if (direct.isEmpty) {
      throw ProviderHttpException('Media Zoronime tidak mengembalikan URL');
    }

    return StreamDto(
      episodeId: episode.id,
      type: direct.contains('.m3u8') ? 'hls' : 'direct',
      url: direct,
    );
  }

  String _extractMediaUrl(dynamic decoded) {
    if (decoded is String) return decoded.trim();
    if (decoded is! Map<String, dynamic>) return '';
    final direct =
        _firstNonEmpty(decoded, const <String>['url', 'videoUrl', 'streamUrl']);
    if (direct.isNotEmpty) return direct;
    final data = decoded['data'];
    if (data is Map<String, dynamic>) {
      return _firstNonEmpty(data, const <String>['url', 'videoUrl', 'streamUrl']);
    }
    return '';
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
        .replaceAll(RegExp(r'[\[\]\(\)\{\}]'), ' ')
        .replaceAllMapped(
          RegExp(r'\b(\d+)(st|nd|rd|th)\b'),
          (match) => match.group(1)!,
        )
        .replaceAll(RegExp(r'[-_]'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
