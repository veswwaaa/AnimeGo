import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:html/parser.dart' as html_parser;
import 'dart:convert';

// ============================================================
// MODEL: Hasil video yang ditemukan
// ============================================================
class VideoResult {
  final String title;
  final String videoUrl;
  final String thumbnail;
  final String quality;

  VideoResult({
    required this.title,
    required this.videoUrl,
    required this.thumbnail,
    required this.quality,
  });
}

// ============================================================
// SERVICE: Semua logika scraping ada di sini
// ============================================================
class VideoScraperService {
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36';

  // ============================================================
  // ✅ SINGLETON: CookieJar & Dio dibuat SEKALI, dipakai berulang
  // Ini kunci agar cookie session tersimpan antar request!
  // ============================================================
  static final CookieJar _cookieJar = CookieJar();
  static final Dio _dio = _initDio();

  static Dio _initDio() {
    final dio = Dio();
    dio.interceptors.add(CookieManager(_cookieJar));

    dio.options
      ..followRedirects = true
      ..maxRedirects = 5
      ..connectTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(seconds: 15)
      // ✅ FIX: Jangan auto-decode response sebagai JSON
      // Biarkan sebagai String mentah agar kita bisa strip prefix dulu
      ..responseType = ResponseType.plain;

    return dio;
  }

  // ============================================================
  // HELPER: Bersihkan URL dari escape unicode Google
  // ============================================================
  static String cleanGoogleUrl(String rawUrl) {
    return rawUrl
        .replaceAll(r'\u003d', '=')
        .replaceAll(r'\u0026', '&');
  }

  // ============================================================
  // HELPER: Strip anti-XSSI prefix dari Google
  // Google selalu menambahkan ")]}'\\n" di awal response
  // agar tidak bisa langsung di-eval sebagai JavaScript
  // ============================================================
  static String stripGooglePrefix(String raw) {
    // Contoh response mentah: ")]}'\\n[[...actual data...]]"
    const prefix = ")]}'\n";
    if (raw.startsWith(prefix)) {
      return raw.substring(prefix.length);
    }
    // Fallback: buang semua karakter sampai ketemu '[' atau '{'
    final startBracket = raw.indexOf('[');
    final startCurly = raw.indexOf('{');

    if (startBracket == -1 && startCurly == -1) return raw;
    if (startBracket == -1) return raw.substring(startCurly);
    if (startCurly == -1) return raw.substring(startBracket);

    return raw.substring(startBracket < startCurly ? startBracket : startCurly);
  }

  // Header untuk request playback langsung ke googlevideo/blogger.
  // Tanpa header ini, sebagian URL akan mengembalikan unauthorized.
  static Future<Map<String, String>> buildPlaybackHeaders(String videoUrl) async {
    final headers = <String, String>{
      'User-Agent': userAgent,
      'Referer': 'https://www.blogger.com/',
      'Origin': 'https://www.blogger.com',
      'Accept': '*/*',
      'Connection': 'keep-alive',
    };

    final uri = Uri.tryParse(videoUrl);
    if (uri == null) return headers;

    final cookieByName = <String, String>{};
    final cookieTargets = <Uri>[
      Uri.parse('https://www.blogger.com'),
      uri,
    ];

    for (final target in cookieTargets) {
      final cookies = await _cookieJar.loadForRequest(target);
      for (final cookie in cookies) {
        cookieByName[cookie.name] = cookie.value;
      }
    }

    if (cookieByName.isNotEmpty) {
      headers['Cookie'] = cookieByName.entries
          .map((entry) => '${entry.key}=${entry.value}')
          .join('; ');
    }

    return headers;
  }

  // ============================================================
  // STEP 1: Jika URL dari desustream, ambil dulu URL blogger-nya
  // ============================================================
  static Future<String?> getBloggerUrlFromDesustream(String desuUrl) async {
    try {
      print('[Desustream] Fetching: $desuUrl');

      final response = await _dio.get(
        desuUrl,
        options: Options(headers: {
          'User-Agent': userAgent,
          'Referer': 'https://desustream.info/',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'id-ID,id;q=0.9,en-US;q=0.8',
        }),
      );

      final document = html_parser.parse(response.data.toString());
      final iframe = document.getElementById('myIframe');
      final iframeSrc = iframe?.attributes['src'];

      if (iframeSrc == null ||
          iframeSrc.trim().isEmpty ||
          iframeSrc.endsWith('token=')) {
        throw Exception('Iframe src kosong atau token tidak valid');
      }

      final cleanUrl = iframeSrc.replaceAll('&amp;', '&');
      print('[Desustream] Blogger URL: ${cleanUrl.substring(0, 60)}...');
      return cleanUrl;

    } catch (e) {
      print('[Desustream] ERROR: $e');
      return null;
    }
  }

