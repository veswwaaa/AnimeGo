import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:animego/core/utils/utils.dart';
import 'package:animego/features/anime-detail-screen/data/google-blog-direct.dart';

// ==========================================
// 6. VIDEO PLAYER SCREEN (NEW)
// ==========================================
class AnimeVideoPlayerScreen extends StatefulWidget {
  final String title;
  final String animeImageUrl;
  final String episodeName;
  final String videoUrl;
  final Duration startAt;

  const AnimeVideoPlayerScreen({
    super.key,
    required this.title,
    required this.animeImageUrl,
    required this.episodeName,
    required this.videoUrl,
    this.startAt = Duration.zero,
  });

  @override
  State<AnimeVideoPlayerScreen> createState() => _AnimeVideoPlayerScreenState();
}

class _AnimeVideoPlayerScreenState extends State<AnimeVideoPlayerScreen> {
  late final Player _player;
  late final VideoController _videoController;
  StreamSubscription<Duration>? _durationSubscription;
  bool _didSaveHistory = false;
  bool _didSeekInitialPosition = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _videoController = VideoController(_player);
    _durationSubscription = _player.stream.duration.listen(
      _seekToInitialPositionWhenReady,
    );
    _listenToPlayerErrors();
    _initializePlayer();
  }

  /// Menangkap error dari mpv supaya penyebab gagalnya tampil di layar.
  void _listenToPlayerErrors() {
    _player.stream.error.listen((error) {
      logDev('Player error: $error', prefix: 'AnimeVideoPlayer:');
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Gagal memuat video: $error';
      });
    });
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

  @override
  void dispose() {
    _saveWatchHistory();
    _durationSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _saveWatchHistory();
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                widget.episodeName,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        body: Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Video(
                  controller: _videoController,
                  fit: BoxFit.contain,
                  controls: (state) => AdaptiveVideoControls(state),
                ),
                if (_errorMessage != null) _buildErrorView(_errorMessage!),
              ],
            ),
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
}
