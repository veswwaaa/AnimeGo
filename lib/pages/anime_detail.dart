import 'package:animego/models/model_anime.dart';
import 'package:flutter/material.dart';

class AnimeDetailPage extends StatefulWidget {
  final DataAnim anime;

  const AnimeDetailPage({super.key, required this.anime});

  @override
  State<AnimeDetailPage> createState() => _AnimeDetailPageState();
}

class _AnimeDetailPageState extends State<AnimeDetailPage> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}