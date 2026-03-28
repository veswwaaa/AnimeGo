import 'dart:async';
import 'dart:convert';
import 'package:animego/example-demo-apk/features/anime-detail-screen/data/google-blog-direct.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'dart:developer' as developer;
import 'hive_bootstrap.dart';
import 'log_dev_storage_stub.dart';

// ==========================================
// DUMMY DATA MODEL
// ==========================================
class Anime {
  final String title;
  final String imageUrl;
  final double rating;
  final List<String> genres;
  final String synopsis;
  String sourceUrl;
  String? detailUrl;
  int episodes;

  Anime({
    required this.title,
    required this.imageUrl,
    required this.rating,
    required this.genres,
    required this.sourceUrl,
    this.detailUrl,
    required this.episodes,
    this.synopsis =
        "Yuji Itadori is a boy with tremendous physical strength, though he lives a completely ordinary high school life. One day, to save a friend who has been attacked by Curses, he eats a finger of Ryomen Sukuna, taking the Curse into his own soul.",
  });
}

List<Anime> dummyAnimes = [
  Anime(
    title: 'Jujutsu Kaisen',
    imageUrl: 'https://picsum.photos/seed/jujutsu/400/600',
    rating: 8.6,
    genres: ['Action', 'Fantasy', 'Supernatural'],
    sourceUrl: 'https://myanimelist.net/anime/40748/Jujutsu_Kaisen',
    episodes: 24,
  ),
  Anime(
    title: 'Attack on Titan',
    imageUrl: 'https://picsum.photos/seed/aot/400/600',
    rating: 9.0,
    genres: ['Action', 'Drama', 'Fantasy'],
    sourceUrl: 'https://myanimelist.net/anime/16498/Shingeki_no_Kyojin',
    episodes: 24,
  ),
  Anime(
    title: 'Demon Slayer',
    imageUrl: 'https://picsum.photos/seed/demon/400/600',
    rating: 8.5,
    genres: ['Action', 'Fantasy'],
    sourceUrl: 'https://myanimelist.net/anime/38000/Kimetsu_no_Yaiba',
    episodes: 24,
  ),
  Anime(
    title: 'SPY x FAMILY',
    imageUrl: 'https://picsum.photos/seed/spy/400/600',
    rating: 8.6,
    genres: ['Action', 'Comedy'],
    sourceUrl: 'https://myanimelist.net/anime/50265/Spy_x_Family',
    episodes: 12,
  ),
  Anime(
    title: 'One Punch Man',
    imageUrl: 'https://picsum.photos/seed/onepunch/400/600',
    rating: 8.5,
    genres: ['Action', 'Comedy'],
    sourceUrl: 'https://myanimelist.net/anime/30276/One_Punch_Man',
    episodes: 24,
  ),
];

class WatchHistoryItem {
  final String animeTitle;
  final String animeImageUrl;
  final String episodeName;
  final String videoUrl;
  final int positionSeconds;
  final DateTime updatedAt;

  const WatchHistoryItem({
    required this.animeTitle,
    required this.animeImageUrl,
    required this.episodeName,
    required this.videoUrl,
    required this.positionSeconds,
    required this.updatedAt,
  });

  Duration get position => Duration(seconds: positionSeconds);

  Map<String, dynamic> toMap() {
    return {
      'animeTitle': animeTitle,
      'animeImageUrl': animeImageUrl,
      'episodeName': episodeName,
      'videoUrl': videoUrl,
      'positionSeconds': positionSeconds,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static WatchHistoryItem? fromMap(Map<dynamic, dynamic> map) {
    final animeTitle = map['animeTitle'] as String?;
    final animeImageUrl = map['animeImageUrl'] as String?;
    final episodeName = map['episodeName'] as String?;
    final videoUrl = map['videoUrl'] as String?;
    final positionSecondsRaw = map['positionSeconds'];
    final updatedAtRaw = map['updatedAt'] as String?;

    if (animeTitle == null ||
        animeImageUrl == null ||
        episodeName == null ||
        videoUrl == null ||
        positionSecondsRaw == null ||
        updatedAtRaw == null) {
      return null;
    }

    final parsedDate = DateTime.tryParse(updatedAtRaw);
    if (parsedDate == null) {
      return null;
    }

    return WatchHistoryItem(
      animeTitle: animeTitle,
      animeImageUrl: animeImageUrl,
      episodeName: episodeName,
      videoUrl: videoUrl,
      positionSeconds: (positionSecondsRaw as num).toInt(),
      updatedAt: parsedDate,
    );
  }
}

final ValueNotifier<List<WatchHistoryItem>> watchHistoryNotifier =
    ValueNotifier<List<WatchHistoryItem>>([]);

const String _watchHistoryBoxName = 'watch_history_box';
const String _watchHistoryStorageKey = 'items';
Box<dynamic>? _watchHistoryBox;

Future<void> initWatchHistoryStorage() async {
  await ensureHiveInitialized();
  _watchHistoryBox ??= await Hive.openBox<dynamic>(_watchHistoryBoxName);

  final stored = _watchHistoryBox!.get(_watchHistoryStorageKey);
  if (stored is! List) {
    watchHistoryNotifier.value = [];
    return;
  }

  final items =
      stored
          .whereType<Map>()
          .map((entry) => WatchHistoryItem.fromMap(entry))
          .whereType<WatchHistoryItem>()
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  watchHistoryNotifier.value = items;
}

void _persistWatchHistory(List<WatchHistoryItem> items) {
  final box = _watchHistoryBox;
  if (box == null) {
    return;
  }

  final serialized = items.map((item) => item.toMap()).toList();
  unawaited(box.put(_watchHistoryStorageKey, serialized));
}

void upsertWatchHistory(WatchHistoryItem item) {
  final current = List<WatchHistoryItem>.from(watchHistoryNotifier.value);
  current.removeWhere(
    (existing) =>
        existing.animeTitle == item.animeTitle &&
        existing.episodeName == item.episodeName,
  );
  current.insert(0, item);
  watchHistoryNotifier.value = current;
  _persistWatchHistory(current);
}

void clearWatchHistory() {
  watchHistoryNotifier.value = [];
  _persistWatchHistory(const []);
}

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
  // final response = await httpGetWithRetry(
  //   Uri.parse('$apiBaseUrl$endpoint?url=${toBase64(trimmedUrl)}'),
  //   timeout: const Duration(seconds: 45),
  //   maxAttempts: 2,
  // );
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

String toBase64(String input) {
  List<int> bytes = utf8.encode(input);
  String base64Encoded = base64Encode(bytes);
  return base64Encoded;
}

Future<http.Response> httpGetWithRetry(
  Uri uri, {
  required Duration timeout,
  int maxAttempts = 2,
}) async {
  Object? lastError;
  StackTrace? lastStackTrace;

  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await http.get(uri).timeout(timeout);
    } catch (error, stackTrace) {
      lastError = error;
      lastStackTrace = stackTrace;

      if (attempt >= maxAttempts) {
        Error.throwWithStackTrace(error, stackTrace);
      }

      await Future.delayed(Duration(milliseconds: 500 * attempt));
    }
  }

