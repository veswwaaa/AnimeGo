import 'dart:convert';

import 'package:animego/core/utils/utils.dart';
import 'package:animego/core/providers/otakudesu/parse.dart';
import 'package:animego/core/providers/otakudesu/search.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;

/// Port Dart dari `src/otakudesu/features/mirrors.ts`,
/// `src/otakudesu/features/video.ts`, dan `src/otakudesu/features/finalVideo.ts`.

/// Satu mirror streaming yang tersedia di halaman episode.
class OtakudesuMirror {
  final String quality;
  final String provider;
  final String content;
  final Map<String, dynamic>? data;
  final bool isDefault;

  const OtakudesuMirror({
    required this.quality,
    required this.provider,
    required this.content,
    required this.data,
    required this.isDefault,
  });
}

/// Hasil resolusi mirror untuk satu halaman episode.
class OtakudesuMirrorsResponse {
  final String url;
  final OtakudesuMirror? selected;
  final List<OtakudesuMirror> mirrors;

  const OtakudesuMirrorsResponse({
    required this.url,
    required this.selected,
    required this.mirrors,
  });
}

/// Hasil akhir pemanggilan video: stream siap diputar.
class OtakudesuVideoResult {
  final bool success;
  final String? quality;
  final String? provider;
  final String? iframeHtml;
  final String? streamUrl;
  final String? errorMessage;

  const OtakudesuVideoResult({
    required this.success,
    this.quality,
    this.provider,
    this.iframeHtml,
    this.streamUrl,
    this.errorMessage,
  });
}

const String _ajaxUrl = 'https://otakudesu.blog/wp-admin/admin-ajax.php';
const String _nonceAction = 'aa1208d27f29ca340c92c66d1926f13f';
const String _streamAction = '2a3505c93b0035d3f455df82bf976b84';

/// Header AJAX sesuai `AJAX_HEADERS` di `utils.ts`.
Map<String, String> _ajaxHeaders(String referer) {
  return {
    ...otakudesuBrowserHeaders,
    'Accept': '*/*',
    'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
    'X-Requested-With': 'XMLHttpRequest',
    'Origin': 'https://otakudesu.blog',
    'Referer': referer,
  };
}

/// Mengambil daftar mirror dari halaman episode Otakudesu.
///
/// Setara `getAnimeMirrors` pada `mirrors.ts`.
Future<OtakudesuMirrorsResponse> getOtakudesuMirrors(String url) async {
  try {
    final response = await httpGetWithRetry(
      Uri.parse(url),
      headers: {
        ...otakudesuBrowserHeaders,
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      },
      timeout: const Duration(seconds: 15),
      maxAttempts: 2,
    );

    final mirrors = await parseOtakudesuMirrorsAsync(response.body);
    if (mirrors.isEmpty) {
      throw Exception(
        'Mirror video tidak ditemukan. Pastikan URL yang digunakan adalah '
        'halaman episode yang sudah memiliki mirror.',
      );
    }

    final selected = _selectPreferredMirror(mirrors);

    return OtakudesuMirrorsResponse(
      url: url,
      selected: selected,
      mirrors: mirrors,
    );
  } catch (error, stackTrace) {
    logDev(
      'getOtakudesuMirrors gagal: $error\n$stackTrace',
      prefix: 'getOtakudesuMirrors:',
    );
    rethrow;
  }
}

/// Mengubah HTML halaman episode menjadi daftar mirror.
///
/// Parsing dijalankan di background isolate lewat `compute()`.
Future<List<OtakudesuMirror>> parseOtakudesuMirrorsAsync(String html) async {
  final records = await compute(parseOtakudesuMirrorRecords, html);

  return records.map(_mirrorFromRecord).toList();
}

/// Mengubah HTML halaman episode menjadi daftar mirror (versi sinkron).
List<OtakudesuMirror> parseOtakudesuMirrors(String html) {
  final records = parseOtakudesuMirrorRecords(html);
  return records.map(_mirrorFromRecord).toList();
}

/// Mengubah satu record mirror menjadi [OtakudesuMirror].
OtakudesuMirror _mirrorFromRecord(Map<String, dynamic> record) {
  return OtakudesuMirror(
    quality: record['quality']?.toString() ?? '',
    provider: record['provider']?.toString() ?? '',
    content: record['content']?.toString() ?? '',
    data: record['data'] as Map<String, dynamic>?,
    isDefault: record['isDefault'] as bool? ?? false,
  );
}

/// Memilih mirror utama: 720p dengan provider streaming, lalu default, lalu 720p.
///
/// Mengikuti `getAnimeVideo` di `video.ts`.
OtakudesuMirror? _selectPreferredMirror(List<OtakudesuMirror> mirrors) {
  bool isStreamingProvider(String provider) {
    final normalized = provider.toLowerCase();
    return normalized == 'odstream';
  }

  return _firstWhere(
        mirrors,
        (mirror) =>
            mirror.quality == '720p' && isStreamingProvider(mirror.provider),
      ) ??
      _firstWhere(mirrors, (mirror) => isStreamingProvider(mirror.provider)) ??
      _firstWhere(mirrors, (mirror) => mirror.isDefault) ??
      _firstWhere(mirrors, (mirror) => mirror.quality == '720p');
}

