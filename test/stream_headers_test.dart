import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:animego/core/dto/api_envelope.dart';
import 'package:animego/core/dto/api_v2_dto.dart';
import 'package:animego/core/dto/episode_dto.dart';
import 'package:animego/core/providers/nimegami/nimegami_provider_v2.dart';

void main() {
  group('ApiEpisodeDetail.streamHeaders', () {
    test('header dari API dibaca sebagai Map<String, String>', () {
      final detail = ApiEpisodeDetail.fromJson(<String, dynamic>{
        'id': 'nimegami:stone-ocean#1',
        'animeId': 'nimegami:stone-ocean',
        'provider': 'nimegami',
        'number': 1,
        'streamUrl': 'https://vidcache.net:8161/video.mp4',
        'streamHeaders': <String, dynamic>{
          'Referer': 'https://yourupload.com/',
        },
      });

      expect(detail.streamHeaders, <String, String>{
        'Referer': 'https://yourupload.com/',
      });
    });

    test('header yang hilang menghasilkan map kosong', () {
      final detail = ApiEpisodeDetail.fromJson(<String, dynamic>{
        'id': 'nimegami:stone-ocean#1',
        'animeId': 'nimegami:stone-ocean',
        'provider': 'nimegami',
        'number': 1,
      });

      expect(detail.streamHeaders, isEmpty);
    });
  });

  group('NimegamiProviderV2 stream headers', () {
    test('stream meneruskan streamHeaders dari API ke StreamDto', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode(<String, dynamic>{
            'success': true,
            'data': <String, dynamic>{
              'id': 'nimegami:stone-ocean#1',
              'animeId': 'nimegami:stone-ocean',
              'provider': 'nimegami',
              'number': 1,
              'streamUrl': 'https://vidcache.net:8161/video.mp4',
              'streamHeaders': <String, dynamic>{
                'Referer': 'https://yourupload.com/',
              },
            },
            'meta': <String, dynamic>{},
            'error': null,
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        ),
      );

      final provider = NimegamiProviderV2(client: client);
      final stream = await provider.getStreamUrl(
        EpisodeDto(
          id: const AnimeId('nimegami', 'stone-ocean#1'),
          animeId: const AnimeId('nimegami', 'stone-ocean'),
          number: 1,
          url: 'https://nimegami.id/stone-ocean-sub-indo/',
        ),
      );

      expect(stream.url, 'https://vidcache.net:8161/video.mp4');
      expect(stream.headers, <String, String>{
        'Referer': 'https://yourupload.com/',
      });
    });

    test('stream tanpa streamHeaders menghasilkan header kosong', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode(<String, dynamic>{
            'success': true,
            'data': <String, dynamic>{
              'id': 'nimegami:stone-ocean#1',
              'animeId': 'nimegami:stone-ocean',
              'provider': 'nimegami',
              'number': 1,
              'streamUrl': 'https://cdn.test/master.mp4',
            },
            'meta': <String, dynamic>{},
            'error': null,
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        ),
      );

      final provider = NimegamiProviderV2(client: client);
      final stream = await provider.getStreamUrl(
        EpisodeDto(
          id: const AnimeId('nimegami', 'stone-ocean#1'),
          animeId: const AnimeId('nimegami', 'stone-ocean'),
          number: 1,
          url: 'https://nimegami.id/stone-ocean-sub-indo/',
        ),
      );

      expect(stream.headers, isEmpty);
    });
  });
}