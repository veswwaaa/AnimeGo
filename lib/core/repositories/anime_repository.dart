import '../dto/anime_dto.dart';
import '../dto/api_envelope.dart';
import '../dto/episode_dto.dart';
import '../dto/stream_dto.dart';

/// Kontrak repository yang menyerupai bentuk REST, agar UI tidak pernah tahu
/// apakah data berasal dari backend HTTP atau scraper client-side.
abstract class AnimeRepository {
  Future<ApiEnvelope<List<AnimeDto>>> search(String query);

  Future<ApiEnvelope<AnimeDto>> detail(String id);

  Future<ApiEnvelope<List<EpisodeDto>>> episodes(String animeId);

  Future<ApiEnvelope<StreamDto>> stream(String episodeId);
}
