import '../auth/mal_models.dart';

/// Normalisasi response mentah MyAnimeList menjadi DTO internal.
///
/// Feature layer tidak boleh pernah menyentuh bentuk JSON vendor.
class MalMapper {
  const MalMapper._();

  /// Map `GET /v2/users/@me` -> [MalUser].
  static MalUser user(Map<String, dynamic> json) {
    final name = json['name'];
    final id = json['id'];
    final statistics = json['anime_statistics'];
    return MalUser(
      id: id is int ? id : int.tryParse('$id') ?? 0,
      username: (json['user_name'] ?? json['name'] ?? '').toString(),
      name: name is String ? name : null,
      avatarUrl: (json['picture'] ?? '').toString().isEmpty
          ? null
          : json['picture'].toString(),
      animeCount: statistics is Map && statistics['count_anime'] is int
          ? statistics['count_anime'] as int
          : null,
    );
  }

  /// Map satu node list MAL -> [MalListEntry].
  static MalListEntry listEntry(Map<String, dynamic> json) {
    final node = json['node'] is Map ? json['node'] as Map : json;
    final status = node['list_status'] is Map
        ? node['list_status'] as Map
        : <String, dynamic>{};
    final anime = node['anime'] is Map
        ? node['anime'] as Map
        : node;
    final id = anime['id'];
    final episodes = anime['num_episodes'];
    return MalListEntry(
      malAnimeId: id is int ? id : int.tryParse('$id') ?? 0,
      title: (anime['title'] ?? '').toString(),
      status: status['status'] is int ? status['status'] as int : 0,
      score: status['score'] is num ? (status['score'] as num).toInt() : null,
      numWatchedEpisodes: status['num_episodes_watched'] is int
          ? status['num_episodes_watched'] as int
          : 0,
      totalEpisodes: episodes is int ? episodes : 0,
    );
  }

  /// Map seluruh payload list -> list entri.
  static List<MalListEntry> list(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => listEntry(e.cast<String, dynamic>()))
        .toList(growable: false);
  }
}
