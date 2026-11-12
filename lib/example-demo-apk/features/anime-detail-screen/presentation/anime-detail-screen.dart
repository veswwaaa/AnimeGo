import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animego/example-demo-apk/core/utils/utils.dart';
import 'package:animego/example-demo-apk/features/anime-detail-screen/data/function.dart';
import 'package:animego/example-demo-apk/features/anime-video-player-screen/presentation/anime-video-player-screen.dart';
import 'package:animego/example-demo-apk/features/anime-detail-screen/data/sendReportToSupabase.dart';
import 'package:animego/example-demo-apk/features/search-screen/data/otakudesu-episodes.dart';
import 'package:animego/example-demo-apk/features/search-screen/data/otakudesu-video.dart';
import 'dart:developer' as developer;

// ==========================================
// 5. DETAIL SCREEN
// ==========================================
class AnimeDetailScreen extends StatefulWidget {
  Anime anime;

  AnimeDetailScreen({super.key, required this.anime});

  @override
  State<AnimeDetailScreen> createState() => _AnimeDetailScreenState();
}

class _AnimeDetailScreenState extends State<AnimeDetailScreen> {
  late Anime _anime;
  late final Anime _initialAnime;
  int serverId = 1;
  bool _isRefreshingDetail = false;

  // Anime yang berasal dari Otakudesu memakai daftar episode sendiri.
  bool get _isOtakudesuAnime =>
      _anime.sourceUrl.contains('otakudesu.blog');

  List<OtakudesuEpisode> _otakudesuEpisodes = [];
  bool _isLoadingOtakudesuEpisodes = false;

  Anime _cloneAnime(Anime source) {
    return Anime(
      title: source.title,
      imageUrl: source.imageUrl,
      rating: source.rating,
      genres: List<String>.from(source.genres),
      synopsis: source.synopsis,
      status: source.status,
      sourceUrl: source.sourceUrl,
      detailUrl: source.detailUrl,
      episodes: source.episodes,
    );
  }

  @override
  void initState() {
    super.initState();
    _anime = _cloneAnime(widget.anime);
    _initialAnime = _cloneAnime(widget.anime);
    if (_isOtakudesuAnime) {
      _loadOtakudesuEpisodes();
    } else {
      _refreshAnimeDetail();
    }
  }

