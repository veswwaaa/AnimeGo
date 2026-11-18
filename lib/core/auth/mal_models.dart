/// Profil user MAL yang sudah dinormalisasi.
class MalUser {
  const MalUser({
    required this.id,
    required this.username,
    this.name,
    this.avatarUrl,
    this.animeCount,
  });

  final int id;
  final String username;
  final String? name;
  final String? avatarUrl;
  final int? animeCount;

  @override
  String toString() => 'MalUser(username: $username, id: $id)';
}

/// Status entri list MAL (sesuai MAL API).
class MalListStatus {
  static const int watching = 1;
  static const int completed = 2;
  static const int onHold = 3;
  static const int dropped = 4;
  static const int planToWatch = 6;
}

/// Satu entri watchlist MAL.
class MalListEntry {
  const MalListEntry({
    required this.malAnimeId,
    required this.title,
    required this.status,
    required this.numWatchedEpisodes,
    required this.totalEpisodes,
    this.score,
  });

  final int malAnimeId;
  final String title;
  final int status;
  final int? score;
  final int numWatchedEpisodes;
  final int totalEpisodes;
}

/// Error domain untuk alur MAL, dipetakan ke pesan user-friendly.
class MalAuthException implements Exception {
  const MalAuthException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'MalAuthException($message, status: $statusCode)';
}
