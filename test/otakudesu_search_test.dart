import 'package:animego/example-demo-apk/features/search-screen/data/otakudesu-search.dart';
import 'package:flutter_test/flutter_test.dart';

const String _otakudesuSearchHtml = '''
<html><body>
<ul class="chivsrc">
  <li style='list-style:none;'>
    <img src="https://otakudesu.blog/wp-content/uploads/2026/01/154488.jpg" />
    <h2><a href="https://otakudesu.blog/anime/jjk-s3-sub-indo/">Jujutsu Kaisen Season 3 Subtitle Indonesia</a></h2>
    <div class="set"><b>Genres</b> : <a href="https://otakudesu.blog/genres/action/">Action</a>, <a href="https://otakudesu.blog/genres/school/">School</a></div>
    <div class="set"><b>Status</b> : Ongoing</div>
    <div class="set"><b>Rating</b> : 7.57</div>
  </li>
  <li style='list-style:none;'>
    <img src="https://otakudesu.blog/wp-content/uploads/2024/03/jjk-s2.jpg" />
    <h2><a href="https://otakudesu.blog/anime/jjk-s2-sub-indo/">Jujutsu Kaisen Season 2</a></h2>
    <div class="set"><b>Genres</b> : <a href="https://otakudesu.blog/genres/fantasy/">Fantasy</a></div>
    <div class="set"><b>Status</b> : Completed</div>
    <div class="set"><b>Rating</b> : 8.85</div>
  </li>
  <li><span>item navigasi biasa, bukan hasil anime</span></li>
  <li style='list-style:none;'>
    <h2><a>Judul tanpa URL</a></h2>
  </li>
</ul>
</body></html>
''';

void main() {
  group('parseOtakudesuSearchResults', () {
    test('mengambil judul, url, gambar, rating, genre, dan status', () {
      final results = parseOtakudesuSearchResults(_otakudesuSearchHtml);

      expect(results, hasLength(2));

      final first = results.first;
      expect(first.title, 'Jujutsu Kaisen Season 3 Subtitle Indonesia');
      expect(first.sourceUrl, 'https://otakudesu.blog/anime/jjk-s3-sub-indo/');
      expect(first.detailUrl, 'https://otakudesu.blog/anime/jjk-s3-sub-indo/');
      expect(
        first.imageUrl,
        'https://otakudesu.blog/wp-content/uploads/2026/01/154488.jpg',
      );
      expect(first.rating, 7.57);
      expect(first.genres, ['Action', 'School']);
      expect(first.status, 'Ongoing');
    });

    test('mengabaikan li tanpa list-style:none dan tanpa href', () {
      final results = parseOtakudesuSearchResults(_otakudesuSearchHtml);

      expect(
        results.map((anime) => anime.title),
        isNot(contains('item navigasi biasa, bukan hasil anime')),
      );
      expect(
        results.map((anime) => anime.title),
        isNot(contains('Judul tanpa URL')),
      );
    });

    test('mengembalikan list kosong untuk html tanpa hasil', () {
      expect(parseOtakudesuSearchResults('<html><body></body></html>'), isEmpty);
    });

    test('menerima style list-style dengan spasi', () {
      const html = '''
      <li style="list-style: none;">
        <h2><a href="https://otakudesu.blog/anime/two/">Bleach</a></h2>
        <div class="set"><b>Status</b> : Completed</div>
      </li>
      ''';

      final results = parseOtakudesuSearchResults(html);

      expect(results, hasLength(1));
      expect(results.first.title, 'Bleach');
    });

    test('fallback genre Unknown saat blok Genres kosong', () {
      const html = '''
      <li style='list-style:none;'>
        <h2><a href="https://otakudesu.blog/anime/one/">One Piece</a></h2>
        <div class="set"><b>Genres</b> : </div>
        <div class="set"><b>Status</b> : Ongoing</div>
        <div class="set"><b>Rating</b> : 9.1</div>
      </li>
      ''';

      final results = parseOtakudesuSearchResults(html);

      expect(results, hasLength(1));
      expect(results.first.genres, ['Unknown']);
      expect(results.first.status, 'Ongoing');
      expect(results.first.rating, 9.1);
    });
  });
}
