import '../dto/anime_dto.dart';
import 'anime.dart';

/// Konversi DTO canonical -> model UI.
///
/// Ini satu-satunya tempat DTO dipetakan ke model, sehingga model UI
/// tidak pernah bocor ke layer data.
Anime animeDtoToModel(AnimeDto dto) {
  return Anime(
    title: dto.title,
    imageUrl: dto.image ?? '',
    rating: dto.rating,
    genres: dto.genres,
    synopsis: dto.description ?? 'No synopsis available',
    status: dto.status,
    sourceUrl: dto.url ?? dto.episodeListUrl ?? '',
    detailUrl: dto.episodeListUrl ?? dto.url,
    episodes: dto.totalEpisodes ?? 0,
    providerId: dto.provider,
  );
}
