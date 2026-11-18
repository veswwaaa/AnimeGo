import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:animego/core/utils/utils.dart';
import 'package:animego/features/anime-detail-screen/data/google-blog-direct.dart';

// ==========================================
// 6. VIDEO PLAYER SCREEN (NEW)
//
// Implementasi sesuai board Penpot
// `Anime / Video Player Screen` (390x844):
// - Player 16:9 di atas (overlay custom: close, rewind/pause/forward,
//   timestamp, fullscreen, progress bar crimson).
// - Metadata episode (judul mono, baris metadata, sinopsis).
// - Action pills: Server Switch (gold), My List, Download.
// - Tabs: EPISODES / RELATED / COMMENTS dengan indikator aktif gold.
// - Daftar episode vertikal (badge nomor + judul + subtitle + menu).
//
// Catatan: cluster ikon subtitle/audio/speed/PiP/cast TIDAK digambar manual
// (sudah dihapus di desain); kontrol bawaan `media_kit` tetap dipakai
// lewat `AdaptiveVideoControls` untuk mode landscape/fullscreen.
// ==========================================

/// Token warna dari board Penpot `Anime / Video Player Screen`.
class _PlayerTokens {
  static const Color background = Color(0xFF0B0E11);
  static const Color surface = Color(0xFF12161B);
  static const Color surfaceStrong = Color(0xFF1B2026);
  static const Color pill = Color(0xFF181E24);
  static const Color accent = Color(0xFFE50914);
  static const Color gold = Color(0xFFFACC15);
  static const Color textMuted = Color(0xFF9AA4B2);
  static const Color textBody = Color(0xFFCBD5E1);
  static const Color white = Color(0xFFFFFFFF);
}

/// Info episode untuk baris daftar episode di bawah player.
class PlayerEpisodeInfo {
  const PlayerEpisodeInfo({
    required this.number,
    required this.title,
    this.subtitle,
    this.isWatched = false,
  });

  final int number;
  final String title;
  final String? subtitle;
  final bool isWatched;
}

class AnimeVideoPlayerScreen extends StatefulWidget {
  final String title;
  final String animeImageUrl;
  final String episodeName;
  final String videoUrl;
  final Duration startAt;

  /// Sinopsis anime (opsional, sesuai desain).
  final String? synopsis;

  /// Baris metadata ringkas, mis. `Season 1 • Sub | Dub • 24m • 2024`.
  final String? metaLine;

  /// Nama server aktif, mis. `BerkasDrive`.
  final String? serverName;

  /// Daftar server yang tersedia untuk dipilih.
  final List<String> servers;

  /// Daftar episode untuk section `EPISODES`.
  final List<PlayerEpisodeInfo> episodes;

  /// Nomor episode yang sedang diputar.
  final int? currentEpisodeNumber;

  /// Callback saat user memilih server lain.
  ///
  /// Mengembalikan URL stream baru (nullable = tidak berubah).
  final Future<String?> Function(String serverName)? onServerSelected;

  /// Callback saat user memilih episode lain dari daftar.
  final Future<void> Function(PlayerEpisodeInfo episode)? onEpisodeSelected;

  const AnimeVideoPlayerScreen({
    super.key,
    required this.title,
    required this.animeImageUrl,
    required this.episodeName,
    required this.videoUrl,
    this.startAt = Duration.zero,
    this.synopsis,
    this.metaLine,
    this.serverName,
    this.servers = const <String>[],
    this.episodes = const <PlayerEpisodeInfo>[],
    this.currentEpisodeNumber,
    this.onServerSelected,
    this.onEpisodeSelected,
  });

  @override
  State<AnimeVideoPlayerScreen> createState() => _AnimeVideoPlayerScreenState();
}

class _AnimeVideoPlayerScreenState extends State<AnimeVideoPlayerScreen> {
  late final Player _player;
  late final VideoController _videoController;

  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  bool _didSaveHistory = false;
  bool _didSeekInitialPosition = false;
  String? _errorMessage;

  // State playback.
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isBuffering = false;

  // State UI.
  bool _isFullscreen = false;
  String _activeServer = '';
  String? _selectedTab;