  Future<void> _loadOtakudesuEpisodes() async {
    setState(() {
      _isLoadingOtakudesuEpisodes = true;
    });

    try {
      final episodes = await getOtakudesuEpisodes(_anime.sourceUrl);
      if (!mounted) {
        return;
      }

      setState(() {
        _otakudesuEpisodes = episodes;
      });
    } catch (error, stackTrace) {
      logError(
        'Gagal memuat daftar episode Otakudesu: ${_anime.title}',
        error,
        stackTrace,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingOtakudesuEpisodes = false;
        });
      }
    }
  }

  Future<void> _openOtakudesuEpisode(OtakudesuEpisode episode) async {
    showErrorSnackBar(context, 'Memuat episode ${episode.title}...');

    final video = await getOtakudesuVideo(episode.url);
    if (!mounted) {
      return;
    }

    final episodeUrl = video.streamUrl;
    if (!video.success || episodeUrl == null || episodeUrl.isEmpty) {
      showErrorSnackBar(
        context,
        'Gagal memuat episode. Silakan coba lagi.',
      );
      return;
    }
    //tolong dong ketika episodeUrl berhasil diambil, print console terminal dong url nya biar bisa saya cross check

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnimeVideoPlayerScreen(
          title: _anime.title,
          animeImageUrl: _anime.imageUrl,
          episodeName: episode.title,
          videoUrl: episodeUrl,
        ),
      ),
    );
  }

  Future<void> _refreshAnimeDetail({
    String? sourceUrl,
    int? serverOverride,
  }) async {
    final activeServer = serverOverride ?? serverId;
    final targetSourceUrl = (sourceUrl ?? _anime.sourceUrl).trim();
    if (targetSourceUrl.isEmpty) {
      return;
    }

    setState(() {
      _isRefreshingDetail = true;
    });

    try {
      final latestAnime = await detailAnime(
        targetSourceUrl,
        serverId: activeServer,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _anime.sourceUrl = latestAnime.sourceUrl;
        _anime.episodes = latestAnime.episodes;
      });
    } catch (error, stackTrace) {
      logError(
        'Gagal refresh detail anime: ${_anime.title}',
        error,
        stackTrace,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingDetail = false;
        });
      }
    }
  }

  Future<void> _changeServer(int targetServerId) async {
    print('Pindah ke server $targetServerId');
    if (targetServerId == serverId) {
      return;
    }

    setState(() {
      serverId = targetServerId;
    });

    if (targetServerId == 1) {
      print('Kembali ke server 1 dengan URL: ${_initialAnime.sourceUrl}');
      await _refreshAnimeDetail(
        sourceUrl: _initialAnime.sourceUrl,
        serverOverride: 1,
      );
      return;
    }

    try {
      final candidates = await searchAnime(_anime.title, serverId: 2);
      if (!mounted) {
        return;
      }

      if (candidates.isEmpty) {
        showErrorSnackBar(context, 'Anime tidak ditemukan di Server 2.');
        return;
      }

      final selectedAnime = candidates.first;
      print(selectedAnime.title);
      print(selectedAnime.detailUrl);
      setState(() {
        _anime.sourceUrl = selectedAnime.sourceUrl;
        _anime.episodes = selectedAnime.episodes;
      });

      await _refreshAnimeDetail(
        sourceUrl: selectedAnime.detailUrl,
        serverOverride: 2,
      );
    } catch (error, stackTrace) {
      logError(
        'Gagal pindah ke server 2 untuk anime: ${_anime.title}',
        error,
        stackTrace,
      );
      if (!mounted) {
        return;
      }
      showErrorSnackBar(context, 'Gagal memuat data dari Server 2.');
    }
  }

  Future<void> _report() async {
  // Gunakan TextEditingController untuk mengambil teks input nantinya
  final TextEditingController reasonController = TextEditingController();
  final TextEditingController animeNameController = TextEditingController();
  animeNameController.text = _anime.title; // Set nama anime ke TextField
  final TextEditingController emailController = TextEditingController();
  final animeUrl = _anime.sourceUrl;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Report Anime'),
        content: SingleChildScrollView( // Agar tidak overflow saat keyboard muncul
          child: Column(
            mainAxisSize: MainAxisSize.min, // Agar dialog pas dengan isi
            children: [
              TextField(
                readOnly: true,
                controller: animeNameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Anime',
                  border: OutlineInputBorder(),
                ),
                // maxLines: 4, // Disesuaikan agar nyaman mengetik
              ),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  hintText: 'Tuliskan email Anda...',
                ),
                // maxLines: 4, // Disesuaikan agar nyaman mengetik
              ),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Alasan laporan',
                  border: OutlineInputBorder(),
                  hintText: 'Tuliskan alasan detail di sini...',
                ),
                maxLines: 4, // Disesuaikan agar nyaman mengetik
              ),
              // Jika butuh input tambahan, tambahkan TextField lain di sini
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              logDev('Laporan dikirim dengan alasan: ${reasonController.text} ${emailController.text} ${animeNameController.text} ${animeUrl}');
              sendReportToSupabase(
                animeName: animeNameController.text,
                email: emailController.text,
                reason: reasonController.text,
                animeUrl: animeUrl,
              );
              String alasan = reasonController.text;
              
              // Tambahkan logika validasi jika perlu
              if (alasan.isEmpty) {
                // Tampilkan pesan peringatan jika kosong
                return;
              }

              Navigator.of(dialogContext).pop();
              
              // Logika kirim ke API/Server diletakkan di sini
              
              showErrorSnackBar(
                context,
                'Anime telah dilaporkan. Terima kasih atas laporannya.',
              );
            },
            child: const Text('Laporkan'),
          ),
        ],
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    final episodeCount = _anime.episodes;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: const Color(0xFF0D0D12),
            actions: [
              IconButton(
                tooltip: 'Report',
                icon: const Icon(Icons.flag_outlined),
                onPressed: () {
                  _report();
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  buildSafeAnimeImage(_anime.imageUrl, fit: BoxFit.cover),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF0D0D12),
                          Colors.transparent,
                          Color(0xFF0D0D12),
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        stops: [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: buildSafeAnimeImage(
                          _anime.imageUrl,
                          width: 100,
                          height: 150,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _anime.title,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _anime.status.isEmpty
                                  ? 'Status - 2020'
                                  : 'Status - ${_anime.status}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Colors.orange,
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${_anime.rating}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              children: _anime.genres
                                  .map(
                                    (g) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1C1C24),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        g,
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Synopsis',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _anime.synopsis,
                    style: const TextStyle(color: Colors.grey, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  if (!_isOtakudesuAnime) ...[
                    const Text(
                      'Select Server',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _changeServer(1),
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: serverId == 1
                                  ? const Color(0xFFFF7A00)
                                  : const Color(0xFF1C1C24),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Server 1',
                                  style: TextStyle(
                                    color: serverId == 1
                                        ? Colors.white
                                        : Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '2 eps',
                                  style: TextStyle(
                                    color: serverId == 1
                                        ? Colors.white
                                        : Colors.orangeAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _changeServer(2),
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: serverId == 2
                                  ? const Color(0xFFFF7A00)
                                  : const Color(0xFF1C1C24),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Server 2',
                                  style: TextStyle(
                                    color: serverId == 2
                                        ? Colors.white
                                        : Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '12 eps',
                                  style: TextStyle(
                                    color: serverId == 2
                                        ? Colors.white
                                        : Colors.orangeAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    ),
                  ],
                  Text(
                    _isOtakudesuAnime
                        ? 'Episodes (${_otakudesuEpisodes.length})'
                        : 'Episodes ($episodeCount)',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_isOtakudesuAnime)
                    _buildOtakudesuEpisodeList()
                  else ...[
                  if (_isRefreshingDetail)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  if (episodeCount <= 0)
                    const Text(
                      'Episode belum tersedia',
                      style: TextStyle(color: Colors.grey),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: episodeCount,
                      padding: EdgeInsets.zero,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () async {
                            final sourceUrl = _anime.sourceUrl.trim();
                            if (sourceUrl.isEmpty) {
                              showErrorSnackBar(
                                context,
                                'Episode belum tersedia untuk anime ini.',
                              );
                              logInfo(
                                'Source URL kosong untuk anime: ${_anime.title}',
                              );
                              return;
                            }

                            final episodeUrl = await animeEpisode(
                              sourceUrl,
                              index + 1,
                              serverId,
                            );
                            if (!context.mounted) {
                              return;
                            }

                            if (episodeUrl == null || episodeUrl.isEmpty) {
                              showErrorSnackBar(
                                context,
                                'Gagal memuat episode. Silakan coba lagi.',
                              );
                              return;
                            }

                            print('[Server $serverId] Episode URL: $episodeUrl');

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AnimeVideoPlayerScreen(
                                  title: _anime.title,
                                  animeImageUrl: _anime.imageUrl,
                                  episodeName: 'Episode ${index + 1}',
                                  videoUrl: episodeUrl,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF14141A),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1C1C24),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_arrow,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                'Episode ${index + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: const Text(
                                '24 min',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtakudesuEpisodeList() {
    if (_isLoadingOtakudesuEpisodes) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }

    if (_otakudesuEpisodes.isEmpty) {
      return const Text(
        'Episode belum tersedia',
        style: TextStyle(color: Colors.grey),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _otakudesuEpisodes.length,
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        final episode = _otakudesuEpisodes[index];
        return GestureDetector(
          onTap: () => _openOtakudesuEpisode(episode),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF14141A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFF1C1C24),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.grey,
                  size: 20,
                ),
              ),
              title: Text(
                episode.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Otakudesu',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ),
        );
      },
    );
  }
}
