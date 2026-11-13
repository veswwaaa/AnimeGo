import 'package:animego/core/providers/otakudesu/episodes.dart';
import 'package:animego/core/providers/otakudesu/search.dart';
import 'package:animego/core/providers/otakudesu/video.dart';
import 'package:flutter_test/flutter_test.dart';

const String _searchHtml = '''
<html><body>
  <li style='list-style:none;'>
    <img src="https://otakudesu.blog/wp-content/uploads/2026/01/154488.jpg" />
    <h2><a href="https://otakudesu.blog/anime/jjk-s3-sub-indo/">Jujutsu Kaisen Season 3</a></h2>
    <div class="set"><b>Genres</b> : <a href="#">Action</a></div>
    <div class="set"><b>Status</b> : Ongoing</div>
    <div class="set"><b>Rating</b> : 7.57</div>
  </li>
</ul>
</body></html>
''';

const String _animePageHtml = '''
<html><body>
  <a href="https://otakudesu.blog/episode/jujutsu-kaisen-episode-2-sub-indo/">Episode 2</a>
  <a href="https://otakudesu.blog/episode/jujutsu-kaisen-episode-10-sub-indo/">Episode 10</a>
  <a href="https://otakudesu.blog/episode/jujutsu-kaisen-episode-1-sub-indo/">Episode 1</a>
</body></html>
''';

void main() {
  group('parsing di background isolate', () {
    test('parseOtakudesuSearchResultsAsync menghasilkan hasil yang sama '
        'dengan versi sinkron', () async {
      final sync = parseOtakudesuSearchResults(_searchHtml);
      final async = await parseOtakudesuSearchResultsAsync(_searchHtml);

      expect(async, hasLength(sync.length));
      expect(async.first.title, sync.first.title);
      expect(async.first.sourceUrl, sync.first.sourceUrl);
      expect(async.first.rating, sync.first.rating);
      expect(async.first.genres, sync.first.genres);
    });

    test('parseOtakudesuEpisodesAsync mengurutkan episode by nomor', () async {
      final episodes = await parseOtakudesuEpisodesAsync(_animePageHtml);

      expect(episodes, hasLength(3));
      expect(episodes.first.url, contains('episode-1'));
      expect(episodes.last.url, contains('episode-10'));
    });

    test('parseOtakudesuAnimeDetailAsync mengembalikan DTO lengkap', () async {
      final detail = await parseOtakudesuAnimeDetailAsync(
        '<html><body><h1 class="entry-title">Bleach</h1>'
        '<div class="set"><b>Status</b> : Completed</div>'
        '</body></html>',
        sourceUrl: 'https://otakudesu.blog/anime/bleach/',
      );

      expect(detail.provider, 'otakudesu');
      expect(detail.title, 'Bleach');
      expect(detail.status, 'Completed');
      expect(detail.id.composite, startsWith('otakudesu:'));
    });

    test(
      'parseOtakudesuMirrorsAsync membaca mirror dari html episode',
      () async {
        const html = '''
            <div class="mirrorstream">
              <ul class="m720p">
                <li><a href="#" data-content="eyJpZCI6IjEiLCJpIjoiMiJ9">otakustream</a></li>
              </ul>
            </div>
            ''';

        final mirrors = await parseOtakudesuMirrorsAsync(html);

        expect(mirrors, hasLength(1));
        expect(mirrors.first.quality, '720p');
        expect(mirrors.first.provider, 'otakustream');
        expect(mirrors.first.data?['id'], '1');
      },
    );
  });
}
