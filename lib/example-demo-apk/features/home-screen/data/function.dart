import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:animego/example-demo-apk/core/config/api_config.dart';
import 'package:animego/example-demo-apk/core/utils/utils.dart';

Future<List<Anime>> getSchedules() async {
  logDev('schedules called', prefix: 'getSchedules:');
  try {
    final response = await httpGetWithRetry(
      Uri.parse('$apiBaseUrl/api/nimegami/schedules'),
      timeout: const Duration(seconds: 60),
      maxAttempts: 2,
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Schedules API gagal dengan status ${response.statusCode}',
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    final List<dynamic> rawSchedules;

    if (decoded is Map<String, dynamic> && decoded['animeUpdates'] is List) {
      rawSchedules = decoded['animeUpdates'] as List<dynamic>;
    } else if (decoded is List) {
      rawSchedules = decoded;
    } else {
      throw Exception('Format response schedules tidak valid');
    }

    final schedules = rawSchedules.whereType<Map<String, dynamic>>().map((
      item,
    ) {
      final episode = parseEpisodeCount(item['last_episode']);
      final sourceUrl = item['sourceUrl']?.toString().trim() ?? '';
      final title = item['title']?.toString().trim();
      final synopsis = item['synopsis']?.toString().trim();

      final images = item['images'];

      final score = item['score'];
      final rating = score is num
          ? score.toDouble()
          : double.tryParse('$score') ?? 0.0;

      final genres = (item['genres'] as List<dynamic>?)
          ?.where((genre) => genre != null)
          .map((genre) => genre.toString())
          .where((genre) => genre.isNotEmpty)
          .toList();

      return Anime(
        title: (title == null || title.isEmpty) ? 'Untitled Anime' : title,
        imageUrl: extractBestImageUrl(
          images,
          fallbackTitle: (title == null || title.isEmpty) ? 'unknown' : title,
        ),
        rating: rating,
        genres: (genres == null || genres.isEmpty) ? ['Unknown'] : genres,
        synopsis: (synopsis == null || synopsis.isEmpty)
            ? 'No synopsis available'
            : synopsis,
        sourceUrl: sourceUrl,
        episodes: episode,
      );
    }).toList();

    dummyAnimes = schedules;
    return schedules;
  } catch (error, stackTrace) {
    logDev(
      'schedules request failed: $error\n$stackTrace',
      prefix: 'getSchedules:',
    );
    return [];
  }
}

