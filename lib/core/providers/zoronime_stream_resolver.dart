import 'package:animego/core/utils/http_client.dart';
import 'package:animego/features/anime-detail-screen/data/google-blog-direct.dart';

/// Resolver URL stream yang dikembalikan backend zoronime.
///
/// Backend zoronime sering mengembalikan URL halaman embed
/// (desustream.info atau odvidhide.com), bukan file video langsung.
/// Fungsi ini mengubah URL embed tersebut menjadi URL video playable.
class ZoronimeStreamResolver {
  const ZoronimeStreamResolver._();

  /// Resolve halaman desustream menjadi URL video Blogger.
  static Future<String?> resolveDesustreamVideoUrl(String url) async {
    try {
      final result = await VideoScraperService.resolveVideoFromUrl(url);
      final videoUrl = result?.videoUrl;
      if (videoUrl == null || videoUrl.trim().isEmpty) {
        return null;
      }
      return videoUrl.trim();
    } catch (_) {
      return null;
    }
  }

  /// Resolve halaman odvidhide.com menjadi URL HLS index.
  static Future<String?> resolveOdvIdhideStreamUrl(String vidhideUrl) async {
    final embedUrl = Uri.tryParse(vidhideUrl.trim());
    if (embedUrl == null) {
      return null;
    }

    try {
      final response = await httpGetWithRetry(
        embedUrl,
        timeout: const Duration(seconds: 15),
        headers: const {
          'Referer': 'https://odvidhide.com/',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Gagal memuat halaman: HTTP ' + response.statusCode.toString(),
        );
      }

      final masterUrl = _extractMasterUrl(response.body);
      if (masterUrl == null) {
        throw Exception('URL hls2 tidak ditemukan');
      }

      return _toIndexUrl(masterUrl);
    } catch (_) {
      return null;
    }
  }

  /// Mengambil URL master m3u8 dari script JavaScript Packer.
  static String? _extractMasterUrl(String html) {
    final packerRegex = RegExp(
      r"eval\(function\(p,a,c,k,e,d\)[\s\S]+?\.split\('\|'\)\)\)",
    );
    final packerMatch = packerRegex.firstMatch(html);
    if (packerMatch == null) {
      return null;
    }

    final decodeRegex = RegExp(
      r"}\s*\(\s*'([\s\S]*?)'\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*'([\s\S]*?)'\.split\(\s*'\|'\s*\)",
    );
    final decodeMatch = decodeRegex.firstMatch(packerMatch.group(0)!);
    if (decodeMatch == null) {
      return null;
    }

    var p = decodeMatch.group(1)!;
    final radix = int.parse(decodeMatch.group(2)!);
    final count = int.parse(decodeMatch.group(3)!);
    final keys = decodeMatch.group(4)!.split('|');

    for (var i = count - 1; i >= 0; i--) {
      if (i < keys.length && keys[i].isNotEmpty) {
        final radixStr = i.toRadixString(radix);
        p = p.replaceAll(RegExp(r'\b' + radixStr + r'\b'), keys[i]);
      }
    }

    final objectRegex = RegExp(r"var\s+(?:links|o)\s*=\s*(\{[\s\S]*?\})\s*;");
    final objectMatch = objectRegex.firstMatch(p);
    if (objectMatch == null) {
      return null;
    }

    final hls2Regex = RegExp(r"""hls2""\s*:\s*""([^'"]+)""");
    final hls2Match = hls2Regex.firstMatch(objectMatch.group(1)!);
    return hls2Match?.group(1);
  }

  /// Mengubah master.m3u8 menjadi index-v1-a1.m3u8 (query tetap dipertahankan).
  static String _toIndexUrl(String masterUrl) {
    final queryStart = masterUrl.indexOf('?');
    var basePath = masterUrl;
    var queryString = '';

    if (queryStart != -1) {
      basePath = masterUrl.substring(0, queryStart);
      queryString = masterUrl.substring(queryStart);
    }

    return basePath.replaceAll(
      RegExp(r'master\.m3u8$'),
      'index-v1-a1.m3u8',
    ) + queryString;
  }
}
