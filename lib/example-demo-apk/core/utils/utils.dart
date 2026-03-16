import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'dart:developer' as developer;
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
  await Hive.initFlutter();
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

String formatPlaybackPosition(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}

String formatHistoryDate(DateTime dateTime) {
  final day = dateTime.day.toString().padLeft(2, '0');
  final month = dateTime.month.toString().padLeft(2, '0');
  final year = dateTime.year;
  return '$day/$month/$year';
}

String _fallbackImageForTitle(String title) {
  return 'https://picsum.photos/seed/${Uri.encodeComponent(title)}/400/600';
}

String _normalizeAnimeImageUrl(
  String? rawUrl, {
  required String fallbackTitle,
}) {
  final value = rawUrl?.trim() ?? '';
  if (value.isEmpty) {
    return _fallbackImageForTitle(fallbackTitle);
  }

  final parsed = Uri.tryParse(value);
  if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
    return _fallbackImageForTitle(fallbackTitle);
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

String _extractBestImageUrl(dynamic images, {required String fallbackTitle}) {
  if (images is! Map<String, dynamic>) {
    return _fallbackImageForTitle(fallbackTitle);
  }

  final webp = images['webp'];
  if (webp is Map<String, dynamic>) {
    final large = webp['large_image_url']?.toString();
    if (large != null && large.trim().isNotEmpty) {
      return _normalizeAnimeImageUrl(large, fallbackTitle: fallbackTitle);
    }

    final normal = webp['image_url']?.toString();
    if (normal != null && normal.trim().isNotEmpty) {
      return _normalizeAnimeImageUrl(normal, fallbackTitle: fallbackTitle);
    }
  }

  final jpg = images['jpg'];
  if (jpg is Map<String, dynamic>) {
    final large = jpg['large_image_url']?.toString();
    if (large != null && large.trim().isNotEmpty) {
      return _normalizeAnimeImageUrl(large, fallbackTitle: fallbackTitle);
    }

    final normal = jpg['image_url']?.toString();
    if (normal != null && normal.trim().isNotEmpty) {
      return _normalizeAnimeImageUrl(normal, fallbackTitle: fallbackTitle);
    }
  }

  return _fallbackImageForTitle(fallbackTitle);
}

Widget buildSafeAnimeImage(
  String imageUrl, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
}) {
  return Image.network(
    _normalizeAnimeImageUrl(imageUrl, fallbackTitle: 'unknown'),
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

Future<List<Anime>> searchAnime(String query, {int serverId = 1}) async {
  final trimmedQuery = query.trim();
  if (trimmedQuery.isEmpty) {
    return [];
  }

  late final http.Response response;

  switch (serverId) {
    case 1:
      try {
        response = await _httpGetWithRetry(
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
        logDev('searchAnime gagal parse response JSON: $error\n$stackTrace', prefix: 'searchAnime:');
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
        response = await _httpGetWithRetry(
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
          imageUrl: _normalizeAnimeImageUrl(
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
          episodes: _parseEpisodeCount(item['episodes']),
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

Future<String?> animeEpisode(String rawUrl, int eps, int server) async {
  Future<String?> fetchEpisodeFrom(String endpoint) async {
    try {
      final trimmedUrl = rawUrl.trim();
      if (trimmedUrl.isEmpty) {
        return null;
      }

      final String encodedUrl = (server == 2)
          ? Uri.encodeQueryComponent(trimmedUrl)
          : base64Encode(utf8.encode(trimmedUrl));
      final String apiUrl = '$apiBaseUrl$endpoint?url=$encodedUrl&eps=$eps';

      logDev('Requesting episode: $apiUrl', prefix: 'animeEpisode:');

      final response = await _httpGetWithRetry(
        Uri.parse(apiUrl),
        timeout: const Duration(seconds: 60),
        maxAttempts: 2,
      );

      logDev('Response status: ${response.body}', prefix: 'animeEpisode:');

      if (response.statusCode != 200) {
        logDev(
          'Error Log: Server error episode dengan status ${response.statusCode}',
          prefix: 'animeEpisode:',
        );
        return null;
      }

      final dynamic decodedDynamic = jsonDecode(response.body);

      if (decodedDynamic is String && decodedDynamic.trim().isNotEmpty) {
        return decodedDynamic.trim();
      }

      if (decodedDynamic is! Map<String, dynamic>) {
        logDev('Error Log: Format response episode tidak valid.', prefix: 'animeEpisode:');
        return null;
      }

      final directUrl = (server == 2)
        ? (await getOdvidhideUrl(decodedDynamic['url']))?.trim() ?? '' :
          decodedDynamic['url']?.toString().trim() ??
          decodedDynamic['videoUrl']?.toString().trim() ??
          decodedDynamic['streamUrl']?.toString().trim() ??
          '';
      
      logDev('directUrl: $directUrl', prefix: 'animeEpisode:');

      if (directUrl.isNotEmpty) {
        return directUrl;
      }

      final data = decodedDynamic['data'];
      if (data is Map<String, dynamic>) {
        final nestedUrl = (server == 2)
            ? (await getOdvidhideUrl(data['url']))?.trim() ?? ''
            : data['url']?.toString().trim() ??
              data['videoUrl']?.toString().trim() ??
              data['streamUrl']?.toString().trim() ??
              '';
        logDev('Nested URL: $nestedUrl', prefix: 'animeEpisode:');
        if (nestedUrl.isNotEmpty) {
          return nestedUrl;
        }
      }

      return null;
    } catch (error, stackTrace) {
      logDev(
        'Error Log: Terjadi kesalahan fatal saat ambil episode: $error\n$stackTrace',
        prefix: 'animeEpisode:',
      );
      return null;
    }
  }

  switch (server) {
    case 1:
      return await fetchEpisodeFrom('/api/nimegami/media');
    case 2:
      return await fetchEpisodeFrom('/api/zoronime/media');
    default:
      logDev('server tidak dikenal: $server', prefix: 'animeEpisode:');
      return null;
  }
}

Future<Anime> detailAnime(String url, {int serverId = 1}) async {
  logDev('detailAnime called with url: $url, serverId: $serverId', prefix: 'detailAnime:');
  final trimmedUrl = url.trim();
  if (trimmedUrl.isEmpty) {
    throw const FormatException('detailAnime url kosong');
  }

  logDev('detailAnime called with url: $trimmedUrl', prefix: 'detailAnime:');

  final endpoint = serverId == 2
      ? '/api/zoronime/anime'
      : '/api/nimegami/anime';

  //jika serverid 1 itu pake tobase64, jika serverid 2 dia tidak pake tobase64
  // final response = await _httpGetWithRetry(
  //   Uri.parse('$apiBaseUrl$endpoint?url=${toBase64(trimmedUrl)}'),
  //   timeout: const Duration(seconds: 45),
  //   maxAttempts: 2,
  // );
  final response = await _httpGetWithRetry(
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
    logDev('detailAnime gagal parse response JSON: $error\n$stackTrace', prefix: 'detailAnime:');
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
  final fallbackImage = _normalizeAnimeImageUrl(
    animePayload['imageUrl']?.toString(),
    fallbackTitle: safeTitle,
  );

  final imageUrl = (animePayload['images'] is Map<String, dynamic>)
      ? _extractBestImageUrl(animePayload['images'], fallbackTitle: safeTitle)
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
    episodes: _parseEpisodeCount(
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

String toBase64(String input) {
  List<int> bytes = utf8.encode(input);
  String base64Encoded = base64Encode(bytes);
  return base64Encoded;
}

Future<http.Response> _httpGetWithRetry(
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

Future<List<Anime>> getSchedules() async {
  logDev('schedules called', prefix: 'getSchedules:');
  try {
    final response = await _httpGetWithRetry(
      Uri.parse('$apiBaseUrl/api/nimegami/schedules'),
      timeout: const Duration(seconds: 60),
      maxAttempts: 2,
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Schedules API gagal dengan status ${response.statusCode}',
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    final List<dynamic> rawSchedules;

    if (decoded is Map<String, dynamic> && decoded['animeUpdates'] is List) {
      rawSchedules = decoded['animeUpdates'] as List<dynamic>;
    } else if (decoded is List) {
      rawSchedules = decoded;
    } else {
      throw Exception('Format response schedules tidak valid');
    }

    final schedules = rawSchedules.whereType<Map<String, dynamic>>().map((
      item,
    ) {
      final episode = _parseEpisodeCount(item['last_episode']);
      final sourceUrl = item['sourceUrl']?.toString().trim() ?? '';
      final title = item['title']?.toString().trim();
      final synopsis = item['synopsis']?.toString().trim();

      final images = item['images'];

      final score = item['score'];
      final rating = score is num
          ? score.toDouble()
          : double.tryParse('$score') ?? 0.0;

      final genres = (item['genres'] as List<dynamic>?)
          ?.where((genre) => genre != null)
          .map((genre) => genre.toString())
          .where((genre) => genre.isNotEmpty)
          .toList();

      return Anime(
        title: (title == null || title.isEmpty) ? 'Untitled Anime' : title,
        imageUrl: _extractBestImageUrl(
          images,
          fallbackTitle: (title == null || title.isEmpty) ? 'unknown' : title,
        ),
        rating: rating,
        genres: (genres == null || genres.isEmpty) ? ['Unknown'] : genres,
        synopsis: (synopsis == null || synopsis.isEmpty)
            ? 'No synopsis available'
            : synopsis,
        sourceUrl: sourceUrl,
        episodes: episode,
      );
    }).toList();

    dummyAnimes = schedules;
    return schedules;
  } catch (error, stackTrace) {
    logDev('schedules request failed: $error\n$stackTrace', prefix: 'getSchedules:');
    return [];
  }
}

int _parseEpisodeCount(dynamic value) {
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

Future<String?> getOdvidhideUrl(String fileId) async {
  final embedUrl = Uri.parse('https://odvidhide.com/embed/$fileId');

  try {
    // 1. Fetch HTML embed page
    final response = await http.get(
      embedUrl,
      headers: {
        "User-Agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Referer": "https://odvidhide.com/",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception("Gagal memuat halaman: HTTP ${response.statusCode}");
    }

    final html = response.body;

    // 2. Cari packed script
    final packerRegex = RegExp(r"eval\(function\(p,a,c,k,e,d\)[\s\S]+?\.split\('\|'\)\)\)");
    final packerMatch = packerRegex.firstMatch(html);
    if (packerMatch == null) throw Exception("Packed script tidak ditemukan");

    final packedScript = packerMatch.group(0)!;

    // Decode JavaScript Packer (p,a,c,k,e,d) secara inline
    final decodeRegex = RegExp(r"}\s*\(\s*'([\s\S]*?)'\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*'([\s\S]*?)'\.split\(\s*'\|'\s*\)");
    final decodeMatch = decodeRegex.firstMatch(packedScript);
    if (decodeMatch == null) throw Exception("Tidak bisa parse packed script");

    String p = decodeMatch.group(1)!;
    final int a = int.parse(decodeMatch.group(2)!);
    final int c = int.parse(decodeMatch.group(3)!);
    final List<String> k = decodeMatch.group(4)!.split('|');

    // Proses decoding
    for (int i = c - 1; i >= 0; i--) {
      // Sama seperti `if (k[i])` di JS
      if (i < k.length && k[i].isNotEmpty) {
        // toRadixString di Dart berfungsi persis seperti toString(radix) di JS (mendukung base 2-36)
        final radixStr = i.toRadixString(a); 
        p = p.replaceAll(RegExp(r'\b' + radixStr + r'\b'), k[i]);
      }
    }
    
    final decoded = p;

    // 3. Cari object links/o yang berisi video sources
    final objectRegex = RegExp(r"var\s+(?:links|o)\s*=\s*(\{[\s\S]*?\})\s*;");
    final objectMatch = objectRegex.firstMatch(decoded);
    if (objectMatch == null) throw Exception("Video sources tidak ditemukan");

    final objectStr = objectMatch.group(1)!;

    // 4. Ambil URL hls2
    final hls2Regex = RegExp(r'''["']hls2["']\s*:\s*["']([^"']+)["']''');
    final hls2Match = hls2Regex.firstMatch(objectStr);
    if (hls2Match == null) throw Exception("URL hls2 tidak ditemukan");

    final masterUrl = hls2Match.group(1)!;

    // 5. Convert master.m3u8 → index-v1-a1.m3u8
    final queryStart = masterUrl.indexOf("?");
    String basePath = masterUrl;
    String queryString = "";

    if (queryStart != -1) {
      basePath = masterUrl.substring(0, queryStart);
      queryString = masterUrl.substring(queryStart);
    }

    // Replace master.m3u8 di akhir path lalu gabungkan dengan query string
    final indexUrl = basePath.replaceAll(RegExp(r'master\.m3u8$'), 'index-v1-a1.m3u8') + queryString;

    return indexUrl;

  } catch (e) {
    // Print error untuk mempermudah debugging
    logDev('Error saat mengekstrak URL: $e', prefix: 'getOdvidhideUrl:');
    return null;
  }
}


void logDev(String text, {String prefix = 'Dev Log:'}) {
  print('$prefix $text');
  unawaited(appendDevLogEntry('$prefix $text'));
}