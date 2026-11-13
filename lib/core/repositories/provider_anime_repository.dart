import 'package:animego/core/dto/anime_dto.dart';
import 'package:animego/core/dto/api_envelope.dart';
import 'package:animego/core/dto/episode_dto.dart';
import 'package:animego/core/dto/stream_dto.dart';
import 'package:animego/core/providers/anime_provider.dart';
import 'package:animego/core/providers/provider_registry.dart';
import 'package:animego/core/repositories/anime_repository.dart';

/// Adapter registry -> repository.
///
/// Menerjemahkan [AnimeProvider] (scraper client-side maupun REST) menjadi
/// bentuk [ApiEnvelope] seragam, sehingga UI tidak pernah tahu asal data.
///
/// Repository ini juga menyimpan cache DTO di memori supaya ID canonical
/// (`provider:localId`) cukup untukocell detail, episode, dan stream tanpa
/// harus membawa URL mentah antar layer.
class ProviderAnimeRepository implements AnimeRepository {
  ProviderAnimeRepository({ProviderRegistry? registry, this.providerOrder})
      : registry = registry ?? appProviderRegistry;

  final ProviderRegistry registry;

  /// Urutan prioritas provider. Null = urutan registrasi.
  final List<String>? providerOrder;

  final Map<String, AnimeDto> _animeCache = <String, AnimeDto>{};
  final Map<String, EpisodeDto> _episodeCache = <String, EpisodeDto>{};

  @override
  Future<ApiEnvelope<List<AnimeDto>>> search(
    String query, {
    List<String>? providerOrder,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return ApiEnvelope<List<AnimeDto>>.failure(
        const ApiError(
          code: 'INVALID_QUERY',
          message: 'Query tidak boleh kosong',
        ),
      );
    }

    ApiError? lastApiError;

    final order = providerOrder ?? this.providerOrder ?? registry.ids;

    for (final id in order) {
      final provider = registry[id];
      if (provider == null || !provider.supportsSearch) continue;

      try {
        final results = await provider.search(trimmed);
        if (results.isNotEmpty) {
          for (final item in results) {
            _animeCache[item.id.composite] = item;
          }
          return ApiEnvelope<List<AnimeDto>>.success(
            results,
            meta: <String, dynamic>{
              'provider': provider.id,
              'count': results.length,
            },
          );
        }
      } catch (error) {
        lastApiError = ApiError(
          code: 'PROVIDER_UNAVAILABLE',
          message: error.toString(),
          provider: provider.id,
          retryable: true,
        );
      }
    }

    return ApiEnvelope<List<AnimeDto>>.failure(
      lastApiError ??
          const ApiError(
            code: 'NO_RESULT',
            message: 'Anime tidak ditemukan',
          ),
    );
  }

  @override
  Future<ApiEnvelope<AnimeDto>> detail(String id) async {
    final parsed = AnimeId.parse(id);
    if (parsed == null) {
      return ApiEnvelope<AnimeDto>.failure(
        const ApiError(
          code: 'INVALID_ID',
          message: 'ID harus berformat provider:localId',
        ),
      );
    }

    final provider = registry[parsed.providerId];
    if (provider == null || !provider.supportsDetail) {
      return ApiEnvelope<AnimeDto>.failure(
        ApiError(
          code: 'PROVIDER_UNAVAILABLE',
          message: 'Provider ${parsed.providerId} tidak mendukung detail',
          provider: parsed.providerId,
        ),
      );
    }

    try {
      final data = await provider.getDetail(_sourceUrlFor(parsed));
      _animeCache[data.id.composite] = data;
      return ApiEnvelope<AnimeDto>.success(
        data,
        meta: <String, dynamic>{'provider': provider.id},
      );
    } catch (error) {
      return ApiEnvelope<AnimeDto>.failure(
        ApiError(
          code: 'PROVIDER_UNAVAILABLE',
          message: error.toString(),
          provider: provider.id,
          retryable: true,
        ),
      );
    }
  }

  @override
  Future<ApiEnvelope<List<EpisodeDto>>> episodes(String animeId) async {
    final parsed = AnimeId.parse(animeId);
    if (parsed == null) {
      return ApiEnvelope<List<EpisodeDto>>.failure(
        const ApiError(
          code: 'INVALID_ID',
          message: 'ID harus berformat provider:localId',
        ),
      );
    }

    final provider = registry[parsed.providerId];
    if (provider == null || !provider.supportsEpisodes) {
      return ApiEnvelope<List<EpisodeDto>>.failure(
        ApiError(
          code: 'PROVIDER_UNAVAILABLE',
          message: 'Provider ${parsed.providerId} tidak mendukung episode',
          provider: parsed.providerId,
        ),
      );
    }

    try {
      final data = await provider.getEpisodes(_sourceUrlFor(parsed));
      for (final episode in data) {
        _episodeCache[episode.id.composite] = episode;
      }
      return ApiEnvelope<List<EpisodeDto>>.success(
        data,
        meta: <String, dynamic>{'provider': provider.id, 'count': data.length},
      );
    } catch (error) {
      return ApiEnvelope<List<EpisodeDto>>.failure(
        ApiError(
          code: 'PROVIDER_UNAVAILABLE',
          message: error.toString(),
          provider: provider.id,
          retryable: true,
        ),
      );
    }
  }

  @override
  Future<ApiEnvelope<StreamDto>> stream(String episodeId) async {
    final parsed = AnimeId.parse(episodeId);
    if (parsed == null) {
      return ApiEnvelope<StreamDto>.failure(
        const ApiError(
          code: 'INVALID_ID',
          message: 'ID harus berformat provider:localId',
        ),
      );
    }

    final provider = registry[parsed.providerId];
    if (provider == null || !provider.supportsStream) {
      return ApiEnvelope<StreamDto>.failure(
        ApiError(
          code: 'PROVIDER_UNAVAILABLE',
          message: 'Provider ${parsed.providerId} tidak mendukung stream',
          provider: parsed.providerId,
        ),
      );
    }

    final episode =
        _episodeCache[episodeId] ??
        EpisodeDto(
          id: parsed,
          animeId: AnimeId(parsed.providerId, parsed.localId),
          number: _episodeNumber(parsed.localId),
        );

    try {
      final data = await provider.getStreamUrl(episode);
      return ApiEnvelope<StreamDto>.success(
        data,
        meta: <String, dynamic>{'provider': provider.id},
      );
    } catch (error) {
      return ApiEnvelope<StreamDto>.failure(
        ApiError(
          code: 'PROVIDER_UNAVAILABLE',
          message: error.toString(),
          provider: provider.id,
          retryable: true,
        ),
      );
    }
  }

  /// Mengembalikan URL sumber untuk provider.
  ///
  /// Provider scraping butuh URL halaman penuh; provider REST juga butuh
  /// URL asli anime. Karena itu URL disimpan di cache saat search/detail.
  String _sourceUrlFor(AnimeId parsed) {
    final cached = _animeCache[parsed.composite];
    final url = cached?.url ?? cached?.episodeListUrl;
    if (url != null && url.isNotEmpty) return url;
    // localId pada provider ini sudah berupa URL sumber.
    return parsed.localId;
  }

  int _episodeNumber(String localId) {
    final parts = localId.split('#');
    if (parts.length < 2) return 1;
    return int.tryParse(parts.last) ?? 1;
  }
}
