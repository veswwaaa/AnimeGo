import 'package:flutter_test/flutter_test.dart';

import 'package:animego/core/dto/anime_dto.dart';
import 'package:animego/core/dto/api_envelope.dart';
import 'package:animego/core/dto/episode_dto.dart';
import 'package:animego/core/dto/stream_dto.dart';
import 'package:animego/core/providers/anime_provider.dart';
import 'package:animego/core/providers/provider_registry.dart';
import 'package:animego/core/repositories/provider_anime_repository.dart';

/// Provider palsu untuk menguji fallback registry + envelope repository.
class _FakeProvider extends AnimeProvider {
  _FakeProvider(this.id, this._items, {this.shouldThrow = false});

  @override
  final String id;

  final List<AnimeDto> _items;
  final bool shouldThrow;

  @override
  String get displayName => id;

  @override
  String get kind => 'fake';

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
    if (shouldThrow) {
      throw StateError('provider $id gagal');
    }
    return _items;
  }

  @override
  Future<AnimeDto> getDetail(String sourceUrl) async {
    return _items.first;
  }

  @override
  Future<List<EpisodeDto>> getEpisodes(String sourceUrl) async {
    return const <EpisodeDto>[];
  }

  @override
  Future<StreamDto> getStreamUrl(EpisodeDto episode) async {
    return StreamDto(episodeId: episode.id, type: 'direct', url: 'http://x');
  }
}

AnimeDto _dto(String provider, String title) {
  return AnimeDto(
    id: AnimeId(provider, title.toLowerCase()),
    provider: provider,
    title: title,
    image: null,
  );
}

void main() {
  group('ProviderRegistry', () {
    test(
      'searchAll memakai provider pertama yang mengembalikan hasil',
      () async {
        final registry = ProviderRegistry(
          providers: [
            _FakeProvider('a', const <AnimeDto>[]),
            _FakeProvider('b', [_dto('b', 'Jujutsu')]),
          ],
        );

        final result = await registry.searchAll('jjk');

        expect(result.length, 1);
        expect(result.first.provider, 'b');
      },
    );

    test('searchAll melewati provider yang melempar error', () async {
      final registry = ProviderRegistry(
        providers: [
          _FakeProvider('a', const <AnimeDto>[], shouldThrow: true),
          _FakeProvider('b', [_dto('b', 'Jujutsu')]),
        ],
      );

      final result = await registry.searchAll('jjk');

      expect(result.length, 1);
      expect(result.first.provider, 'b');
    });
  });

  group('ProviderAnimeRepository', () {
    test('search membungkus hasil di ApiEnvelope sukses', () async {
      final registry = ProviderRegistry(
        providers: [
          _FakeProvider('a', [_dto('a', 'Jujutsu')]),
        ],
      );
      final repository = ProviderAnimeRepository(registry: registry);

      final envelope = await repository.search('jjk');

      expect(envelope.isSuccess, isTrue);
      expect(envelope.data!.first.title, 'Jujutsu');
      expect(envelope.meta['provider'], 'a');
    });

    test('search mengembalikan ApiError saat semua provider gagal', () async {
      final registry = ProviderRegistry(
        providers: [_FakeProvider('a', const <AnimeDto>[], shouldThrow: true)],
      );
      final repository = ProviderAnimeRepository(registry: registry);

      final envelope = await repository.search('jjk');

      expect(envelope.isSuccess, isFalse);
      expect(envelope.error, isNotNull);
      expect(envelope.error!.provider, 'a');
    });

    test(
      'detail menolak ID yang tidak punya format provider:localId',
      () async {
        final registry = ProviderRegistry(providers: const <AnimeProvider>[]);
        final repository = ProviderAnimeRepository(registry: registry);

        final envelope = await repository.detail('tanpa-provider');

        expect(envelope.isSuccess, isFalse);
        expect(envelope.error!.code, 'INVALID_ID');
      },
    );
  });
}
