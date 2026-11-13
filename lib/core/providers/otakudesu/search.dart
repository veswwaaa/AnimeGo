import 'package:animego/core/utils/utils.dart';
import 'package:animego/core/providers/otakudesu/parse.dart';
import 'package:flutter/foundation.dart';

/// Base URL Otakudesu.
const String otakudesuBaseUrl = 'https://otakudesu.blog';

/// Header agar Otakudesu merespons seperti browser biasa.
const Map<String, String> otakudesuBrowserHeaders = {
  'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
  'Accept':
      'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
};

/// Melakukan pencarian anime di Otakudesu dengan cara scraping langsung
/// ke `otakudesu.blog` (setara `searchAnime` pada `src/otakudesu/features/search.ts`).
///
/// Mengembalikan list [Anime] berisi judul, gambar, rating, genre, status,
/// dan URL anime Otakudesu.
Future<List<Anime>> searchAnimeOtakudesu(String query) async {
  final trimmedQuery = query.trim();
  if (trimmedQuery.isEmpty) {
    return [];
  }

  final uri = Uri.parse(
    otakudesuBaseUrl,
  ).replace(queryParameters: {'s': trimmedQuery, 'post_type': 'anime'});

  logDev('searchAnimeOtakudesu request: $uri', prefix: 'searchAnimeOtakudesu:');

  final response = await httpGetWithRetry(
    uri,
    headers: otakudesuBrowserHeaders,
    timeout: const Duration(seconds: 15),
    maxAttempts: 2,
  );

  if (response.statusCode != 200) {
    throw Exception(
      'Search Otakudesu gagal dengan status ${response.statusCode}',
    );
  }

  final results = await parseOtakudesuSearchResultsAsync(response.body);
  logDev(
    'searchAnimeOtakudesu "$trimmedQuery" menghasilkan ${results.length} hasil',
    prefix: 'searchAnimeOtakudesu:',
  );
  return results;
}

/// Mengubah HTML halaman hasil pencarian Otakudesu menjadi list [Anime].
///
/// Parsing berat dijalankan di background isolate lewat `compute()` supaya
/// UI thread tidak tersedak saat hasil pencarian besar.
Future<List<Anime>> parseOtakudesuSearchResultsAsync(String html) async {
  final records = await compute(parseOtakudesuSearchRecords, html);

  return records.map(_animeFromSearchRecord).toList();
}

/// Mengubah HTML halaman hasil pencarian Otakudesu menjadi list [Anime].
///
/// Versi sinkron dipakai unit test (tanpa isolate).
List<Anime> parseOtakudesuSearchResults(String html) {
  final records = parseOtakudesuSearchRecords(html);
  return records.map(_animeFromSearchRecord).toList();
}

/// Mengubah satu record hasil parsing menjadi model [Anime].
Anime _animeFromSearchRecord(Map<String, dynamic> record) {
  final title = record['title']?.toString() ?? '';
  final image = record['image']?.toString() ?? '';
  final sourceUrl = record['sourceUrl']?.toString() ?? '';
  final genres = (record['genres'] as List<dynamic>? ?? const [])
      .map((genre) => genre.toString())
      .toList();

  return Anime(
    title: title,
    imageUrl: normalizeAnimeImageUrl(image, fallbackTitle: title),
    rating: (record['rating'] as num?)?.toDouble() ?? 0.0,
    genres: genres.isEmpty ? ['Unknown'] : genres,
    status: record['status']?.toString() ?? '',
    sourceUrl: sourceUrl,
    detailUrl: sourceUrl,
    episodes: 0,
  );
}

/// Mengubah HTML halaman anime Otakudesu menjadi DTO detail.
///
/// Dipisah agar parsing bisa diuji tanpa network.
AnimeDto parseOtakudesuAnimeDetail(String html, {required String sourceUrl}) {
  final record = parseOtakudesuDetailRecord(<String, String>{
    'html': html,
    'sourceUrl': sourceUrl,
  });
  return _animeDtoFromDetailRecord(record);
}

/// Mengubah HTML halaman anime Otakudesu menjadi DTO detail di background
/// isolate.
Future<AnimeDto> parseOtakudesuAnimeDetailAsync(
  String html, {
  required String sourceUrl,
}) async {
  final record = await compute(parseOtakudesuDetailRecord, <String, String>{
    'html': html,
    'sourceUrl': sourceUrl,
  });

  return _animeDtoFromDetailRecord(record);
}

/// Mengubah record detail menjadi [AnimeDto].
AnimeDto _animeDtoFromDetailRecord(Map<String, dynamic> record) {
  final title = record['title']?.toString() ?? 'Untitled Anime';
  final image = record['image']?.toString() ?? '';
  final synopsis = record['synopsis']?.toString() ?? '';
  final status = record['status']?.toString() ?? '';
  final genres = (record['genres'] as List<dynamic>? ?? const [])
      .map((genre) => genre.toString())
      .toList();
  final sourceUrl = record['sourceUrl']?.toString() ?? '';

  return AnimeDto(
    id: AnimeId('otakudesu', sourceUrl),
    provider: 'otakudesu',
    title: title,
    image: normalizeAnimeImageUrl(image, fallbackTitle: title),
    description: synopsis.isEmpty ? null : synopsis,
    genres: genres.isEmpty ? ['Unknown'] : genres,
    status: status.isEmpty ? 'Unknown' : status,
    rating: (record['rating'] as num?)?.toDouble() ?? 0.0,
    url: sourceUrl,
    episodeListUrl: sourceUrl,
  );
}
