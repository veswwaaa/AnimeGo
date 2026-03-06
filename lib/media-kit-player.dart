// Make sure to add following packages to pubspec.yaml:
// * media_kit
// * media_kit_video
// * media_kit_libs_video
import 'package:flutter/material.dart';

import 'package:media_kit/media_kit.dart';                      // Provides [Player], [Media], [Playlist] etc.
import 'package:media_kit_video/media_kit_video.dart';          // Provides [VideoController] & [Video] etc.

class MyScreen extends StatefulWidget {
  const MyScreen({Key? key}) : super(key: key);
  @override
  State<MyScreen> createState() => MyScreenState();
}

class MyScreenState extends State<MyScreen> {
  // Create a [Player] to control playback.
  late final player = Player();
  // Create a [VideoController] to handle video output from [Player].
  late final controller = VideoController(player);

  @override
  void initState() {
    super.initState();
    // Play a [Media] or [Playlist].
    player.open(Media('https://halahgan.com/st/anime/Anime_O/Oshi_no_Ko_Season_3/7/2026/01/16/ar7zt31o-_Nimegami_Oshi_no_Ko_S3_Ep_01_720p_.mp4?exp=1772800925&sig=ca81f911a2b2146b7586dc367f7fa079dd9290f2e26f749446ae6c2ed561f67c&name=%5BNimegami%5D%20Oshi%20no%20Ko%20S3%20Ep%2001%20%28720p%29.mp4&filename=%5BNimegami%5D%20Oshi%20no%20Ko%20S3%20Ep%2001%20%28720p%29.mp4'));
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.width * 9.0 / 16.0,
        // Use [Video] widget to display video output.
        child: Video(controller: controller),
      ),
    );
  }
}