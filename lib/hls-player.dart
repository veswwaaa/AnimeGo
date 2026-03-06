import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

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
    super.initState();
    _player = Player();
    _videoController = VideoController(_player);
    _player.open(
      Media(
        'https://ESrZaEKj9iFIuE8.dramiyos-cdn.com/hls2/01/07528/9wfsi07o6mf1_h/index-v1-a1.m3u8?t=IHgobURsTxNmFPkqYXoV60p-t87OXQyBXgi-aqkzBJw&s=1772537176&e=129600&f=37644876&srv=ovC9UKBg4l5m&i=0.4&sp=500&p1=ovC9UKBg4l5m&p2=ovC9UKBg4l5m&asn=23693',
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
