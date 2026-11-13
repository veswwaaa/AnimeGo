import 'package:flutter/material.dart';

import 'package:animego/core/dto/episode_dto.dart';
import 'package:animego/core/providers/provider_container.dart';
import 'package:animego/core/utils/utils.dart';
import 'package:animego/features/anime-detail-screen/data/sendReportToSupabase.dart';
import 'package:animego/features/anime-video-player-screen/presentation/anime-video-player-screen.dart';

// ==========================================
// 5. DETAIL SCREEN
// ==========================================
class AnimeDetailScreen extends StatefulWidget {
  final Anime anime;

  const AnimeDetailScreen({super.key, required this.anime});

  @override
  State<AnimeDetailScreen> createState() => _AnimeDetailScreenState();
}

class _AnimeDetailScreenState extends State<AnimeDetailScreen> {
  late final Anime _anime;

  List<EpisodeDto> _episodes = const <EpisodeDto>[];
  bool _isLoadingEpisodes = false;

  @override
  void initState() {
    super.initState();
    _anime = widget.anime;
    _loadEpisodes();
  }

  /// ID anime komposit: `providerId:localId`.
  String get _animeCompositeId {
    final providerId = _anime.providerId;
    final localId = _anime.sourceUrl.isEmpty ? _anime.title : _anime.sourceUrl;
    return providerId.isEmpty ? localId : providerId + ':' + localId;
  }

  Future<void> _loadEpisodes() async {
    setState(() {
      _isLoadingEpisodes = true;
    });

    try {
      final envelope = await ProviderContainer.instance.repository.episodes(
        _animeCompositeId,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _episodes = envelope.data ?? const <EpisodeDto>[];
        if (_episodes.isNotEmpty) {
          _anime.episodes = _episodes.length;
        }
      });
    } catch (error, stackTrace) {
      logError(
        'Gagal memuat daftar episode: ' + _anime.title,
        error,
        stackTrace,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingEpisodes = false;
        });
      }
    }
  }

  Future<void> _openEpisode(EpisodeDto episode) async {
    final episodeLabel =
        episode.title ?? ('Episode ' + episode.number.toString());
    showErrorSnackBar(context, 'Memuat episode ' + episodeLabel + '...');

    final envelope = await ProviderContainer.instance.repository.stream(
      episode.id.composite,
    );
    if (!mounted) {
      return;
    }

    final stream = envelope.data;
    if (stream == null || stream.url.isEmpty) {
      showErrorSnackBar(
        context,
        envelope.error?.message ?? 'Gagal memuat episode. Silakan coba lagi.',
      );
      return;
    }

    logDev('Episode URL: ' + stream.url, prefix: 'AnimeDetail:');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnimeVideoPlayerScreen(
          title: _anime.title,
          animeImageUrl: _anime.imageUrl,
          episodeName: episodeLabel,
          videoUrl: stream.url,
        ),
      ),
    );
  }

  Future<void> _report() async {
    final TextEditingController reasonController = TextEditingController();
    final TextEditingController animeNameController = TextEditingController();
    animeNameController.text = _anime.title;
    final TextEditingController emailController = TextEditingController();
    final animeUrl = _anime.sourceUrl;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Report Anime'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  readOnly: true,
                  controller: animeNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Anime',
                    border: OutlineInputBorder(),
                  ),
                ),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    hintText: 'Tuliskan email Anda...',
                  ),
                ),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Alasan laporan',
                    border: OutlineInputBorder(),
                    hintText: 'Tuliskan alasan detail di sini...',
                  ),
                  maxLines: 4,
                ),
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
                final alasan = reasonController.text.trim();
                if (alasan.isEmpty) {
                  return;
                }

                sendReportToSupabase(
                  animeName: animeNameController.text,
                  email: emailController.text,
                  reason: alasan,
                  animeUrl: animeUrl,
                );

                Navigator.of(dialogContext).pop();
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
                onPressed: _report,
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
                                  ? 'Status - Unknown'
                                  : 'Status - ' + _anime.status,
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
                                  _anime.rating.toString(),
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
                  Text(
                    'Episodes (' + _episodes.length.toString() + ')',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildEpisodeList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodeList() {
    if (_isLoadingEpisodes) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }

    if (_episodes.isEmpty) {
      return const Text(
        'Episode belum tersedia',
        style: TextStyle(color: Colors.grey),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _episodes.length,
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        final episode = _episodes[index];
        return GestureDetector(
          onTap: () => _openEpisode(episode),
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
                episode.title ?? ('Episode ' + episode.number.toString()),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                _anime.providerId,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ),
        );
      },
    );
  }
}
