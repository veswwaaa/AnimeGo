import 'package:animego/core/dto/api_v2_dto.dart';
import 'package:animego/core/dto/api_v2_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiV2Envelope', () {
    test('parse envelope sukses dengan data search', () {
      final envelope = parseApiV2Envelope<Map<String, dynamic>>(
        {
          'success': true,
          'data': {'items': [], 'query': 'naruto'},
          'meta': {'provider': 'nimegami', 'contractVersion': 'v2'},
          'error': null,
        },
        (json) => json,
      );

      expect(envelope.isSuccess, isTrue);
      expect(envelope.error, isNull);
      expect(envelope.meta.provider, 'nimegami');
      expect(envelope.meta.contractVersion, 'v2');
    });

    test('parse envelope error menghasilkan failure tanpa exception', () {
      final envelope = parseApiV2Envelope<Map<String, dynamic>>(
        {
          'success': false,
          'data': null,
          'meta': {'provider': 'zoronime'},
          'error': {
            'code': 'NOT_FOUND',
            'message': 'Anime tidak ditemukan',
            'provider': 'zoronime',
            'retryable': false,
            'status': 404,
          },
        },
        (json) => json,
      );

      expect(envelope.isSuccess, isFalse);
      expect(envelope.data, isNull);
      expect(envelope.error?.code, ApiErrorCode.notFound);
      expect(envelope.error?.status, 404);
    });

    test('payload rusak menghasilkan error PARSE_ERROR', () {
      final envelope = parseApiV2Envelope<Map<String, dynamic>>(
        {
          'success': true,
          'data': 'bukan-object',
          'meta': <String, dynamic>{},
          'error': null,
        },
        (json) => json,
      );

      expect(envelope.isSuccess, isFalse);
      expect(envelope.error?.code, ApiErrorCode.parseError);
    });
  });

  group('ApiSearchResponse', () {
    test('mengubah list item menjadi ApiSearchItem', () {
      final response = ApiSearchResponse.fromJson({
        'query': 'naruto',
        'items': [
          {
            'id': 'naru',
            'provider': 'nimegami',
            'title': 'Naruto',
            'url': 'https://nimegami.id/anime/naruto',
            'genres': ['Action'],
            'rating': 8.1,
          },
        ],
      });

      expect(response.items.length, 1);
      expect(response.items.first.title, 'Naruto');
      expect(response.items.first.genres, ['Action']);
      expect(response.items.first.rating, 8.1);
    });
  });

  group('mapper ke DTO internal', () {
    test('detail canonical jadi AnimeDto dengan provider id komposit', () {
      final dto = animeDtoFromApiDetail(
        const ApiAnimeDetail(
          id: 'https://nimegami.id/anime/naruto',
          provider: 'nimegami',
          title: 'Naruto',
          image: 'https://img/naruto.jpg',
          description: 'Story',
          genres: ['Action'],
          rating: 8.1,
          totalEpisodes: 220,
          url: 'https://nimegami.id/anime/naruto',
        ),
      );

      expect(dto.id.composite, 'nimegami:https://nimegami.id/anime/naruto');
      expect(dto.provider, 'nimegami');
      expect(dto.totalEpisodes, 220);
      expect(dto.genres, ['Action']);
    });

    test('episode canonical jadi EpisodeDto', () {
      final dto = episodeDtoFromApiEpisode(
        const ApiEpisode(
          id: 'nimegami:abc#3',
          animeId: 'nimegami:abc',
          provider: 'nimegami',
          number: 3,
          url: 'https://nimegami.id/episode/3',
        ),
      );

      expect(dto.id.composite, 'nimegami:abc#3');
      expect(dto.animeId.composite, 'nimegami:abc');
      expect(dto.number, 3);
    });

    test('stream canonical jadi StreamDto dengan mirrors', () {
      final dto = streamDtoFromApiStream(
        const ApiStream(
          episodeId: 'zoronime:abc#1',
          provider: 'zoronime',
          type: 'hls',
          url: 'https://cdn/master.m3u8',
          mirrors: [
            ApiStreamMirror(url: 'https://cdn2/master.m3u8', quality: '720p'),
          ],
        ),
      );

      expect(dto.type, 'hls');
      expect(dto.url, 'https://cdn/master.m3u8');
      expect(dto.mirrors.length, 1);
      expect(dto.mirrors.first.quality, '720p');
      expect(dto.episodeId.composite, 'zoronime:abc#1');
    });
  });

  group('ApiEpisodeDetail (endpoint /episode)', () {
    test('baca streamUrl, server, dan kualitas dari payload canonical', () {
      final detail = ApiEpisodeDetail.fromJson({
        'id': 'nimegami:one-piece#3',
        'animeId': 'nimegami:one-piece',
        'provider': 'nimegami',
        'number': 3,
        'title': 'Episode 3',
        'url': 'https://nimegami.id/one-piece/#episode_3',
        'animeUrl': 'https://nimegami.id/one-piece/',
        'streamUrl': 'https://cdn.test/master.m3u8',
        'streamUrlDefaultServer': 'https://cdn.test/720.m3u8',
        'defaultQuality': '720p',
        'defaultServerName': 'Berkasdrive [KC]',
        'server': [
          {'name': 'Berkasdrive [KC]', 'mediaId': 'abc', 'quality': '720p'},
        ],
        'kualitas': ['360p', '720p'],
      });

      expect(detail.number, 3);
      expect(detail.animeUrl, 'https://nimegami.id/one-piece/');
      expect(detail.streamUrl, 'https://cdn.test/master.m3u8');
      expect(detail.streamUrlDefaultServer, 'https://cdn.test/720.m3u8');
      expect(detail.defaultQuality, '720p');
      expect(detail.defaultServerName, 'Berkasdrive [KC]');
      expect(detail.server.length, 1);
      expect(detail.server.first.name, 'Berkasdrive [KC]');
      expect(detail.server.first.quality, '720p');
      expect(detail.kualitas, ['360p', '720p']);
    });

    test('backward compatible: key lama streamUrl720pdefaultserver tetap dibaca', () {
      final detail = ApiEpisodeDetail.fromJson(<String, dynamic>{
        'id': 'nimegami:one-piece#1',
        'animeId': 'nimegami:one-piece',
        'provider': 'nimegami',
        'number': 1,
        'streamUrl720pdefaultserver': 'https://cdn.test/legacy.m3u8',
      });

      expect(detail.streamUrlDefaultServer, 'https://cdn.test/legacy.m3u8');
    });

    test('streamUrl null tetap valid (normal, bukan error)', () {
      final detail = ApiEpisodeDetail.fromJson({
        'id': 'nimegami:one-piece#1',
        'animeId': 'nimegami:one-piece',
        'provider': 'nimegami',
        'number': 1,
      });

      expect(detail.streamUrl, isNull);
      expect(detail.server, isEmpty);
      expect(detail.kualitas, isEmpty);
    });
  });

  group('ApiAnimeDetail episodes', () {
    test('detail memuat daftar episode dari endpoint /detail', () {
      final detail = ApiAnimeDetail.fromJson({
        'id': 'nimegami:one-piece',
        'provider': 'nimegami',
        'title': 'One Piece',
        'url': 'https://nimegami.id/one-piece/',
        'type': 'SERIES',
        'episodes': [
          {
            'id': 'nimegami:one-piece#1',
            'animeId': 'nimegami:one-piece',
            'provider': 'nimegami',
            'number': 1,
            'url': 'https://nimegami.id/one-piece/',
          },
          {
            'id': 'nimegami:one-piece#2',
            'animeId': 'nimegami:one-piece',
            'provider': 'nimegami',
            'number': 2,
            'url': 'https://nimegami.id/one-piece/',
          },
        ],
      });

      expect(detail.type, 'SERIES');
      expect(detail.episodes.length, 2);
      expect(detail.episodes.last.number, 2);
    });
  });

  group('id komposit backend tidak jadi ganda', () {
    test('detail dengan id komposit menghasilkan localId yang benar', () {
      final dto = animeDtoFromApiDetail(
        const ApiAnimeDetail(
          id: 'nimegami:one-piece',
          provider: 'nimegami',
          title: 'One Piece',
          url: 'https://nimegami.id/one-piece/',
        ),
      );

      expect(dto.id.composite, 'nimegami:one-piece');
    });

    test('search item dengan id komposit menghasilkan localId yang benar', () {
      final dto = animeDtoFromApiSearchItem(
        const ApiSearchItem(
          id: 'nimegami:naruto',
          provider: 'nimegami',
          title: 'Naruto',
          url: 'https://nimegami.id/naruto/',
        ),
      );

      expect(dto.id.composite, 'nimegami:naruto');
    });

    test('id non-komposit (URL penuh) tetap dipakai apa adanya', () {
      final dto = animeDtoFromApiDetail(
        const ApiAnimeDetail(
          id: 'https://nimegami.id/anime/naruto',
          provider: 'nimegami',
          title: 'Naruto',
          url: 'https://nimegami.id/anime/naruto',
        ),
      );

      expect(dto.id.composite, 'nimegami:https://nimegami.id/anime/naruto');
    });
  });
}
