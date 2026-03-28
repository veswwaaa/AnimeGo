import 'dart:async';
import 'dart:convert';
import 'package:animego/example-demo-apk/features/anime-detail-screen/data/google-blog-direct.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:animego/example-demo-apk/core/config/api_config.dart';
import 'dart:developer' as developer;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:animego/example-demo-apk/core/utils/log_dev_storage_stub.dart';
import 'package:animego/example-demo-apk/core/utils/utils.dart';

Future<String?> animeEpisode(String rawUrl, int eps, int server) async {
  switch (server) {
    case 1:
      return await _fetchEpisodeServer1(rawUrl: rawUrl, eps: eps);
    case 2:
      return await _fetchEpisodeServer2(rawUrl: rawUrl, eps: eps);
    default:
      logDev('server tidak dikenal: $server', prefix: 'animeEpisode:');
      return null;
  }
}

Future<String?> _fetchEpisodeServer1({
  required String rawUrl,
  required int eps,
}) async {
  try {
    final trimmedUrl = rawUrl.trim();
    if (trimmedUrl.isEmpty) {
      return null;
    }

    logDev(
      'fetchEpisodeFrom server 1 with rawUrl: $rawUrl, eps: $eps',
      prefix: 'animeEpisode:',
    );

    final encodedUrl = base64Encode(utf8.encode(trimmedUrl));

    final String apiUrl =
        '$apiBaseUrl/api/nimegami/media?url=$encodedUrl&eps=$eps';

    logDev('Requesting episode: $apiUrl', prefix: 'animeEpisode:');

    final response = await httpGetWithRetry(
      Uri.parse(apiUrl),
      timeout: const Duration(seconds: 60),
      maxAttempts: 2,
    );

    logDev('Response status: ${response.body}', prefix: 'animeEpisode:');

    if (response.statusCode != 200) {
      logDev(
        'Error Log: Server error episode dengan status ${response.statusCode}',
        prefix: 'animeEpisode:',
      );
      return null;
    }

    final dynamic decodedDynamic = jsonDecode(response.body);

    if (decodedDynamic is String && decodedDynamic.trim().isNotEmpty) {
      return decodedDynamic.trim();
    }

    if (decodedDynamic is! Map<String, dynamic>) {
      logDev(
        'Error Log: Format response episode tidak valid.',
        prefix: 'animeEpisode:',
      );
      return null;
    }

    final directUrl =
        decodedDynamic['url']?.toString().trim() ??
        decodedDynamic['videoUrl']?.toString().trim() ??
        decodedDynamic['streamUrl']?.toString().trim() ??
        '';

    logDev('directUrl: $directUrl', prefix: 'animeEpisode:');

    if (directUrl.isNotEmpty) {
      return directUrl;
    }

    final data = decodedDynamic['data'];
    if (data is Map<String, dynamic>) {
      final nestedUrl =
          data['url']?.toString().trim() ??
          data['videoUrl']?.toString().trim() ??
          data['streamUrl']?.toString().trim() ??
          '';
      logDev('Nested URL: $nestedUrl', prefix: 'animeEpisode:');
      if (nestedUrl.isNotEmpty) {
        return nestedUrl;
      }
    }

    return null;
  } catch (error, stackTrace) {
    logDev(
      'Error Log: Terjadi kesalahan fatal saat ambil episode: $error\n$stackTrace',
      prefix: 'animeEpisode:',
    );
    return null;
  }
}

Future<String?> _fetchEpisodeServer2({
  required String rawUrl,
  required int eps,
}) async {
  VideoScraperService videoScraperService = new VideoScraperService();
  try {
    final trimmedUrl = rawUrl.trim();
    if (trimmedUrl.isEmpty) {
      return null;
    }

    logDev(
      'fetchEpisodeFrom server 2 with rawUrl: $rawUrl, eps: $eps',
      prefix: 'animeEpisode:',
    );

    final encodedUrl = Uri.encodeQueryComponent(trimmedUrl);

    final String apiUrl =
        '$apiBaseUrl/api/zoronime/media?url=$encodedUrl&eps=$eps';

    logDev('Requesting episode: $apiUrl', prefix: 'animeEpisode:');

    final response = await httpGetWithRetry(
      Uri.parse(apiUrl),
      timeout: const Duration(seconds: 60),
      maxAttempts: 2,
    );

    logDev('Response status: ${response.body}', prefix: 'animeEpisode:');

    if (response.statusCode != 200) {
      logDev(
        'Error Log: Server error episode dengan status ${response.statusCode}',
        prefix: 'animeEpisode:',
      );
      return null;
    }

    final dynamic decodedDynamic = jsonDecode(response.body);

    if (decodedDynamic is String && decodedDynamic.trim().isNotEmpty) {
      return decodedDynamic.trim();
    }

    if (decodedDynamic is! Map<String, dynamic>) {
      logDev(
        'Error Log: Format response episode tidak valid.',
        prefix: 'animeEpisode:',
      );
      return null;
    }
    
    if(checkIsDesudesustream(decodedDynamic['url']?.toString() ?? '')) {
      logDev('URL terdeteksi dari desustream, mencoba ekstrak blogger URL...', prefix: 'animeEpisode:');
      final result = await VideoScraperService.resolveVideoFromUrl(decodedDynamic['url']?.toString() ?? '');
      print(result!.videoUrl);
      return result!.videoUrl;
    }

    final directFileId = decodedDynamic['url']?.toString().trim() ?? '';
    final directUrl = directFileId.isNotEmpty
        ? (await getOdvidhideUrl(directFileId))?.trim() ?? ''
        : '';

    logDev('directUrl: $directUrl', prefix: 'animeEpisode:');

    if (directUrl.isNotEmpty) {
      return directUrl;
    }

    final data = decodedDynamic['data'];
    if (data is Map<String, dynamic>) {
      final nestedFileId = data['url']?.toString().trim() ?? '';
      final nestedUrl = nestedFileId.isNotEmpty
          ? (await getOdvidhideUrl(nestedFileId))?.trim() ?? ''
          : '';
      logDev('Nested URL: $nestedUrl', prefix: 'animeEpisode:');
      if (nestedUrl.isNotEmpty) {
        return nestedUrl;
      }
    }

    return null;
  } catch (error, stackTrace) {
    logDev(
      'Error Log: Terjadi kesalahan fatal saat ambil episode: $error\n$stackTrace',
      prefix: 'animeEpisode:',
    );
    return null;
  }
}

