import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:animego/core/dto/anime_dto.dart';
import 'package:animego/core/dto/api_envelope.dart';
import 'package:animego/core/dto/episode_dto.dart';
import 'package:animego/core/dto/stream_dto.dart';
import 'package:animego/core/models/anime.dart';
import 'package:animego/core/models/anime_mapper.dart';
import 'package:animego/core/providers/anime_provider.dart';
import 'package:animego/core/providers/nimegami/nimegami_provider_v2.dart';
import 'package:animego/core/providers/provider_container.dart';
import 'package:animego/core/providers/provider_registry.dart';
import 'package:animego/features/anime-detail-screen/presentation/anime-detail-screen.dart';

/// Provider palsu yang mencatat pemanggilan detail/episodes/stream.
class _RecordingProvider extends AnimeProvider {
  _RecordingProvider();

  int detailCalls = 0;
  int episodeCalls = 0;

  @override
  String get id => 'nimegami';

  @override
  String get displayName => 'Nimegami';

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
  Future<List<AnimeDto>> search(String query) async => const <AnimeDto>[];

  @override
  Future<AnimeDto> getDetail(String sourceUrl) async {
    detailCalls++;
    return AnimeDto(
      id: const AnimeId('nimegami', 'stone-ocean'),
      provider: 'nimegami',
      title: 'Stone Ocean',
      image: 'https://img/poster.jpg',
      description: 'Warisan keluarga Joestar berlanjut.',
      genres: const <String>['Action'],
      status: 'Tamat',
      rating: 8.6,
      totalEpisodes: 26,
      url: 'https://nimegami.id/stone-ocean-sub-indo/',
      episodeListUrl: 'https://nimegami.id/stone-ocean-sub-indo/',
    );
  }

  @override
  Future<List<EpisodeDto>> getEpisodes(String sourceUrl) async {
    episodeCalls++;
    return List<EpisodeDto>.generate(
      3,
      (index) => EpisodeDto(
        id: AnimeId('nimegami', 'stone-ocean#${index + 1}'),
        animeId: const AnimeId('nimegami', 'stone-ocean'),
        number: index + 1,
        url: 'https://nimegami.id/stone-ocean-sub-indo/',
      ),
      growable: false,
    );
  }

  @override
  Future<StreamDto> getStreamUrl(EpisodeDto episode) async {
    return StreamDto(episodeId: episode.id, type: 'direct', url: 'https://s/x');
  }
}

Map<String, dynamic> _searchEnvelope() {
  return <String, dynamic>{
    'success': true,
    'data': <String, dynamic>{
      'items': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'nimegami:stone-ocean',
          'provider': 'nimegami',
          'title': 'Stone Ocean',
          'image': 'https://img/poster.jpg',
          'genres': <String>['Action'],
          'status': null,
          'rating': 8.6,
          'totalEpisodes': 26,
          'url': 'https://nimegami.id/stone-ocean-sub-indo/',
        },
      ],
      'query': 'stone ocean',
    },
    'meta': <String, dynamic>{'provider': 'nimegami'},
    'error': null,
  };
}

void main() {
  group('NimegamiProviderV2', () {
    test('hanya memanggil endpoint /api/v2/nimegami/*', () async {
      final requested = <String>[];
      final client = MockClient((request) async {
        requested.add(request.url.toString());
        return http.Response(
          jsonEncode(_searchEnvelope()),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });

      final provider = NimegamiProviderV2(client: client);
      final results = await provider.search('stone ocean');

      expect(results.length, 1);
      expect(requested, isNotEmpty);
      for (final url in requested) {
        expect(
          url,
          contains('/api/v2/nimegami/'),
          reason: 'jalur v1 tidak boleh dipakai: $url',
        );
        expect(url, isNot(contains('/api/nimegami/')));
      }
    });

    test('search memetakan id komposit provider:localId', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode(_searchEnvelope()),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        ),
      );

      final provider = NimegamiProviderV2(client: client);
      final results = await provider.search('stone ocean');

      expect(results.single.id.composite, 'nimegami:stone-ocean');
      expect(results.single.id.providerId, 'nimegami');
      expect(results.single.id.localId, 'stone-ocean');
    });

    test('error 404 dari server diterjemahkan jadi pesan eksplisit', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode(<String, dynamic>{
            'success': false,
            'data': null,
            'meta': <String, dynamic>{},
            'error': <String, dynamic>{
              'code': 'NOT_FOUND',
              'message': 'Anime tidak ditemukan',
              'status': 404,
              'retryable': false,
            },
          }),
          404,
          headers: <String, String>{'content-type': 'application/json'},
        ),
      );

      final provider = NimegamiProviderV2(client: client);

      await expectLater(
        provider.getDetail('https://nimegami.id/tidak-ada-sub-indo/'),
        throwsA(
          isA<Object>().having(
            (Object e) => e.toString(),
            'message',
            contains('Anime tidak ditemukan'),
          ),
        ),
      );
    });
  });

  group('animeDtoToModel', () {
    test('mengisi Anime.id dengan id komposit provider:localId', () {
      final dto = AnimeDto(
        id: const AnimeId('nimegami', 'stone-ocean'),
        provider: 'nimegami',
        title: 'Stone Ocean',
        image: 'https://img/poster.jpg',
        url: 'https://nimegami.id/stone-ocean-sub-indo/',
      );

      final model = animeDtoToModel(dto);

      expect(model.id, 'nimegami:stone-ocean');
      expect(model.id.startsWith('nimegami:'), isTrue);
      expect(model.id.contains('https://'), isFalse);
    });
  });

  group('AnimeDetailScreen', () {
    testWidgets('memanggil repository.detail() saat initState', (
      WidgetTester tester,
    ) async {
      final provider = _RecordingProvider();
      final registry = ProviderRegistry(providers: <AnimeProvider>[provider]);
      ProviderContainer.instance = ProviderContainer.create(registry: registry);

      await tester.pumpWidget(
        MaterialApp(
          home: AnimeDetailScreen(
            anime: Anime(
              title: 'Stone Ocean',
              imageUrl: 'https://img/poster.jpg',
              rating: 8.6,
              genres: const <String>['Action'],
              sourceUrl: 'https://nimegami.id/stone-ocean-sub-indo/',
              episodes: 26,
              providerId: 'nimegami',
              id: 'nimegami:stone-ocean',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(provider.detailCalls, 1);
      expect(find.textContaining('Stone Ocean'), findsWidgets);
    });

    testWidgets('menampilkan sinopsis, status, dan episode dari detail', (
      WidgetTester tester,
    ) async {
      final provider = _RecordingProvider();
      final registry = ProviderRegistry(providers: <AnimeProvider>[provider]);
      ProviderContainer.instance = ProviderContainer.create(registry: registry);

      await tester.pumpWidget(
        MaterialApp(
          home: AnimeDetailScreen(
            anime: Anime(
              title: 'Stone Ocean',
              imageUrl: 'https://img/poster.jpg',
              rating: 8.6,
              genres: const <String>['Action'],
              sourceUrl: 'https://nimegami.id/stone-ocean-sub-indo/',
              episodes: 26,
              providerId: 'nimegami',
              id: 'nimegami:stone-ocean',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Warisan keluarga Joestar'), findsOneWidget);
      expect(find.textContaining('Tamat'), findsOneWidget);
      expect(find.text('Episode 1'), findsOneWidget);
    });
  });
}
