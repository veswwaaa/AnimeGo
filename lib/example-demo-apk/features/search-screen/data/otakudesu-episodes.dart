import 'package:animego/example-demo-apk/features/search-screen/data/otakudesu-search.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

/// Data layer Otakudesu untuk daftar episode.
///
/// Dipakai untuk anime yang berasal dari Otakudesu, karena halaman
/// `/anime/` Otakudesu tidak memakai `.list_eps_stream` milik nimegami
/// dan episode-nya dipanggil lewat URL episode, bukan index episode.
///
/// Resolusi stream video ada di `otakudesu-video.dart` (port dari
/// `video.ts`, `mirrors.ts`, dan `finalVideo.ts`).
class OtakudesuEpisode {
  final String title;
  final String url;

  const OtakudesuEpisode({required this.title, required this.url});
}

/// Mengambil daftar episode dari halaman anime Otakudesu.
///
/// Episode diurutkan dari nomor episode terkecil ke terbesar.
Future<List<OtakudesuEpisode>> getOtakudesuEpisodes(String animeUrl) async {
  final trimmedUrl = animeUrl.trim();
  if (trimmedUrl.isEmpty) {
    return [];
  }

  final response = await http
      .get(Uri.parse(trimmedUrl), headers: otakudesuBrowserHeaders)
      .timeout(const Duration(seconds: 15));

  if (response.statusCode != 200) {
    throw Exception(
      'Gagal memuat halaman anime Otakudesu dengan status ${response.statusCode}',
    );
  }

  return parseOtakudesuEpisodes(response.body);
}

/// Mengubah HTML halaman anime Otakudesu menjadi daftar episode.
List<OtakudesuEpisode> parseOtakudesuEpisodes(String html) {
  final document = html_parser.parse(html);
  final seen = <String>{};
  final episodes = <OtakudesuEpisode>[];

  for (final anchor in document.querySelectorAll('a')) {
    final href = (anchor.attributes['href'] ?? '').trim();
    if (!href.contains('/episode/') || !seen.add(href)) {
      continue;
    }

    final title = anchor.text.trim();
    if (title.isEmpty) {
      continue;
    }

    episodes.add(OtakudesuEpisode(title: title, url: href));
  }

  episodes.sort(
    (a, b) => _episodeNumber(a.url).compareTo(_episodeNumber(b.url)),
  );

  return episodes;
}

/// Mengambil angka episode dari URL, misal `...-episode-12-sub-indo/`.
int _episodeNumber(String url) {
  final match = RegExp(r'episode-(\d+)').firstMatch(url);
  if (match == null) {
    return 0;
  }
  return int.tryParse(match.group(1)!) ?? 0;
}
