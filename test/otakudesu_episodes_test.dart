import 'package:animego/features/search-screen/data/otakudesu-episodes.dart';
import 'package:animego/features/search-screen/data/otakudesu-video.dart';
import 'package:flutter_test/flutter_test.dart';

const String _animePageHtml = '''
<html><body>
<div class="episodelist"><ul>
  <li><span><a href="https://otakudesu.blog/episode/jobzadrvnt-episode-26-sub-indo/">JoJo Episode 26 (End)</a></span></li>
  <li><span><a href="https://otakudesu.blog/episode/jobzadrvnt-episode-25-sub-indo/">JoJo Episode 25</a></span></li>
  <li><span><a href="https://otakudesu.blog/episode/jobzadrvnt-episode-24-sub-indo/">JoJo Episode 24</a></span></li>
</ul></div>
<a href="https://otakudesu.blog/batch/jobzadrvnt-batch-sub-indo/">Batch</a>
<a href="https://otakudesu.blog/anime/other/">Anime lain</a>
</body></html>
''';

const String _episodePageHtml = '''
<html><body>
<div class="mirrorstream" style="width:100%">
  <ul class="m360p"><li><a href="#" data-content="eyJpZCI6NDk3NDEsImkiOjAsInEiOiIzNjBwIn0=">mega</a></li></ul>
  <ul class="m480p">
    <li><a href="#" data-content="eyJpZCI6NDk3NDEsImkiOjAsInEiOiI0ODBwIn0=" data-default="true">nekoclouds</a></li>
    <li><a href="#" data-content="eyJpZCI6NDk3NDEsImkiOjMsInEiOiI0ODBwIn0=">otakustream</a></li>
  </ul>
  <ul class="m720p"><li><a href="#" data-content="eyJpZCI6NDk3NDEsImkiOjAsInEiOiI3MjBwIn0=">mega</a></li></ul>
</div>
</body></html>
''';

void main() {
  group('parseOtakudesuEpisodes', () {
    test('mengambil link episode dan mengurutkan dari nomor terkecil', () {
      final episodes = parseOtakudesuEpisodes(_animePageHtml);

      expect(episodes, hasLength(3));
      expect(episodes.map((episode) => episode.url), [
        'https://otakudesu.blog/episode/jobzadrvnt-episode-24-sub-indo/',
        'https://otakudesu.blog/episode/jobzadrvnt-episode-25-sub-indo/',
        'https://otakudesu.blog/episode/jobzadrvnt-episode-26-sub-indo/',
      ]);
      expect(episodes.first.title, 'JoJo Episode 24');
    });

    test('mengabaikan link batch dan link anime', () {
      final episodes = parseOtakudesuEpisodes(_animePageHtml);

      expect(
        episodes.map((episode) => episode.url),
        everyElement(contains('/episode/')),
      );
    });
  });

  group('parseOtakudesuMirrors', () {
    test('membaca kualitas, provider, dan payload data-content', () {
      final mirrors = parseOtakudesuMirrors(_episodePageHtml);

      expect(mirrors, hasLength(4));

      final otakustream = mirrors.firstWhere(
        (mirror) => mirror.provider == 'otakustream',
      );
      expect(otakustream.quality, '480p');
      expect(otakustream.data?['id'], 49741);
      expect(otakustream.data?['i'], 3);
      expect(otakustream.isDefault, isFalse);
    });

    test('menandai mirror default', () {
      final mirrors = parseOtakudesuMirrors(_episodePageHtml);

      final nekoclouds = mirrors.firstWhere(
        (mirror) => mirror.provider == 'nekoclouds',
      );
      expect(nekoclouds.isDefault, isTrue);
    });

    test('mengabaikan mirror tanpa data-content', () {
      const html = '''
      <div class="mirrorstream">
        <ul class="m360p"><li><a href="#">tanpa data</a></li></ul>
      </div>
      ''';

      expect(parseOtakudesuMirrors(html), isEmpty);
    });
  });

  group('extractOtakudesuPlayerFileUrl', () {
    test('mengambil file dari script json player desudrive', () {
      const html = '''
      <script>
      function otakudesu(e) { jwplayer.key = "abc"; }
      otakudesu('{"file":"https://drive.google.com/file.mp4","img":"x"}');
      </script>
      ''';

      expect(
        extractOtakudesuPlayerFileUrl(html),
        'https://drive.google.com/file.mp4',
      );
    });

    test('mengambil source dari player otakustream', () {
      const html = '''
      <video controls>
        <source src="https://rr3.googlevideo.com/videoplayback?a=1&amp;b=2" type="video/mp4">
      </video>
      ''';

      expect(
        extractOtakudesuPlayerFileUrl(html),
        'https://rr3.googlevideo.com/videoplayback?a=1&b=2',
      );
    });

    test('mengembalikan null saat tidak ada file', () {
      expect(extractOtakudesuPlayerFileUrl('<html></html>'), isNull);
    });
  });
}