OtakudesuMirror? _firstWhere(
  List<OtakudesuMirror> mirrors,
  bool Function(OtakudesuMirror mirror) test,
) {
  for (final mirror in mirrors) {
    if (test(mirror)) {
      return mirror;
    }
  }
  return null;
}

/// Mengambil URL video siap diputar untuk satu episode Otakudesu.
///
/// Setara `getAnimeVideo` pada `video.ts`.
Future<OtakudesuVideoResult> getOtakudesuVideo(String url) async {
  try {
    final mirrorResult = await getOtakudesuMirrors(url);
    final targetMirror = mirrorResult.selected;

    if (targetMirror == null || targetMirror.data == null) {
      return const OtakudesuVideoResult(
        success: false,
        errorMessage: 'Mirror yang diinginkan (otakustream) tidak ditemukan.',
      );
    }

    final nonce = await _fetchNonce(url);

    final streamResponse = await httpPostWithRetry(
      Uri.parse(_ajaxUrl),
      headers: _ajaxHeaders(url),
      body: {
        'id': '${targetMirror.data!['id']}',
        'i': '${targetMirror.data!['i']}',
        'q': targetMirror.quality,
        'nonce': nonce,
        'action': _streamAction,
      },
      timeout: const Duration(seconds: 15),
      maxAttempts: 2,
    );

    final rawBase64Html = _readAjaxData(streamResponse.body);
    if (rawBase64Html == null || rawBase64Html.isEmpty) {
      throw Exception('Tidak ada data stream yang dikembalikan oleh server');
    }

    final decodedHtml = utf8.decode(base64Decode(rawBase64Html));
    final document = html_parser.parse(decodedHtml);
    final iframeSrc = document.querySelector('iframe')?.attributes['src'];

    String? streamUrl;
    if (iframeSrc != null && iframeSrc.isNotEmpty) {
      streamUrl =
          RegExp(r'desustream\.net', caseSensitive: false).hasMatch(iframeSrc)
          ? await getOtakudesuFinalDirectVideoUrl(iframeSrc)
          : iframeSrc;
    }

    logDev(
      'getOtakudesuVideo stream: $streamUrl',
      prefix: 'getOtakudesuVideo:',
    );

    return OtakudesuVideoResult(
      success: true,
      quality: targetMirror.quality,
      provider: targetMirror.provider,
      iframeHtml: decodedHtml,
      streamUrl: streamUrl,
    );
  } catch (error, stackTrace) {
    final message = error.toString();
    logDev(
      'getOtakudesuVideo gagal: $message\n$stackTrace',
      prefix: 'getOtakudesuVideo:',
    );
    return OtakudesuVideoResult(success: false, errorMessage: message);
  }
}

/// Mengambil URL video final dari halaman desustream.net.
///
/// Setara `getFinalDirectVideoUrl` pada `finalVideo.ts`.
Future<String> getOtakudesuFinalDirectVideoUrl(String desustreamUrl) async {
  final pageResponse = await httpGetWithRetry(
    Uri.parse(desustreamUrl),
    headers: {...otakudesuBrowserHeaders, 'Referer': 'https://otakudesu.blog/'},
    timeout: const Duration(seconds: 15),
    maxAttempts: 2,
  );

  final fileUrl = extractOtakudesuPlayerFileUrl(pageResponse.body);
  if (fileUrl == null) {
    throw Exception(
      'URL file video tidak ditemukan di dalam player desustream',
    );
  }

  return httpHeadFinalUrl(fileUrl);
}

/// Mengambil URL video dari halaman player.
///
/// Player desustream/desudrive memuat file JSON di dalam script
/// (`file: "..."`), sedangkan player otakustream memakai tag `<source src>`.
String? extractOtakudesuPlayerFileUrl(String html) {
  final jsonMatch = RegExp(
    r"""otakudesu\('(\{.*?\})'\)""",
    dotAll: true,
  ).firstMatch(html);

  if (jsonMatch != null) {
    try {
      final json = jsonDecode(jsonMatch.group(1)!);
      if (json is Map<String, dynamic>) {
        final file = json['file']?.toString().trim() ?? '';
        if (file.isNotEmpty) {
          return file;
        }
      }
    } catch (_) {
      // Lanjut ke parsing tag <source>.
    }
  }

  final fileMatch = RegExp("file\\s*:\\s*['\"]([^'\"]+)['\"]").firstMatch(html);
  if (fileMatch != null) {
    return fileMatch.group(1)!;
  }

  final sourceMatch = RegExp(
    r'<source[^>]+src="([^"]+)"',
    dotAll: true,
  ).firstMatch(html);
  if (sourceMatch != null) {
    return sourceMatch.group(1)!.replaceAll('&amp;', '&');
  }

  return null;
}

/// Mengambil nonce dari `admin-ajax.php`.
Future<String> _fetchNonce(String episodeUrl) async {
  final response = await httpPostWithRetry(
    Uri.parse(_ajaxUrl),
    headers: _ajaxHeaders(episodeUrl),
    body: {'action': _nonceAction},
    timeout: const Duration(seconds: 15),
    maxAttempts: 2,
  );

  final nonce = _readAjaxData(response.body);
  if (nonce == null || nonce.isEmpty) {
    throw Exception('Gagal mendapatkan token nonce dari server');
  }
  return nonce;
}

/// Membaca field `data` dari response `admin-ajax.php`.
String? _readAjaxData(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, dynamic>) {
    return null;
  }
  return decoded['data']?.toString();
}
