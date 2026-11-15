/// Mapper dari kontrak canonical v2 ke DTO internal mobile.
///
/// Dipakai REST provider (Nimegami/Zoronime) agar hasil network langsung
/// bisa dipakai layer UI tanpa branching berdasarkan asal data.
///
/// File ini sengaja terpisah dari folder `providers/` supaya tidak bentrok
/// dengan implementasi provider.
library;

import '../dto/anime_dto.dart';
import '../dto/episode_dto.dart';
import '../dto/stream_dto.dart';
import '../dto/api_v2_dto.dart';
import '../dto/api_envelope.dart';

/// Ambil `localId` dari id komposit backend (`<provider>:<localId>`).
///
/// Id dari backend v2 sudah komposit (`nimegami:one-piece`). Kalau id-nya
/// ternyata bukan format itu (mis. masih URL penuh seperti payload lama),
/// dipakai apa adanya supaya `AnimeId.parse` tetap aman di sisi consumer.
String localIdFromApiId(
  String raw, {
  required String provider,
  required String fallback,
}) {
  final parsed = AnimeId.parse(raw);
  if (parsed != null &&
      parsed.providerId == provider &&
      parsed.localId.isNotEmpty) {
    return parsed.localId;
  }
  return raw.isNotEmpty ? raw : fallback;
}

/// Konversi detail canonical v2 -> [AnimeDto].
AnimeDto animeDtoFromApiDetail(ApiAnimeDetail detail) {
  final provider = detail.provider;
  final localId = localIdFromApiId(
    detail.id,
    provider: provider,
    fallback: detail.url,
  );

  return AnimeDto(
    id: AnimeId(provider, localId),
    provider: provider,
    title: detail.title,
    image: detail.image,
    description: detail.description,
    genres: detail.genres.isEmpty ? const <String>['Unknown'] : detail.genres,
    status: detail.status ?? 'Unknown',
    rating: detail.rating ?? 0,
    year: detail.year,
    totalEpisodes: detail.totalEpisodes,
    url: detail.url,
    episodeListUrl: detail.episodeListUrl ?? detail.url,
    extra: <String, dynamic>{
      'source': provider,
      ...detail.extra,
    },
  );
}

/// Konversi item pencarian canonical v2 -> [AnimeDto].
AnimeDto animeDtoFromApiSearchItem(ApiSearchItem item) {
  final localId = localIdFromApiId(
    item.id,
    provider: item.provider,
    fallback: item.url,
  );

  return AnimeDto(
    id: AnimeId(item.provider, localId),
    provider: item.provider,
    title: item.title,
    image: item.image,
    description: item.description,
    genres: item.genres.isEmpty ? const <String>['Unknown'] : item.genres,
    status: item.status ?? 'Unknown',
    rating: item.rating ?? 0,
    year: item.year,
    totalEpisodes: item.totalEpisodes,
    url: item.url,
    episodeListUrl: item.url,
    extra: <String, dynamic>{'source': item.provider},
  );
}

/// Konversi episode canonical v2 -> [EpisodeDto].
EpisodeDto episodeDtoFromApiEpisode(ApiEpisode episode) {
  final parsed = AnimeId.parse(episode.id);
  final animeParsed = AnimeId.parse(episode.animeId);

  return EpisodeDto(
    id:
        parsed ??
        AnimeId(
          episode.provider,
          '${episode.animeId}#${episode.number}',
        ),
    animeId:
        animeParsed ??
        AnimeId(
          episode.provider,
          episode.animeId.isEmpty ? 'unknown' : episode.animeId,
        ),
    number: episode.number,
    title: episode.title,
    url: episode.url,
    airingDate: episode.airingDate,
    extra: episode.extra,
  );
}

/// Konversi stream canonical v2 -> [StreamDto].
StreamDto streamDtoFromApiStream(ApiStream stream) {
  final parsed = AnimeId.parse(stream.episodeId);

  return StreamDto(
    episodeId: parsed ?? AnimeId(stream.provider, stream.episodeId),
    type: stream.type,
    url: stream.url,
    mirrors: stream.mirrors
        .map(
          (mirror) => StreamMirror(
            url: mirror.url,
            label: mirror.label,
            quality: mirror.quality,
          ),
        )
        .toList(growable: false),
    headers: stream.headers,
    expiresAt: stream.expiresAt == null
        ? null
        : DateTime.tryParse(stream.expiresAt!),
  );
}
