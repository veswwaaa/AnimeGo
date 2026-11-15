import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:animego/core/providers/nimegami/nimegami_provider_v2.dart';

void main() {
  test('live probe nimegami v2', () async {
    for (final q in <String>['jojo', 'one piece', 'naruto']) {
      final uri = Uri.parse(
        'https://kevinapienim.vercel.app/api/v2/nimegami/search',
      ).replace(queryParameters: <String, String>{
        'q': q,
        'page': '1',
        'limit': '20',
      });
      // ignore: avoid_print
      print('URL $q => $uri');

      final res = await http.get(
        uri,
        headers: <String, String>{
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
          'Accept-Language': 'id-ID,id;q=0.9,en-US;q=0.8',
        },
      );
      // ignore: avoid_print
      print(
        'status ${res.statusCode} body ${res.body.substring(0, res.body.length < 300 ? res.body.length : 300)}',
      );

      final provider = NimegamiProviderV2();
      try {
        final items = await provider.search(q);
        // ignore: avoid_print
        print(
          'provider search $q => ${items.length} items, first=${items.isEmpty ? '-' : items.first.id.composite}',
        );
      } catch (e) {
        // ignore: avoid_print
        print('provider search $q ERROR $e');
      }
    }
  });
}