Future<String?> getOdvidhideUrl(String vidhideUrl) async {
  final embedUrl = Uri.parse(vidhideUrl.trim());

  try {
    // 1. Fetch HTML embed page
    final response = await http
        .get(
          embedUrl,
          headers: {
            "User-Agent":
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Referer": "https://odvidhide.com/",
            "Accept":
                "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
          },
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception("Gagal memuat halaman: HTTP ${response.statusCode}");
    }

    final html = response.body;

    // 2. Cari packed script
    final packerRegex = RegExp(
      r"eval\(function\(p,a,c,k,e,d\)[\s\S]+?\.split\('\|'\)\)\)",
    );
    final packerMatch = packerRegex.firstMatch(html);
    if (packerMatch == null) throw Exception("Packed script tidak ditemukan");

    final packedScript = packerMatch.group(0)!;

    // Decode JavaScript Packer (p,a,c,k,e,d) secara inline
    final decodeRegex = RegExp(
      r"}\s*\(\s*'([\s\S]*?)'\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*'([\s\S]*?)'\.split\(\s*'\|'\s*\)",
    );
    final decodeMatch = decodeRegex.firstMatch(packedScript);
    if (decodeMatch == null) throw Exception("Tidak bisa parse packed script");

    String p = decodeMatch.group(1)!;
    final int a = int.parse(decodeMatch.group(2)!);
    final int c = int.parse(decodeMatch.group(3)!);
    final List<String> k = decodeMatch.group(4)!.split('|');

    // Proses decoding
    for (int i = c - 1; i >= 0; i--) {
      // Sama seperti `if (k[i])` di JS
      if (i < k.length && k[i].isNotEmpty) {
        // toRadixString di Dart berfungsi persis seperti toString(radix) di JS (mendukung base 2-36)
        final radixStr = i.toRadixString(a);
        p = p.replaceAll(RegExp(r'\b' + radixStr + r'\b'), k[i]);
      }
    }

    final decoded = p;

    // 3. Cari object links/o yang berisi video sources
    final objectRegex = RegExp(r"var\s+(?:links|o)\s*=\s*(\{[\s\S]*?\})\s*;");
    final objectMatch = objectRegex.firstMatch(decoded);
    if (objectMatch == null) throw Exception("Video sources tidak ditemukan");

    final objectStr = objectMatch.group(1)!;

    // 4. Ambil URL hls2
    final hls2Regex = RegExp(r'''["']hls2["']\s*:\s*["']([^"']+)["']''');
    final hls2Match = hls2Regex.firstMatch(objectStr);
    if (hls2Match == null) throw Exception("URL hls2 tidak ditemukan");

    final masterUrl = hls2Match.group(1)!;

    // 5. Convert master.m3u8 → index-v1-a1.m3u8
    final queryStart = masterUrl.indexOf("?");
    String basePath = masterUrl;
    String queryString = "";

    if (queryStart != -1) {
      basePath = masterUrl.substring(0, queryStart);
      queryString = masterUrl.substring(queryStart);
    }

    // Replace master.m3u8 di akhir path lalu gabungkan dengan query string
    final indexUrl =
        basePath.replaceAll(RegExp(r'master\.m3u8$'), 'index-v1-a1.m3u8') +
        queryString;

    return indexUrl;
  } catch (e) {
    // Print error untuk mempermudah debugging
    logDev('Error saat mengekstrak URL: $e', prefix: 'getOdvidhideUrl:');
    return null;
  }
}

bool checkIsDesudesustream(streamUrl) {
  // 1. Parse the URL
  Uri uri = Uri.parse(streamUrl);

  // 2. Check if the host matches
  bool isDesuStream = uri.host == 'desustream.info';

  if (isDesuStream) {
    // final result = await VideoScraperService.resolveVideoFromUrl(streamUrl);
    return true;
  } else {
    // print("Domain does not match.");
    return false;
  }
}

