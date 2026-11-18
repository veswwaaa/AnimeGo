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

/// Status pemuatan halaman detail.
enum _DetailStatus { loading, loaded, error }

class _AnimeDetailScreenState extends State<AnimeDetailScreen> {
  late final Anime _anime;

  List<EpisodeDto> _episodes = const <EpisodeDto>[];
  _DetailStatus _status = _DetailStatus.loading;
  String _errorMessage = '';
  bool _isLoadingEpisodes = false;

  @override
  void initState() {
    super.initState();
    _anime = widget.anime;
    _loadDetail();
  }

  /// ID anime komposit: `providerId:localId`.
  ///
  /// Mengutamakan [Anime.id] yang sudah diisi dari DTO canonical
  /// (`provider:localId`). Fallback ke `sourceUrl` hanya untuk model
  /// yang tidak berasal dari provider canonical (mis. data contoh).
  String get _animeCompositeId {
    final existing = _anime.id.trim();
    if (existing.isNotEmpty) {
      return existing;
    }

    final providerId = _anime.providerId;
    final localId = _anime.sourceUrl.isEmpty ? _anime.title : _anime.sourceUrl;
    return providerId.isEmpty ? localId : providerId + ':' + localId;
  }

  /// Muat detail + episode.
  ///
  /// Detail dan episode dipanggil bersamaan; provider Nimegami v2 sudah
  /// mengembalikan episode list di payload `/detail`, sehingga panggilan
  /// `/episodes` dilayani dari cache provider (tanpa round-trip tambahan).
  Future<void> _loadDetail() async {
    setState(() {
      _status = _DetailStatus.loading;
      _errorMessage = '';
      _isLoadingEpisodes = true;
    });

    final repository = ProviderContainer.instance.repository;

    try {
      // Detail diambil lebih dulu: provider Nimegami v2 mengembalikan
      // episode list di payload /detail, sehingga panggilan /episodes
      // berikutnya dilayani dari cache provider (tanpa round-trip tambahan).
      final detailEnvelope = await repository.detail(_animeCompositeId);
      final episodesEnvelope = await repository.episodes(_animeCompositeId);

      if (!mounted) {
        return;
      }

      final detail = detailEnvelope.data;
      final episodes = episodesEnvelope.data ?? const <EpisodeDto>[];

      if (detail == null) {
        setState(() {
          _status = _DetailStatus.error;
          _errorMessage =
              detailEnvelope.error?.message ??
              'Gagal memuat detail anime. Silakan coba lagi.';
          _isLoadingEpisodes = false;
        });
        return;
      }

      setState(() {
        _applyDetail(detail);
        _episodes = episodes;
        if (episodes.isNotEmpty) {
          _anime.episodes = episodes.length;
        }
        _status = _DetailStatus.loaded;
        _isLoadingEpisodes = false;
      });
    } catch (error, stackTrace) {
      logError(
        'Gagal memuat detail anime: ' + _anime.title,
        error,
        stackTrace,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _status = _DetailStatus.error;
        _errorMessage = _messageFor(error);
        _isLoadingEpisodes = false;
      });
    }
  }

  /// Salin metadata detail ke model UI.
  void _applyDetail(AnimeDto detail) {
    _anime.title = detail.title;
    _anime.imageUrl = detail.image ?? _anime.imageUrl;
    _anime.rating = detail.rating;
    _anime.genres = detail.genres.isEmpty ? _anime.genres : detail.genres;
    final description = detail.description;
    if (description != null && description.trim().isNotEmpty) {
      _anime.synopsis = description;
    }
    if (detail.status.isNotEmpty && detail.status != 'Unknown') {
      _anime.status = detail.status;
    }
    final total = detail.totalEpisodes;
    if (total != null && total > 0) {
      _anime.episodes = total;
    }
  }

  /// Pesan error yang jelas untuk user (bukan halaman kosong).
  String _messageFor(Object error) {
    final text = error.toString();
    if (text.contains('Tidak bisa menghubungi')) {
      return 'Tidak bisa menghubungi server. Periksa koneksi internet Anda.';
    }
    if (text.contains('terlalu lama merespons')) {
      return 'Server terlalu lama merespons. Silakan coba lagi.';
    }
    return 'Gagal memuat detail anime. Silakan coba lagi.';
  }

  /// Baris metadata ringkas untuk player, mis.
  /// `Season 1 • Sub | Dub • 24m • 2024`.
  String get _playerMetaLine {
    final parts = <String>[];
    if (_anime.status.isNotEmpty && _anime.status != 'Unknown') {
      parts.add(_anime.status);
    }
    if (_anime.rating > 0) {
      parts.add('★ ' + _anime.rating.toStringAsFixed(1));
    }
    final total = _anime.episodes;
    if (total > 0) {
      parts.add(total.toString() + ' Episode');
    }
    return parts.join(' • ');
  }

  /// Daftar episode siap pakai untuk section `EPISODES` di player.
  List<PlayerEpisodeInfo> get _playerEpisodes {
    return _episodes
        .map(
          (episode) => PlayerEpisodeInfo(
            number: episode.number,
            title:
                episode.title ?? ('Episode ' + episode.number.toString()),
            subtitle:
                episode.airingDate ?? _anime.providerId,
          ),
        )
        .toList(growable: false);
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

    // Nama server aktif + daftar server dari mirror stream.
    final serverLabels = <String>[];
    for (final mirror in stream.mirrors) {
      final label = (mirror.label ?? '').trim();
      if (label.isNotEmpty && !serverLabels.contains(label)) {
        serverLabels.add(label);
      }
    }
    final activeServer = serverLabels.isNotEmpty
        ? serverLabels.first
        : (stream.mirrors.isEmpty ? null : stream.mirrors.first.label);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnimeVideoPlayerScreen(
          title: _anime.title,
          animeImageUrl: _anime.imageUrl,
          episodeName: episodeLabel,
          videoUrl: stream.url,
          synopsis: _anime.synopsis,
          metaLine: _playerMetaLine,
          serverName: activeServer,
          servers: serverLabels,
          episodes: _playerEpisodes,
          currentEpisodeNumber: episode.number,
          onServerSelected: (serverName) => _resolveServerStream(
            episode,
            serverName,
          ),
          onEpisodeSelected: (info) => _switchEpisode(episode, info),
        ),
      ),
    );
  }

  /// Ambil ulang stream episode (dipakai saat user ganti server).
  Future<String?> _resolveServerStream(
    EpisodeDto episode,
    String serverName,
  ) async {
    try {
      final envelope = await ProviderContainer.instance.repository.stream(
        episode.id.composite,
      );
      final url = envelope.data?.url;
      if (url == null || url.isEmpty) {
        if (!mounted) return null;
        showErrorSnackBar(
          context,
          'Server ' + serverName + ' tidak tersedia untuk episode ini.',
        );
        return null;
      }
      return url;
    } catch (error) {
      logError(
        'Gagal mengganti server: $serverName',
        error,
        StackTrace.current,
      );
      if (!mounted) return null;
      showErrorSnackBar(context, 'Gagal memuat server ' + serverName + '.');
      return null;
    }
  }

  /// Pindah ke episode lain langsung dari daftar di player.
  Future<void> _switchEpisode(
    EpisodeDto currentEpisode,
    PlayerEpisodeInfo info,
  ) async {
    if (info.number == currentEpisode.number) {
      return;
    }

    final target = _episodes.where((item) => item.number == info.number);
    if (target.isEmpty) {
      return;
    }

    final episode = target.first;
    showErrorSnackBar(context, 'Memuat episode ' + info.title + '...');

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

    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AnimeVideoPlayerScreen(
          title: _anime.title,
          animeImageUrl: _anime.imageUrl,
          episodeName: info.title,
          videoUrl: stream.url,
          synopsis: _anime.synopsis,
          metaLine: _playerMetaLine,
          serverName: stream.mirrors.isEmpty ? null : stream.mirrors.first.label,
          servers: stream.mirrors
              .map((mirror) => mirror.label ?? '')
              .where((label) => label.isNotEmpty)
              .toList(growable: false),
          episodes: _playerEpisodes,
          currentEpisodeNumber: episode.number,
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
                  if (_status == _DetailStatus.error) _buildErrorBanner(),
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

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1416),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF5A5A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFFF5A5A)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _errorMessage.isEmpty
                      ? 'Gagal memuat detail anime.'
                      : _errorMessage,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _loadDetail,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A00),
                foregroundColor: Colors.white,
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
      return Text(
        _status == _DetailStatus.loaded
            ? 'Episode belum tersedia untuk anime ini'
            : 'Episode belum tersedia',
        style: const TextStyle(color: Colors.grey),
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
