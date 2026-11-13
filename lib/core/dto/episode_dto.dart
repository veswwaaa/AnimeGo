import 'api_envelope.dart';

/// Bentuk objek episode yang seragam lintas provider.
class EpisodeDto {
  const EpisodeDto({
    required this.id,
    required this.animeId,
    required this.number,
    this.title,
    this.url,
    this.airingDate,
    this.extra = const {},
  });

  final AnimeId id;
  final AnimeId animeId;
  final int number;
  final String? title;
  final String? url;
  final String? airingDate;
  final Map<String, dynamic> extra;

  Map<String, dynamic> toJson() => {
    'id': id.composite,
    'animeId': animeId.composite,
    'number': number,
    'title': title,
    'url': url,
    'airingDate': airingDate,
    'extra': extra,
  };
}