  @override
  void initState() {
    super.initState();
    _activeServer = (widget.serverName ?? '').trim();
    _player = Player();
    _videoController = VideoController(_player);
    _listenToPlayerState();
    _listenToPlayerErrors();
    _initializePlayer();
  }

  /// Menangkap perubahan state player (posisi, durasi, buffering).
  void _listenToPlayerState() {
    _subscriptions.add(
      _player.stream.duration.listen((duration) {
        if (!mounted) return;
        setState(() => _duration = duration);
        _seekToInitialPositionWhenReady(duration);
      }),
    );
    _subscriptions.add(
      _player.stream.position.listen((position) {
        if (!mounted) return;
        setState(() => _position = position);
      }),
    );
    _subscriptions.add(
      _player.stream.buffering.listen((buffering) {
        if (!mounted) return;
        setState(() => _isBuffering = buffering);
      }),
    );
    _subscriptions.add(
      _player.stream.playing.listen((playing) {
        if (!mounted) return;
        setState(() => _isPlaying = playing);
      }),
    );
  }

  /// Menangkap error dari mpv supaya penyebab gagalnya tampil di layar.
  void _listenToPlayerErrors() {
    _subscriptions.add(
      _player.stream.error.listen((error) {
        logDev('Player error: $error', prefix: 'AnimeVideoPlayer:');
        if (!mounted) {
          return;
        }
        setState(() {
          _errorMessage = 'Gagal memuat video: $error';
        });
      }),
    );
  }

  Future<void> _initializePlayer() async {
    final targetUrl = widget.videoUrl;
    final parsedUri = Uri.tryParse(targetUrl);
    final fallbackUri = Uri.parse(
      'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
    );

    final videoUri =
        (parsedUri != null &&
            (parsedUri.isScheme('http') || parsedUri.isScheme('https')))
        ? parsedUri
        : fallbackUri;

    if (videoUri == fallbackUri) {
      logInfo(
        'Video URL tidak valid, gunakan fallback video. Input: $targetUrl',
      );
    }

    if (!mounted) {
      return;
    }

    final playbackHeaders = await VideoScraperService.buildPlaybackHeaders(
      videoUri.toString(),
    );

    logDev(
      'Membuka video: $videoUri dengan header: $playbackHeaders',
      prefix: 'AnimeVideoPlayer:',
    );

    // Host|archive.org/umumnya butuh waktu lama sebelum moov ketemu,
    // dan mpv default network-timeout cuma 5 detik.
    await _setMpvProperty('network-timeout', '30');
    await _setMpvProperty('demuxer-readahead-secs', '30');
    // MP4 non-faststart (moov di akhir file) butuh buffering lebih besar.
    await _setMpvProperty('demuxer-max-bytes', '64MiB');

    _player.open(
      Media(videoUri.toString(), httpHeaders: playbackHeaders),
      play: true,
    );
  }

  /// Mengatur properti mpv. Hanya tersedia di backend native.
  Future<void> _setMpvProperty(String property, String value) async {
    final platform = _player.platform;
    if (platform is! NativePlayer) {
      return;
    }

    try {
      await platform.setProperty(property, value);
    } catch (error) {
      logDev(
        'Gagal set mpv property $property: $error',
        prefix: 'AnimeVideoPlayer:',
      );
    }
  }

  void _seekToInitialPositionWhenReady(Duration totalDuration) {
    if (_didSeekInitialPosition) {
      return;
    }

    if (totalDuration <= Duration.zero) {
      return;
    }

    _didSeekInitialPosition = true;
    final target = widget.startAt;
    if (target <= Duration.zero) {
      return;
    }

    final safeTarget = (target > totalDuration) ? totalDuration : target;
    _player.seek(safeTarget);
  }

  void _saveWatchHistory() {
    if (_didSaveHistory) {
      return;
    }

    _didSaveHistory = true;
    Duration currentPosition = widget.startAt;

    currentPosition = _player.state.position;
    final duration = _player.state.duration;
    if (duration > Duration.zero && currentPosition > duration) {
      currentPosition = duration;
    }

    upsertWatchHistory(
      WatchHistoryItem(
        animeTitle: widget.title,
        animeImageUrl: widget.animeImageUrl,
        episodeName: widget.episodeName,
        videoUrl: widget.videoUrl,
        positionSeconds: currentPosition.inSeconds,
        updatedAt: DateTime.now(),
      ),
    );
  }

