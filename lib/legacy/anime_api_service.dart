import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config/api_config.dart';
import '../core/models/anime.dart';
import '../core/utils/app_logger.dart';
import '../core/utils/http_client.dart';
import '../core/utils/image_utils.dart';

/// Pencarian anime pada server 1 (nimegami) dan server 2 (zoronime).
Future<List<Anime>> searchAnime(String query, {int serverId = 1}) async {
  final trimmedQuery = query.trim();
  if (trimmedQuery.isEmpty) {
    return [];
  }

  late final http.Response response;

  switch (serverId) {
    case 1:
      try {
        response = await httpGetWithRetry(
          Uri.parse(
            '$apiBaseUrl/api/nimegami/search?q=${Uri.encodeQueryComponent(trimmedQuery)}',
          ),
          timeout: const Duration(seconds: 45),
          maxAttempts: 2,
        );
      } on TimeoutException catch (error, stackTrace) {
        logDev(
          'searchAnime timeout untuk query "$query": $error\n$stackTrace',
          prefix: 'searchAnime:',
        );
        rethrow;
      } catch (error, stackTrace) {
        logDev(
          'searchAnime request gagal untuk query "$query": $error\n$stackTrace',
          prefix: 'searchAnime:',
        );
        rethrow;
      }

      if (response.statusCode != 200) {
        throw Exception(
          'Search API gagal dengan status ${response.statusCode}',
        );
      }

      late final dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (error, stackTrace) {
        logDev(
          'searchAnime gagal parse response JSON: $error\n$stackTrace',
          prefix: 'searchAnime:',
        );
        rethrow;
      }

      if (decoded is! List) {
        throw Exception('Invalid response format');
      }

      final animeFutures = decoded.whereType<Map<String, dynamic>>().map((
        item,
      ) {
        final animeUrl = item['url']?.toString().trim() ?? '';
        if (animeUrl.isEmpty) {
          return Future<Anime?>.value(null);
        }

        return detailAnime(
          animeUrl,
          serverId: 1,
        ).then<Anime?>((value) => value).catchError((error, stackTrace) {
          logDev(
            'searchAnime skip item gagal detail url: $animeUrl: $error',
            prefix: 'searchAnime:',
          );
          return null;
        });
      });

      final animeList = await Future.wait(animeFutures);
      return animeList.whereType<Anime>().toList();
    case 2:
      final normalizedQuery = _normalizeZoronimeSearchQuery(trimmedQuery);
      try {
        response = await httpGetWithRetry(
          Uri.parse(
            '$apiBaseUrl/api/zoronime/search?q=${Uri.encodeQueryComponent(normalizedQuery)}',
          ),
          timeout: const Duration(seconds: 45),
          maxAttempts: 2,
        );
      } catch (error, stackTrace) {
        logDev(
          'searchAnime(zoronime) request gagal untuk query "$normalizedQuery": $error\n$stackTrace',
          prefix: 'searchAnime:',
        );
        rethrow;
      }

      if (response.statusCode != 200) {
        throw Exception(
          'Search API zoronime gagal dengan status ${response.statusCode}',
        );
      }

      late final dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (error, stackTrace) {
        logDev(
          'searchAnime(zoronime) gagal parse response JSON: $error\n$stackTrace',
          prefix: 'searchAnime:',
        );
        rethrow;
      }

      if (decoded is! List) {
        throw const FormatException(
          'searchAnime(zoronime) response bukan list',
        );
      }

      final animeFutures = decoded.whereType<Map<String, dynamic>>().map((
        item,
      ) {
        final animeUrl =
            item['sourceUrl']?.toString().trim() ??
            item['url']?.toString().trim() ??
            '';

        final fallbackTitle =
            item['title']?.toString().trim() ?? 'Untitled Anime';
        final fallbackAnime = Anime(
          title: fallbackTitle.isEmpty ? 'Untitled Anime' : fallbackTitle,
          imageUrl: normalizeAnimeImageUrl(
            item['imageUrl']?.toString(),
            fallbackTitle: fallbackTitle,
          ),
          rating: (item['rating'] is num)
              ? (item['rating'] as num).toDouble()
              : double.tryParse('${item['rating']}') ?? 0.0,
          genres: _parseGenres(item['genres']),
          synopsis: (item['synopsis']?.toString().trim().isEmpty ?? true)
              ? 'No synopsis available'
              : item['synopsis'].toString().trim(),
          sourceUrl: animeUrl,
          episodes: parseEpisodeCount(item['episodes']),
        );

        if (animeUrl.isEmpty) {
          return Future<Anime?>.value(fallbackAnime);
        }

        return detailAnime(
          animeUrl,
          serverId: 2,
        ).then<Anime?>((value) => value).catchError((error, stackTrace) {
          logDev(
            'searchAnime(zoronime) fallback item url: $animeUrl: $error',
            prefix: 'searchAnime:',
          );
          return fallbackAnime;
        });
      });

      final animeList = await Future.wait(animeFutures);
      return animeList.whereType<Anime>().toList();
  }
  return [];
}

