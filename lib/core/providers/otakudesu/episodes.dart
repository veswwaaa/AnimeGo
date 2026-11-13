import 'package:animego/core/utils/http_client.dart';
import 'package:animego/core/providers/otakudesu/parse.dart';
import 'package:animego/core/providers/otakudesu/search.dart';
import 'package:flutter/foundation.dart';

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

  final response = await httpGetWithRetry(
    Uri.parse(trimmedUrl),
    headers: otakudesuBrowserHeaders,
    timeout: const Duration(seconds: 15),
    maxAttempts: 2,
  );

  if (response.statusCode != 200) {
    throw Exception(
      'Gagal memuat halaman anime Otakudesu dengan status '
      '${response.statusCode}',
    );
  }

  return parseOtakudesuEpisodesAsync(response.body);
}

/// Mengubah HTML halaman anime Otakudesu menjadi daftar episode.
///
/// Parsing dijalankan di background isolate lewat `compute()`.
Future<List<OtakudesuEpisode>> parseOtakudesuEpisodesAsync(String html) async {
  final records = await compute(parseOtakudesuEpisodeRecords, html);

  return records
      .map(
        (record) => OtakudesuEpisode(
          title: record['title']?.toString() ?? '',
          url: record['url']?.toString() ?? '',
        ),
      )
      .toList();
}

/// Mengubah HTML halaman anime Otakudesu menjadi daftar episode.
///
/// Versi sinkron dipakai unit test (tanpa isolate).
List<OtakudesuEpisode> parseOtakudesuEpisodes(String html) {
  final records = parseOtakudesuEpisodeRecords(html);

  return records
      .map(
        (record) => OtakudesuEpisode(
          title: record['title']?.toString() ?? '',
          url: record['url']?.toString() ?? '',
        ),
      )
      .toList();
}