  if (lastError != null && lastStackTrace != null) {
    Error.throwWithStackTrace(lastError, lastStackTrace);
  }

  throw TimeoutException('Request gagal setelah retry', timeout);
}

String normalizeAnimeImageUrl(
  String? rawUrl, {
  required String fallbackTitle,
}) {
  final value = rawUrl?.trim() ?? '';
  if (value.isEmpty) {
    return fallbackImageForTitle(fallbackTitle);
  }

  final parsed = Uri.tryParse(value);
  if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
    return fallbackImageForTitle(fallbackTitle);
  }

  var normalized = parsed;
  if (normalized.scheme == 'http') {
    normalized = normalized.replace(scheme: 'https');
  }

  if (normalized.host == 'myanimelist.net' &&
      normalized.pathSegments.isNotEmpty &&
      normalized.pathSegments.first == 'images') {
    normalized = normalized.replace(host: 'cdn.myanimelist.net');
  }

  return normalized.toString();
}

String fallbackImageForTitle(String title) {
  return 'https://picsum.photos/seed/${Uri.encodeComponent(title)}/400/600';
}

int parseEpisodeCount(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim()) ?? 0;
  }
  return 0;
}

String extractBestImageUrl(dynamic images, {required String fallbackTitle}) {
  if (images is! Map<String, dynamic>) {
    return fallbackImageForTitle(fallbackTitle);
  }

  final webp = images['webp'];
  if (webp is Map<String, dynamic>) {
    final large = webp['large_image_url']?.toString();
    if (large != null && large.trim().isNotEmpty) {
      return normalizeAnimeImageUrl(large, fallbackTitle: fallbackTitle);
    }

    final normal = webp['image_url']?.toString();
    if (normal != null && normal.trim().isNotEmpty) {
      return normalizeAnimeImageUrl(normal, fallbackTitle: fallbackTitle);
    }
  }

  final jpg = images['jpg'];
  if (jpg is Map<String, dynamic>) {
    final large = jpg['large_image_url']?.toString();
    if (large != null && large.trim().isNotEmpty) {
      return normalizeAnimeImageUrl(large, fallbackTitle: fallbackTitle);
    }

    final normal = jpg['image_url']?.toString();
    if (normal != null && normal.trim().isNotEmpty) {
      return normalizeAnimeImageUrl(normal, fallbackTitle: fallbackTitle);
    }
  }

  return fallbackImageForTitle(fallbackTitle);
}

Widget buildSafeAnimeImage(
  String imageUrl, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
}) {
  return Image.network(
    normalizeAnimeImageUrl(imageUrl, fallbackTitle: 'unknown'),
    width: width,
    height: height,
    fit: fit,
    filterQuality: FilterQuality.medium,
    errorBuilder: (_, __, ___) => Container(
      width: width,
      height: height,
      color: const Color(0xFF1C1C24),
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
    ),
  );
}

/////logging utilities

void logDev(String text, {String prefix = 'Dev Log:'}) {
  print('$prefix $text');
  unawaited(appendDevLogEntry('$prefix $text'));
}

void logInfo(String message) {
  developer.log(message, name: 'ExampleScreen');
}

void logError(String message, Object error, StackTrace stackTrace) {
  developer.log(
    message,
    name: 'ExampleScreen',
    error: error,
    stackTrace: stackTrace,
  );
}

void showErrorSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
