import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'dart:async';
import 'package:http/http.dart' as http;

class HlsPlayerPage extends StatefulWidget {
  const HlsPlayerPage({super.key});

  @override
  State<HlsPlayerPage> createState() => _HlsPlayerPageState();
}

class _HlsPlayerPageState extends State<HlsPlayerPage> {
  late final Player _player;
  late final VideoController _videoController;

  @override
  void initState() {
    getOdvidhideUrl("unx9ahyh9hzr").then((url) {
      if (url != null) {
        // _player.open(
        //   Media(url),
        //   play: true,
        // );
        print("URL video berhasil didapatkan: $url");
      } else {
        print("Gagal mendapatkan URL video");
      }
    });
    super.initState();
    _player = Player();
    _videoController = VideoController(_player);
    _player.open(
      Media(
        'https://h85MclLE5sxF9yF.acek-cdn.com/hls2/01/07518/177mdmb614el_h/index-v1-a1.m3u8?t=QZsJD1lfmVRmgEYfRoVpoavBNEfdfHLEuGTQfR-WShI&s=1772789966&e=129600&f=37594079&srv=V2JQgNtMJhwHbZKu&i=0.4&sp=500&p1=V2JQgNtMJhwHbZKu&p2=V2JQgNtMJhwHbZKu&asn=23693',
      ),
      play: true,
    );
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Video Player')),
      body: Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Video(
            controller: _videoController,
            controls: (state) => AdaptiveVideoControls(state),
          ),
        ),
      ),
    );
  }
}

/// Fungsi untuk mengambil URL hls2 dari Odvidhide
Future<String?> getOdvidhideUrl(String fileId) async {
  final embedUrl = Uri.parse('https://odvidhide.com/embed/$fileId');

  try {
    // 1. Fetch HTML embed page
    final response = await http.get(
      embedUrl,
      headers: {
        "User-Agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Referer": "https://odvidhide.com/",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception("Gagal memuat halaman: HTTP ${response.statusCode}");
    }

    final html = response.body;

    // 2. Cari packed script
    final packerRegex = RegExp(r"eval\(function\(p,a,c,k,e,d\)[\s\S]+?\.split\('\|'\)\)\)");
    final packerMatch = packerRegex.firstMatch(html);
    if (packerMatch == null) throw Exception("Packed script tidak ditemukan");

    final packedScript = packerMatch.group(0)!;

    // Decode JavaScript Packer (p,a,c,k,e,d) secara inline
    final decodeRegex = RegExp(r"}\s*\(\s*'([\s\S]*?)'\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*'([\s\S]*?)'\.split\(\s*'\|'\s*\)");
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
    final indexUrl = basePath.replaceAll(RegExp(r'master\.m3u8$'), 'index-v1-a1.m3u8') + queryString;

    return indexUrl;

  } catch (e) {
    // Print error untuk mempermudah debugging
    print("Error saat mengekstrak URL: $e");
    return null;
  }
}