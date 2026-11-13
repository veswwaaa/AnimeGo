import 'api_envelope.dart';

/// Bentuk objek anime yang seragam lintas provider.
class AnimeDto {
  const AnimeDto({
    required this.id,
    required this.provider,
    required this.title,
    required this.image,
    this.description,
    this.genres = const [],
    this.status = 'Unknown',
    this.rating = 0,
    this.year,
    this.totalEpisodes,
    this.episodeListUrl,
    this.url,
    this.extra = const {},
  });

  final AnimeId id;
  final String provider;
  final String title;
  final String? image;
  final String? description;
  final List<String> genres;
  final String status;
  final double rating;
  final int? year;
  final int? totalEpisodes;
  final String? episodeListUrl;
  final String? url;
  final Map<String, dynamic> extra;

  Map<String, dynamic> toJson() => {
    'id': id.composite,
    'provider': provider,
    'title': title,
    'image': image,
    'description': description,
    'genres': genres,
    'status': status,
    'rating': rating,
    'year': year,
    'totalEpisodes': totalEpisodes,
    'episodeListUrl': episodeListUrl,
    'url': url,
    'extra': extra,
  };
}
