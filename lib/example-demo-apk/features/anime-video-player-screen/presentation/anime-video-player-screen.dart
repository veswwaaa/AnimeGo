import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../core/utils/utils.dart';
import '../../anime-detail-screen/data/google-blog-direct.dart';


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

  @override
  void initState() {
    super.initState();
    _player = Player();
    _videoController = VideoController(_player);
    _durationSubscription = _player.stream.duration.listen(
      _seekToInitialPositionWhenReady,
    );
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    // final hlsUrl = await getOdvidhideUrl("unx9ahyh9hzr");
    // print("URL HLS: $hlsUrl");

    // final targetUrl = (hlsUrl?.trim().isNotEmpty ?? false)
    //     ? hlsUrl!
    //     : widget.videoUrl;
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

    _player.open(
      Media(videoUri.toString(), httpHeaders: playbackHeaders),
      play: true,
    );
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
            child: Video(
              controller: _videoController,
              fit: BoxFit.contain,
              controls: (state) => AdaptiveVideoControls(state),
            ),
          ),
        ),
      ),
    );
  }
}
