import 'package:flutter_test/flutter_test.dart';

import 'package:animego/core/mappers/mal_mapper.dart';

void main() {
  group('MalMapper.user', () {
    test('memetakan /v2/users/@me ke model user internal', () {
      final user = MalMapper.user({
        'id': 123,
        'name': 'Anime Fan',
        'user_name': 'animefan',
        'picture': 'https://cdn.myanimelist.net/images/user.jpg',
        'anime_statistics': {'count_anime': 42},
      });

      expect(user.id, 123);
      expect(user.username, 'animefan');
      expect(user.name, 'Anime Fan');
      expect(user.avatarUrl, 'https://cdn.myanimelist.net/images/user.jpg');
      expect(user.animeCount, 42);
    });

    test('username profil sama dengan username MAL (fallback name)', () {
      final user = MalMapper.user({'id': 1, 'name': 'Solo'});
      expect(user.username, 'Solo');
    });

    test('picture kosong menghasilkan avatarUrl null', () {
      final user = MalMapper.user({'id': 1, 'user_name': 'x', 'picture': ''});
      expect(user.avatarUrl, isNull);
    });
  });

  group('MalMapper.list', () {
    test('memetakan payload list animelist', () {
      final entries = MalMapper.list({
        'data': [
          {
            'node': {
              'id': 1,
              'title': 'One Piece',
              'num_episodes': 1000,
              'list_status': {
                'status': 1,
                'score': 9,
                'num_episodes_watched': 500,
              },
            },
          },
        ],
      });

      expect(entries.length, 1);
      expect(entries.first.malAnimeId, 1);
      expect(entries.first.title, 'One Piece');
      expect(entries.first.status, 1);
      expect(entries.first.score, 9);
      expect(entries.first.numWatchedEpisodes, 500);
      expect(entries.first.totalEpisodes, 1000);
    });

    test('payload kosong menghasilkan list kosong', () {
      expect(MalMapper.list(<String, dynamic>{}), isEmpty);
    });
  });
}
