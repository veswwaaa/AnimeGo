import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../utils/hive_bootstrap.dart';

class WatchHistoryItem {
  final String animeTitle;
  final String animeImageUrl;
  final String episodeName;
  final String videoUrl;
  final int positionSeconds;
  final DateTime updatedAt;

  const WatchHistoryItem({
    required this.animeTitle,
    required this.animeImageUrl,
    required this.episodeName,
    required this.videoUrl,
    required this.positionSeconds,
    required this.updatedAt,
  });

  Duration get position => Duration(seconds: positionSeconds);

  Map<String, dynamic> toMap() {
    return {
      'animeTitle': animeTitle,
      'animeImageUrl': animeImageUrl,
      'episodeName': episodeName,
      'videoUrl': videoUrl,
      'positionSeconds': positionSeconds,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static WatchHistoryItem? fromMap(Map<dynamic, dynamic> map) {
    final animeTitle = map['animeTitle'] as String?;
    final animeImageUrl = map['animeImageUrl'] as String?;
    final episodeName = map['episodeName'] as String?;
    final videoUrl = map['videoUrl'] as String?;
    final positionSecondsRaw = map['positionSeconds'];
    final updatedAtRaw = map['updatedAt'] as String?;

    if (animeTitle == null ||
        animeImageUrl == null ||
        episodeName == null ||
        videoUrl == null ||
        positionSecondsRaw == null ||
        updatedAtRaw == null) {
      return null;
    }

    final parsedDate = DateTime.tryParse(updatedAtRaw);
    if (parsedDate == null) {
      return null;
    }

    return WatchHistoryItem(
      animeTitle: animeTitle,
      animeImageUrl: animeImageUrl,
      episodeName: episodeName,
      videoUrl: videoUrl,
      positionSeconds: (positionSecondsRaw as num).toInt(),
      updatedAt: parsedDate,
    );
  }
}

final ValueNotifier<List<WatchHistoryItem>> watchHistoryNotifier =
    ValueNotifier<List<WatchHistoryItem>>([]);

const String _watchHistoryBoxName = 'watch_history_box';
const String _watchHistoryStorageKey = 'items';
Box<dynamic>? _watchHistoryBox;

Future<void> initWatchHistoryStorage() async {
  await ensureHiveInitialized();
  _watchHistoryBox ??= await Hive.openBox<dynamic>(_watchHistoryBoxName);

  final stored = _watchHistoryBox!.get(_watchHistoryStorageKey);
  if (stored is! List) {
    watchHistoryNotifier.value = [];
    return;
  }

  final items =
      stored
          .whereType<Map>()
          .map((entry) => WatchHistoryItem.fromMap(entry))
          .whereType<WatchHistoryItem>()
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  watchHistoryNotifier.value = items;
}

void _persistWatchHistory(List<WatchHistoryItem> items) {
  final box = _watchHistoryBox;
  if (box == null) {
    return;
  }

  final serialized = items.map((item) => item.toMap()).toList();
  unawaited(box.put(_watchHistoryStorageKey, serialized));
}

void upsertWatchHistory(WatchHistoryItem item) {
  final current = List<WatchHistoryItem>.from(watchHistoryNotifier.value);
  current.removeWhere(
    (existing) =>
        existing.animeTitle == item.animeTitle &&
        existing.episodeName == item.episodeName,
  );
  current.insert(0, item);
  watchHistoryNotifier.value = current;
  _persistWatchHistory(current);
}

void clearWatchHistory() {
  watchHistoryNotifier.value = [];
  _persistWatchHistory(const []);
}
