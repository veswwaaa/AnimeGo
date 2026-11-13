import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

/// Parser HTML Otakudesu yang murni Dart (tanpa Flutter).
///
/// Semua fungsi di file ini aman dijalankan di background isolate lewat
/// `compute()`, karena hanya memakai paket `html` dan tipe sederhana.
///
/// Hasil parsing disimpan sebagai `Map<String, dynamic>` supaya bisa
/// dikirim lintas isolate tanpa perlu konversi ke object class.

/// Menerjemahkan HTML halaman hasil pencarian Otakudesu menjadi daftar record.
///
/// Dipisah dari model agar bisa dipakai baik di isolate maupun sinkron.
List<Map<String, dynamic>> parseOtakudesuSearchRecords(String html) {
  final document = html_parser.parse(html);
  final results = <Map<String, dynamic>>[];

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

    results.add({
      'title': name,
      'image': image,
      'rating': double.tryParse(parseOtakudesuSetValue(sets, 'Rating')) ?? 0.0,
      'genres': parseOtakudesuGenres(sets),
      'status': parseOtakudesuSetValue(sets, 'Status'),
      'sourceUrl': url,
    });
  }

  return results;
}

/// Menerjemahkan HTML halaman anime Otakudesu menjadi satu record detail.
///
/// Payload berisi `html` dan `sourceUrl` supaya bisa langsung dipakai
/// sebagai callback `compute()`.
Map<String, dynamic> parseOtakudesuDetailRecord(Map<String, String> payload) {
  final html = payload['html'] ?? '';
  final sourceUrl = payload['sourceUrl'] ?? '';
  final document = html_parser.parse(html);

  final title =
      document.querySelector('.entry-title, h1, .anime-title')?.text.trim() ??
      '';
  final image =
      document
          .querySelector('.thumb img, .anime-thumb img, .summary_image img')
          ?.attributes['src'] ??
      '';

  final synopsis =
      document
          .querySelector('.entry-content, .summary_content, .anime-synopsis')
          ?.text
          .trim() ??
      '';

  final sets = document.querySelectorAll('.set');

  return {
    'title': title.isEmpty ? 'Untitled Anime' : title,
    'image': image,
    'synopsis': synopsis,
    'genres': parseOtakudesuGenres(sets),
    'status': parseOtakudesuSetValue(sets, 'Status'),
    'rating': double.tryParse(parseOtakudesuSetValue(sets, 'Rating')) ?? 0.0,
    'sourceUrl': sourceUrl,
  };
}

/// Menerjemahkan HTML halaman anime Otakudesu menjadi daftar record episode.
List<Map<String, dynamic>> parseOtakudesuEpisodeRecords(String html) {
  final document = html_parser.parse(html);
  final seen = <String>{};
  final episodes = <Map<String, dynamic>>[];

  for (final anchor in document.querySelectorAll('a')) {
    final href = (anchor.attributes['href'] ?? '').trim();
    if (!href.contains('/episode/') || !seen.add(href)) {
      continue;
    }

    final title = anchor.text.trim();
    if (title.isEmpty) {
      continue;
    }

    episodes.add({
      'title': title,
      'url': href,
      'number': parseOtakudesuEpisodeNumber(href),
    });
  }

  episodes.sort((a, b) => (a['number'] as int).compareTo(b['number'] as int));

  return episodes;
}

/// Mengambil daftar genre dari blok `.set` berlabel `Genres`.
List<String> parseOtakudesuGenres(List<Element> sets) {
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
String parseOtakudesuSetValue(List<Element> sets, String label) {
  for (final set in sets) {
    if ((set.querySelector('b')?.text.trim() ?? '') != label) {
      continue;
    }

    return set.text.replaceFirst(label, '').replaceAll(':', '').trim();
  }

  return '';
}

/// Mengambil angka episode dari URL, misal `...-episode-12-sub-indo/`.
int parseOtakudesuEpisodeNumber(String url) {
  final match = RegExp(r'episode-(\d+)').firstMatch(url);
  if (match == null) {
    return 0;
  }
  return int.tryParse(match.group(1)!) ?? 0;
}

/// Menerjemahkan HTML halaman episode Otakudesu menjadi daftar record mirror.
List<Map<String, dynamic>> parseOtakudesuMirrorRecords(String html) {
  final document = html_parser.parse(html);
  final mirrors = <Map<String, dynamic>>[];

  for (final list in document.querySelectorAll('.mirrorstream > ul')) {
    final quality = parseOtakudesuQuality(list.className);

    for (final anchor in list.querySelectorAll('a')) {
      final content = (anchor.attributes['data-content'] ?? '').trim();
      if (content.isEmpty) {
        continue;
      }

      mirrors.add({
        'quality': quality,
        'provider': anchor.text.trim(),
        'content': content,
        'data': decodeOtakudesuMirrorPayload(content),
        'isDefault': anchor.attributes['data-default'] == 'true',
      });
    }
  }

  return mirrors;
}

/// Mengambil label kualitas dari class `ul`, contoh `m480p` -> `480p`.
String parseOtakudesuQuality(String className) {
  final match = RegExp(r'\bm(\d+)p\b').firstMatch(className);
  if (match == null) {
    return '';
  }
  return '${match.group(1)}p';
}

/// Men-decode payload `data-content` (base64 JSON) menjadi map.
Map<String, dynamic>? decodeOtakudesuMirrorPayload(String content) {
  try {
    final decoded = utf8.decode(base64Decode(content));
    final json = jsonDecode(decoded);
    if (json is Map<String, dynamic>) {
      return json;
    }
  } catch (_) {
    return null;
  }
  return null;
}
