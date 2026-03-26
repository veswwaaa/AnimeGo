// import 'package:animego/example-screen.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import './example-demo-apk/ani-stream-app.dart';
import './example-demo-apk/core/utils/utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:animego/hls-player.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await initWatchHistoryStorage();
  await Supabase.initialize(
    url: "https://lcbvrokfqpaylclxhpqn.supabase.co",
    anonKey: "sb_publishable_A3QTA86sUrkBFlrFC-LT5Q_iuKAUYqI",
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: AniStreamApp(),
    );
  }
}




