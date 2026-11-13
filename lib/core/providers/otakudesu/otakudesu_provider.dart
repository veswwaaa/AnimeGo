import 'package:animego/core/dto/anime_dto.dart';
import 'package:animego/core/providers/anime_provider.dart';
import 'package:animego/core/dto/api_envelope.dart';
import 'package:animego/core/dto/episode_dto.dart';
import 'package:animego/core/dto/stream_dto.dart';
import 'package:animego/core/utils/http_client.dart';
import 'package:animego/core/providers/otakudesu/episodes.dart';
import 'package:animego/core/providers/otakudesu/parse.dart';
// import 'package:animego/core/providers/otakudesu_provider/search.dart';
import 'package:animego/core/providers/otakudesu/search.dart';
import 'package:animego/core/providers/otakudesu/video.dart';

/// Provider Otakudesu (client-side scraper).
///
/// Sumber data diambil langsung dari `otakudesu.blog` tanpa melewati backend,
/// sehingga tetap gratis tanpa server. Parser yang dipakai sudah proven
/// (lihat `features/search-screen/data/otakudesu-*.dart`).
class OtakudesuProvider extends AnimeProvider {
  const OtakudesuProvider();

  static const String providerId = 'otakudesu';

  @override
  String get id => providerId;

  @override
  String get displayName => 'Otakudesu';

  @override
  String get kind => 'scraping';

  @override
  bool get supportsSearch => true;

  @override
  bool get supportsDetail => true;

  @override
  bool get supportsEpisodes => true;

  @override
  bool get supportsStream => true;

  @override
  Future<List<AnimeDto>> search(String query) async {
    final results = await searchAnimeOtakudesu(query);
    return results
        .map(
          (anime) => AnimeDto(
            id: AnimeId(
              providerId,
              anime.sourceUrl.isEmpty ? anime.title : anime.sourceUrl,
            ),
            provider: providerId,
            title: anime.title,
            image: anime.imageUrl,
            genres: anime.genres,
            status: anime.status.isEmpty ? 'Unknown' : anime.status,
            rating: anime.rating,
            url: anime.sourceUrl,
            episodeListUrl: anime.sourceUrl,
          ),
        )
        .toList();
  }

  @override
  Future<AnimeDto> getDetail(String sourceUrl) async {
    final trimmed = sourceUrl.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('URL anime Otakudesu kosong');
    }

    final response = await httpGetWithRetry(
      Uri.parse(trimmed),
      timeout: const Duration(seconds: 20),
      headers: otakudesuBrowserHeaders,
    );

    if (response.statusCode != 200) {
      throw ProviderHttpException(
        'Otakudesu detail gagal dengan status ' +
            response.statusCode.toString(),
        statusCode: response.statusCode,
      );
    }

    return parseOtakudesuAnimeDetailAsync(response.body, sourceUrl: trimmed);
  }

  @override
  Future<List<EpisodeDto>> getEpisodes(String sourceUrl) async {
    final episodes = await getOtakudesuEpisodes(sourceUrl);
    final animeId = AnimeId(providerId, sourceUrl.trim());

    return episodes.indexed.map((entry) {
      final index = entry.$1;
      final episode = entry.$2;
      final number = parseOtakudesuEpisodeNumber(episode.url);
      return EpisodeDto(
        id: AnimeId(providerId, animeId.localId + '#' + number.toString()),
        animeId: animeId,
        number: number > 0 ? number : index + 1,
        title: episode.title,
        url: episode.url,
      );
    }).toList();
  }

  @override
  Future<StreamDto> getStreamUrl(EpisodeDto episode) async {
    final url = episode.url?.trim() ?? '';
    if (url.isEmpty) {
      throw const FormatException('Episode Otakudesu tidak punya URL');
    }

    final video = await getOtakudesuVideo(url);
    final streamUrl = video.streamUrl ?? '';
    if (!video.success || streamUrl.isEmpty) {
      throw ProviderHttpException(
        video.errorMessage ?? 'Gagal memuat stream Otakudesu',
        retryable: true,
      );
    }

    return StreamDto(
      episodeId: episode.id,
      type: streamUrl.contains('.m3u8') ? 'hls' : 'direct',
      url: streamUrl,
      mirrors: [
        if (video.provider != null)
          StreamMirror(
            url: streamUrl,
            label: video.provider,
            quality: video.quality,
          ),
      ],
    );
  }
}