  /* ------------------------------ Actions ------------------------------- */

  void _togglePlayPause() {
    if (_isPlaying) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  void _seekBy(Duration delta) {
    final target = _position + delta;
    final duration = _duration;
    if (duration > Duration.zero && target > duration) {
      _player.seek(duration);
      return;
    }
    if (target < Duration.zero) {
      _player.seek(Duration.zero);
      return;
    }
    _player.seek(target);
  }

  void _seekToFraction(double fraction) {
    final duration = _duration;
    if (duration <= Duration.zero) {
      return;
    }
    final millis = (duration.inMilliseconds * fraction).round();
    _player.seek(Duration(milliseconds: millis));
  }

  Future<void> _toggleFullscreen() async {
    final next = !_isFullscreen;
    setState(() => _isFullscreen = next);
    if (next) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  }

  Future<void> _openServerSheet() async {
    final servers = widget.servers;
    if (servers.isEmpty) {
      return;
    }

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _PlayerTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Text(
                  'Pilih Server',
                  style: TextStyle(
                    color: _PlayerTokens.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Roboto Mono',
                  ),
                ),
              ),
              for (final server in servers)
                ListTile(
                  leading: Icon(
                    server == _activeServer
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: server == _activeServer
                        ? _PlayerTokens.gold
                        : _PlayerTokens.textMuted,
                  ),
                  title: Text(
                    server,
                    style: const TextStyle(color: _PlayerTokens.white),
                  ),
                  onTap: () => Navigator.of(sheetContext).pop(server),
                ),
            ],
          ),
        );
      },
    );

    if (!mounted || selected == null || selected == _activeServer) {
      return;
    }

    final resolver = widget.onServerSelected;
    if (resolver == null) {
      setState(() => _activeServer = selected);
      return;
    }

    final newUrl = await resolver(selected);
    if (!mounted) {
      return;
    }
    setState(() => _activeServer = selected);
    if (newUrl != null && newUrl.isNotEmpty) {
      await _player.open(Media(newUrl), play: true);
    }
  }

  Future<void> _openEpisode(PlayerEpisodeInfo episode) async {
    final callback = widget.onEpisodeSelected;
    if (callback == null) {
      return;
    }
    await callback(episode);
  }

  /* ------------------------------- Build -------------------------------- */

  @override
  Widget build(BuildContext context) {
    if (_isFullscreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _buildVideoLayer(),
            _buildOverlay(isFullscreen: true),
          ],
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        _saveWatchHistory();
        if (!mounted) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: _PlayerTokens.background,
        body: Column(
          children: [
            _buildPlayerSection(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMetadataSection(),
                    _buildTabs(),
                    _buildEpisodeSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Player 16:9 + overlay kontrol custom sesuai desain Penpot.
  Widget _buildPlayerSection() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildVideoLayer(),
          _buildOverlay(isFullscreen: false),
        ],
      ),
    );
  }

  Widget _buildVideoLayer() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Video(
          controller: _videoController,
          fit: BoxFit.contain,
          // Kontrol digambar manual sesuai desain Penpot. Di mode
          // fullscreen/lanskap, kontrol bawaan media_kit tetap dipakai
          // (subtitle, audio track, speed, PiP) tanpa menggandakan ikon.
          controls: (state) => _isFullscreen
              ? AdaptiveVideoControls(state)
              : const SizedBox.shrink(),
        ),
        if (_isBuffering)
          const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _PlayerTokens.white,
              ),
            ),
          ),
        if (_errorMessage != null) _buildErrorView(_errorMessage!),
      ],
    );
  }

  Widget _buildOverlay({required bool isFullscreen}) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    // Di fullscreen/lanskap, kontrol center + progress + fullscreen diambil
    // dari AdaptiveVideoControls (media_kit) supaya tidak dobel.
    if (isFullscreen) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 16,
            left: 16,
            child: _buildIconButton(
              icon: Icons.close,
              size: 44,
              iconSize: 24,
              tooltip: 'Tutup player',
              onPressed: () {
                _saveWatchHistory();
                Navigator.of(context).pop();
              },
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildActionPill(
                  icon: Icons.dns_outlined,
                  label: 'Server',
                  value: _activeServer.isEmpty ? null : _activeServer,
                  onTap: _openServerSheet,
                ),
                const SizedBox(width: 8),
                _buildIconButton(
                  icon: Icons.fullscreen_exit,
                  size: 44,
                  iconSize: 24,
                  tooltip: 'Keluar fullscreen',
                  onPressed: _toggleFullscreen,
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Gradient tipis agar ikon tetap terbaca.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x66000000),
                Color(0x00000000),
                Color(0x99000000),
              ],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
        ),

        // Top bar: tombol close.
        Positioned(
          top: isFullscreen ? 16 : 10,
          left: 16,
          child: _buildIconButton(
            icon: Icons.close,
            size: isFullscreen ? 44 : 36,
            iconSize: isFullscreen ? 24 : 22,
            tooltip: 'Tutup player',
            onPressed: () {
              _saveWatchHistory();
              Navigator.of(context).pop();
            },
          ),
        ),

        // Center controls.
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCircleButton(
                icon: Icons.replay_10,
                size: 56,
                iconSize: 24,
                tooltip: 'Mundur 10 detik',
                onPressed: () => _seekBy(const Duration(seconds: -10)),
              ),
              const SizedBox(width: 32),
              _buildCircleButton(
                icon: _isPlaying ? Icons.pause : Icons.play_arrow,
                size: 60,
                iconSize: 30,
                tooltip: _isPlaying ? 'Pause' : 'Play',
                onPressed: _togglePlayPause,
              ),
              const SizedBox(width: 32),
              _buildCircleButton(
                icon: Icons.forward_10,
                size: 56,
                iconSize: 24,
                tooltip: 'Maju 10 detik',
                onPressed: () => _seekBy(const Duration(seconds: 10)),
              ),
            ],
          ),
        ),

        // Bottom bar: timestamp + fullscreen.
        Positioned(
          left: 16,
          right: 16,
          bottom: isFullscreen ? 20 : 12,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                style: const TextStyle(
                  color: _PlayerTokens.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Roboto Mono',
                ),
              ),
              _buildIconButton(
                icon: _isFullscreen
                    ? Icons.fullscreen_exit
                    : Icons.fullscreen,
                size: isFullscreen ? 44 : 36,
                iconSize: isFullscreen ? 24 : 22,
                tooltip: _isFullscreen ? 'Keluar fullscreen' : 'Fullscreen',
                onPressed: _toggleFullscreen,
              ),
            ],
          ),
        ),

        // Progress bar.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildProgressBar(screenWidth),
        ),
      ],
    );
  }

  Widget _buildProgressBar(double screenWidth) {
    final durationMs = _duration.inMilliseconds;
    final played = durationMs <= 0
        ? 0.0
        : (_position.inMilliseconds / durationMs).clamp(0.0, 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null || box.size.width <= 0) return;
        _seekToFraction(details.localPosition.dx / box.size.width);
      },
      child: SizedBox(
        height: 18,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Container(
              height: 4,
              color: _PlayerTokens.white.withValues(alpha: 0.18),
            ),
            Container(
              height: 4,
              width: screenWidth * played,
              color: _PlayerTokens.accent,
            ),
            Positioned(
              left: (screenWidth * played) - 7,
              child: Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(
                  color: _PlayerTokens.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required double size,
    required double iconSize,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Semantics(
      button: true,
      label: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          child: Icon(icon, color: _PlayerTokens.white, size: iconSize),
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required double size,
    required double iconSize,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Semantics(
      button: true,
      label: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _PlayerTokens.white.withValues(alpha: 0.12),
          ),
          child: Icon(icon, color: _PlayerTokens.white, size: iconSize),
        ),
      ),
    );
  }

  /// Metadata episode: judul, baris metadata, sinopsis, action pills.
  Widget _buildMetadataSection() {
    final synopsis = (widget.synopsis ?? '').trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.episodeName.isEmpty ? widget.title : widget.episodeName,
            style: const TextStyle(
              color: _PlayerTokens.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFamily: 'Roboto Mono',
              height: 1.2,
            ),
          ),
          if (widget.metaLine != null && widget.metaLine!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              widget.metaLine!.trim(),
              style: const TextStyle(
                color: _PlayerTokens.textMuted,
                fontSize: 13,
                fontFamily: 'Roboto Mono',
                height: 1.2,
              ),
            ),
          ],
          if (synopsis.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              synopsis,
              style: const TextStyle(
                color: _PlayerTokens.textBody,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 16),
          _buildActionPills(),
        ],
      ),
    );
  }

  Widget _buildActionPills() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildActionPill(
            icon: Icons.dns_outlined,
            label: 'Server',
            value: _activeServer.isEmpty ? null : _activeServer,
            onTap: _openServerSheet,
          ),
          const SizedBox(width: 8),
          _buildActionPill(
            icon: Icons.bookmark_add_outlined,
            label: 'My List',
            onTap: () => _showSimpleSnack('Disimpan ke My List'),
          ),
          const SizedBox(width: 8),
          _buildActionPill(
            icon: Icons.download_outlined,
            label: 'Download',
            onTap: () => _showSimpleSnack('Download belum tersedia'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionPill({
    required IconData icon,
    required String label,
    String? value,
    VoidCallback? onTap,
  }) {
    return Semantics(
      button: true,
      label: value == null ? label : '$label $value',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _PlayerTokens.pill,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: _PlayerTokens.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: _PlayerTokens.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
              if (value != null && value.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  value,
                  style: const TextStyle(
                    color: _PlayerTokens.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ],
              if (value != null) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.expand_more,
                  size: 12,
                  color: _PlayerTokens.white,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Tabs EPISODES / RELATED / COMMENTS dengan indikator aktif.
  Widget _buildTabs() {
    const tabs = <String>['EPISODES', 'RELATED', 'COMMENTS'];
    final active = _selectedTab ?? tabs.first;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final tab in tabs)
                Padding(
                  padding: const EdgeInsets.only(right: 32),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = tab),
                    child: Text(
                      tab,
                      style: TextStyle(
                        color: tab == active
                            ? _PlayerTokens.white
                            : _PlayerTokens.textMuted,
                        fontSize: 13,
                        fontWeight: tab == active
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontFamily: 'Roboto Mono',
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(width: 66, height: 3, color: _PlayerTokens.gold),
        ],
      ),
    );
  }

  /// Section daftar episode (vertikal, tanpa thumbnail).
  Widget _buildEpisodeSection() {
    final episodes = widget.episodes;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Season 1 Episodes',
            style: TextStyle(
              color: _PlayerTokens.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFamily: 'Roboto Mono',
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          if (episodes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Episode belum tersedia untuk anime ini',
                style: TextStyle(color: _PlayerTokens.textMuted, fontSize: 13),
              ),
            )
          else
            for (final episode in episodes) ...[
              _buildEpisodeRow(episode),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  Widget _buildEpisodeRow(PlayerEpisodeInfo episode) {
    final isCurrent = episode.number == widget.currentEpisodeNumber;

    return Semantics(
      button: true,
      label: 'Episode ${episode.number}',
      child: InkWell(
        onTap: () => _openEpisode(episode),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _PlayerTokens.surface,
            borderRadius: BorderRadius.circular(12),
            border: isCurrent
                ? Border.all(color: _PlayerTokens.gold, width: 1)
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _PlayerTokens.surfaceStrong,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  episode.number.toString(),
                  style: const TextStyle(
                    color: _PlayerTokens.white,
                    fontSize: 14,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      episode.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _PlayerTokens.white,
                        fontSize: 14,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      episode.subtitle ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _PlayerTokens.textMuted,
                        fontSize: 12,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _showSimpleSnack('Opsi episode ${episode.number}'),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.more_horiz,
                    size: 18,
                    color: _PlayerTokens.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView(String message) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            widget.videoUrl,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),
        ],
      ),
    );
  }

  void _showSimpleSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _PlayerTokens.surfaceStrong,
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    final total = duration.isNegative ? Duration.zero : duration;
    final hours = total.inHours;
    final minutes = total.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = total.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _saveWatchHistory();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _player.dispose();
    super.dispose();
  }
}