/// Mengambil detail anime dari server terkait.
Future<Anime> detailAnime(String url, {int serverId = 1}) async {
  logDev(
    'detailAnime called with url: $url, serverId: $serverId',
    prefix: 'detailAnime:',
  );
  final trimmedUrl = url.trim();
  if (trimmedUrl.isEmpty) {
    throw const FormatException('detailAnime url kosong');
  }

  logDev('detailAnime called with url: $trimmedUrl', prefix: 'detailAnime:');

  final endpoint = serverId == 2
      ? '/api/zoronime/anime'
      : '/api/nimegami/anime';

  //jika serverid 1 itu pake tobase64, jika serverid 2 dia tidak pake tobase64
  final response = await httpGetWithRetry(
    Uri.parse(
      serverId == 2
          ? '$apiBaseUrl$endpoint?url=${Uri.encodeQueryComponent(trimmedUrl)}'
          : '$apiBaseUrl$endpoint?url=${toBase64(trimmedUrl)}',
    ),
    timeout: const Duration(seconds: 45),
    maxAttempts: 2,
  );

  if (response.statusCode != 200) {
    throw Exception('detailAnime gagal dengan status ${response.statusCode}');
  }

  late final dynamic decoded;
  try {
    decoded = jsonDecode(response.body);
  } catch (error, stackTrace) {
    logDev(
      'detailAnime gagal parse response JSON: $error\n$stackTrace',
      prefix: 'detailAnime:',
    );
    rethrow;
  }

  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('detailAnime response bukan object');
  }

  final Map<String, dynamic> animePayload =
      (decoded['name'] is Map<String, dynamic>)
      ? decoded['name'] as Map<String, dynamic>
      : decoded;

  final rawTitle =
      animePayload['title']?.toString().trim() ??
      animePayload['name']?.toString().trim() ??
      '';
  final safeTitle = rawTitle.isEmpty ? 'Untitled Anime' : rawTitle;
  final fallbackImage = normalizeAnimeImageUrl(
    animePayload['imageUrl']?.toString(),
    fallbackTitle: safeTitle,
  );

  final imageUrl = (animePayload['images'] is Map<String, dynamic>)
      ? extractBestImageUrl(animePayload['images'], fallbackTitle: safeTitle)
      : fallbackImage;

  return Anime(
    title: safeTitle,
    imageUrl: imageUrl,
    rating: (animePayload['score'] is num)
        ? (animePayload['score'] as num).toDouble()
        : (animePayload['rating'] is num)
        ? (animePayload['rating'] as num).toDouble()
        : double.tryParse(
                '${animePayload['score'] ?? animePayload['rating']}',
              ) ??
              0.0,
    genres: _parseGenres(animePayload['genres']),
    synopsis: (animePayload['synopsis']?.toString().trim().isEmpty ?? true)
        ? 'No synopsis available'
        : animePayload['synopsis'].toString().trim(),
    sourceUrl: animePayload['sourceUrl']?.toString().trim().isNotEmpty == true
        ? animePayload['sourceUrl'].toString().trim()
        : trimmedUrl,
    detailUrl: trimmedUrl,
    episodes: parseEpisodeCount(
      animePayload['last_episode'] ?? animePayload['episodes'],
    ),
  );
}

String _normalizeZoronimeSearchQuery(String input) {
  return input
      .toLowerCase()
      // Remove only bracket characters, keep the text inside.
      .replaceAll(RegExp(r'[\[\]\(\)\{\}]'), ' ')
      // Convert ordinal suffixes: 3rd -> 3, 1st -> 1.
      .replaceAllMapped(
        RegExp(r'\b(\d+)(st|nd|rd|th)\b'),
        (match) => match.group(1)!,
      )
      .replaceAll(RegExp(r'[-_]'), ' ')
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

List<String> _parseGenres(dynamic rawGenres) {
  if (rawGenres is! List) {
    return ['Unknown'];
  }

  final genres = rawGenres
      .map((genre) {
        if (genre is Map<String, dynamic>) {
          return genre['name']?.toString().trim() ?? '';
        }
        return genre?.toString().trim() ?? '';
      })
      .where((genre) => genre.isNotEmpty)
      .toList();

  return genres.isEmpty ? ['Unknown'] : genres;
}
