import 'dart:async';

import 'package:animego/example-demo-apk/core/utils/utils.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

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

  final uri = Uri.parse(otakudesuBaseUrl).replace(
    queryParameters: {'s': trimmedQuery, 'post_type': 'anime'},
  );

  logDev('searchAnimeOtakudesu request: $uri', prefix: 'searchAnimeOtakudesu:');

  final response = await _httpGetWithHeaders(
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

  final results = parseOtakudesuSearchResults(response.body);
  logDev(
    'searchAnimeOtakudesu "$trimmedQuery" menghasilkan ${results.length} hasil',
    prefix: 'searchAnimeOtakudesu:',
  );
  return results;
}

/// Mengubah HTML halaman hasil pencarian Otakudesu menjadi list [Anime].
///
/// Dipisah dari [searchAnimeOtakudesu] agar parsing bisa diuji tanpa network.
List<Anime> parseOtakudesuSearchResults(String html) {
  final document = html_parser.parse(html);
  final results = <Anime>[];

  for (final item in document.querySelectorAll('li')) {
    final style = (item.attributes['style'] ?? '').replaceAll(' ', '');
    if (!style.contains('list-style:none') &&
        !style.contains('list-style-type:none')) {
      continue;
    }

    final titleLink = item.querySelector('h2 a');
    if (titleLink == null) {
      continue;
    }

    final name = titleLink.text.trim();
    final url = (titleLink.attributes['href'] ?? '').trim();
    if (name.isEmpty || url.isEmpty) {
      continue;
    }

    final image = (item.querySelector('img')?.attributes['src'] ?? '').trim();

    final sets = item.querySelectorAll('.set');
    final genres = _parseOtakudesuGenres(sets);
    final status = _parseOtakudesuSetValue(sets, 'Status');
    final rating = double.tryParse(_parseOtakudesuSetValue(sets, 'Rating'));

    results.add(
      Anime(
        title: name,
        imageUrl: normalizeAnimeImageUrl(image, fallbackTitle: name),
        rating: rating ?? 0.0,
        genres: genres,
        status: status,
        sourceUrl: url,
        detailUrl: url,
        episodes: 0,
      ),
    );
  }

  return results;
}

List<String> _parseOtakudesuGenres(List<Element> sets) {
  for (final set in sets) {
    if ((set.querySelector('b')?.text.trim() ?? '') != 'Genres') {
      continue;
    }

    final genres = set
        .querySelectorAll('a')
        .map((anchor) => anchor.text.trim())
        .where((genre) => genre.isNotEmpty)
        .toList();

    if (genres.isNotEmpty) {
      return genres;
    }
  }

  return ['Unknown'];
}

/// Mengambil nilai dari blok `.set` dengan label tertentu, misal `Status`
/// atau `Rating`. Label dan tanda `:` dibuang.
String _parseOtakudesuSetValue(List<Element> sets, String label) {
  for (final set in sets) {
    if ((set.querySelector('b')?.text.trim() ?? '') != label) {
      continue;
    }

    return set.text.replaceFirst(label, '').replaceAll(':', '').trim();
  }

  return '';
}

Future<http.Response> _httpGetWithHeaders(
  Uri uri, {
  required Map<String, String> headers,
  required Duration timeout,
  int maxAttempts = 2,
}) async {
  Object? lastError;
  StackTrace? lastStackTrace;

  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await http.get(uri, headers: headers).timeout(timeout);
    } catch (error, stackTrace) {
      lastError = error;
      lastStackTrace = stackTrace;

      logDev(
        'request gagal (percobaan $attempt): $error',
        prefix: 'searchAnimeOtakudesu:',
      );

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