  // ============================================================
  // STEP 2: Ambil video URL langsung dari Blogger
  // ============================================================
  static Future<VideoResult?> getBloggerVideoDirect(String targetUrl) async {
    // ✅ Gunakan singleton _dio sehingga cookie jar tersimpan!
    try {
      final uri = Uri.parse(targetUrl);
      final token = uri.queryParameters['token'];
      final origin = uri.queryParameters['origin'] ?? 'www.blogger.com';

      if (token == null || token.isEmpty) {
        throw Exception('Token tidak ditemukan dalam URL!');
      }

      print('[Scraper] Token: ${token.substring(0, 20)}...');

      // Step A: Kunjungi halaman untuk dapat cookie session
      // ✅ Pakai header lengkap seperti JS untuk terlihat comme browser asli
      await _dio.get(
        targetUrl,
        options: Options(headers: {
          'User-Agent': userAgent,
          'Referer': 'https://$origin/',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'id-ID,id;q=0.9,en-US;q=0.8',
          'Accept-Encoding': 'gzip, deflate, br',
          'Connection': 'keep-alive',
          'Upgrade-Insecure-Requests': '1',
        }),
      );
      print('[Scraper] Step A OK - Cookie session tersimpan');

      // Step B: Hit Blogger BatchExecute API
      const rpcUrl =
          'https://www.blogger.com/_/BloggerVideoPlayerUi/data/batchexecute'
          '?rpcids=WcwnYd&f.sid=-123456789'
          '&bl=boq_bloggeruiserver_20240320.00_p0&hl=id&rt=c';

      final payload =
          'f.req=[[["WcwnYd","[\\"$token\\",null,0]",null,"generic"]]]';

      print('[Scraper] Step B - Hitting BatchExecute API...');
      
      final response = await _dio.post(
        rpcUrl,
        data: payload,
        options: Options(headers: {
          'User-Agent': userAgent,
          'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8',
          'X-Same-Domain': '1',
          'Origin': 'https://www.blogger.com',
          'Referer': 'https://www.blogger.com/video.g',
          'Accept': '*/*',
          'Accept-Language': 'id-ID,id;q=0.9,en-US;q=0.8',
          'Accept-Encoding': 'gzip, deflate, br',
          'Connection': 'keep-alive',
          'Sec-Fetch-Dest': 'empty',
          'Sec-Fetch-Mode': 'cors',
          'Sec-Fetch-Site': 'same-origin',
        }),
      );

      // Step C: Strip prefix anti-XSSI Google dulu sebelum parse
      // ✅ INI FIX UTAMA — tanpa ini jsonDecode langsung error
      final rawData = response.data.toString();
      print(
        '[Scraper] Raw response (50 char): ${rawData.substring(0, rawData.length > 50 ? 50 : rawData.length)}',
      );

      final cleanData = stripGooglePrefix(rawData);

      // Step D: Cari blok data WcwnYd di dalam response
      final regExp = RegExp(
        r'\["wrb\.fr","WcwnYd","(.+?)",null,null,null,"generic"\]',
      );
      final match = regExp.firstMatch(cleanData);

      if (match == null) {
        throw Exception('Gagal parsing data. Token mungkin kedaluwarsa.');
      }

      // Unescape inner JSON string
      final innerString = match.group(1)!.replaceAll('\\"', '"');
      final data = jsonDecode(innerString);

      // Step E: Validasi struktur data
      if (data == null || data[2] == null || data[2][0] == null) {
        throw Exception('Struktur data tidak sesuai ekspektasi');
      }

      final itag = data[2][0][1][0];
      final quality = (itag == 18) ? '360p' : '720p';

      final result = VideoResult(
        title: data[4] ?? 'Tidak ada judul',
        thumbnail: cleanGoogleUrl((data[3] ?? '').toString()),
        videoUrl: cleanGoogleUrl((data[2][0][0] ?? '').toString()),
        quality: quality,
      );

      print('[Scraper] Berhasil: ${result.title} (${result.quality})');
      print('[Scraper] Video URL: ${result.videoUrl.substring(0, 60)}...');
      
      return result;

    } on DioException catch (e) {
      print('[Scraper] DioError: ${e.type} | ${e.message}');
      print('[Scraper] Status: ${e.response?.statusCode}');
      print('[Scraper] Response: ${e.response?.data}');
      return null;
    } catch (e) {
      print('[Scraper] ERROR: $e');
      return null;
    }
  }

  // ============================================================
  // MAIN: Auto-detect URL (desustream atau blogger langsung)
  // ============================================================
  static Future<VideoResult?> resolveVideoFromUrl(String inputUrl) async {
    String bloggerUrl = inputUrl;

    if (inputUrl.contains('desustream.info')) {
      final extracted = await getBloggerUrlFromDesustream(inputUrl);
      if (extracted == null) return null;
      bloggerUrl = extracted;
    }

    return getBloggerVideoDirect(bloggerUrl);
  }
}