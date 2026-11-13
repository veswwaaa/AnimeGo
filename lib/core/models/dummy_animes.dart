import 'anime.dart';

/// Data contoh untuk tampilan offline.
///
/// Dipisah dari file model supaya model purely data.
List<Anime> buildDummyAnimes() {
  return [
    Anime(
      title: 'Jujutsu Kaisen',
      imageUrl: 'https://picsum.photos/seed/jujutsu/400/600',
      rating: 8.6,
      genres: const ['Action', 'Fantasy', 'Supernatural'],
      sourceUrl: 'https://myanimelist.net/anime/40748/Jujutsu_Kaisen',
      episodes: 24,
      providerId: 'dummy',
    ),
    Anime(
      title: 'Attack on Titan',
      imageUrl: 'https://picsum.photos/seed/aot/400/600',
      rating: 9.0,
      genres: const ['Action', 'Drama', 'Fantasy'],
      sourceUrl: 'https://myanimelist.net/anime/16498/Shingeki_no_Kyojin',
      episodes: 24,
      providerId: 'dummy',
    ),
    Anime(
      title: 'Demon Slayer',
      imageUrl: 'https://picsum.photos/seed/demon/400/600',
      rating: 8.5,
      genres: const ['Action', 'Fantasy'],
      sourceUrl: 'https://myanimelist.net/anime/38000/Kimetsu_no_Yaiba',
      episodes: 24,
      providerId: 'dummy',
    ),
    Anime(
      title: 'SPY x FAMILY',
      imageUrl: 'https://picsum.photos/seed/spy/400/600',
      rating: 8.6,
      genres: const ['Action', 'Comedy'],
      sourceUrl: 'https://myanimelist.net/anime/50265/Spy_x_Family',
      episodes: 12,
      providerId: 'dummy',
    ),
    Anime(
      title: 'One Punch Man',
      imageUrl: 'https://picsum.photos/seed/onepunch/400/600',
      rating: 8.5,
      genres: const ['Action', 'Comedy'],
      sourceUrl: 'https://myanimelist.net/anime/30276/One_Punch_Man',
      episodes: 24,
      providerId: 'dummy',
    ),
  ];
}
