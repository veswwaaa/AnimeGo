import 'dart:convert';

import 'package:animego/core/config/api_config.dart';
import 'package:animego/core/dto/anime_dto.dart';
import 'package:animego/core/dto/api_envelope.dart';
import 'package:animego/core/utils/http_client.dart';
import 'package:animego/core/utils/image_utils.dart';

/// ID provider Nimegami.
const String kNimegamiProviderId = 'nimegami';

/// Mengambil jadwal rilis anime (schedule) dari backend Nimegami.
///
/// Fungsi ini murni di layer data/provider: mengembalikan DTO seragam,
/// bukan model UI, agar bisa dipakai provider maupun repository.
Future<List<AnimeDto>> fetchNimegamiSchedules({
  String baseUrl = apiBaseUrl,
  Duration timeout = const Duration(seconds: 60),
  int maxAttempts = 2,
}) async {
  final uri = Uri.parse('$baseUrl/api/nimegami/schedules');

  final response = await httpGetWithRetry(
    uri,
    timeout: timeout,
    maxAttempts: maxAttempts,
  );

  if (response.statusCode != 200) {
    throw ProviderHttpException(
      'Schedules Nimegami gagal dengan status ${response.statusCode}',
      statusCode: response.statusCode,
    );
  }

  final dynamic decoded = jsonDecode(response.body);
  final List<dynamic> rawSchedules;

  if (decoded is Map<String, dynamic> && decoded['animeUpdates'] is List) {
    rawSchedules = decoded['animeUpdates'] as List<dynamic>;
  } else if (decoded is List) {
    rawSchedules = decoded;
  } else {
    throw const FormatException('Format response schedules tidak valid');
  }

  return rawSchedules
      .whereType<Map<String, dynamic>>()
      .map(_scheduleToDto)
      .toList();
}

AnimeDto _scheduleToDto(Map<String, dynamic> item) {
  final title = _firstNonEmpty(item, const <String>['title', 'name']);
  final resolvedTitle = title.isEmpty ? 'Untitled Anime' : title;
  final sourceUrl = _firstNonEmpty(item, const <String>['sourceUrl', 'url']);

  final score = item['score'] ?? item['rating'];
  final rating = score is num
      ? score.toDouble()
      : double.tryParse('$score') ?? 0.0;

  final images = item['images'];
  final image = images is Map<String, dynamic>
      ? extractBestImageUrl(images, fallbackTitle: resolvedTitle)
      : normalizeAnimeImageUrl(
          item['imageUrl']?.toString(),
          fallbackTitle: resolvedTitle,
        );

  return AnimeDto(
    id: AnimeId(kNimegamiProviderId, sourceUrl.isEmpty ? resolvedTitle : sourceUrl),
    provider: kNimegamiProviderId,
    title: resolvedTitle,
    image: image,
    description: _firstNonEmpty(item, const <String>['synopsis']),
    genres: _parseGenres(item['genres']),
    status: _firstNonEmpty(item, const <String>['status']).isEmpty
        ? 'Unknown'
        : _firstNonEmpty(item, const <String>['status']),
    rating: rating,
    totalEpisodes: parseEpisodeCount(item['last_episode'] ?? item['episodes']),
    url: sourceUrl.isEmpty ? null : sourceUrl,
    episodeListUrl: sourceUrl.isEmpty ? null : sourceUrl,
    extra: <String, dynamic>{'source': kNimegamiProviderId},
  );
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

String _firstNonEmpty(Map<String, dynamic> payload, List<String> keys) {
  for (final key in keys) {
    final value = payload[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '';
}
