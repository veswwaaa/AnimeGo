import 'package:flutter/material.dart';
import 'package:animego/core/dto/anime_dto.dart';
import 'package:animego/core/providers/provider_container.dart';
import 'package:animego/core/utils/utils.dart';
import 'package:animego/features/anime-detail-screen/presentation/anime-detail-screen.dart';

// ==========================================
// 1. HOME SCREEN
// ==========================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<List<Anime>> _schedulesFuture;

  @override
  void initState() {
    super.initState();
    _schedulesFuture = _loadSchedules();
  }

  /// Seed query untuk mengisi beranda.
  ///
  /// Kontrak v2 tidak menyediakan endpoint "jadwal rilis", jadi beranda
  /// diisi dari hasil search provider Nimegami (REST v2).
  static const List<String> _seedQueries = <String>[
    'one piece',
    'naruto',
    'jujutsu kaisen',
    'solo leveling',
    'bleach',
  ];

  Future<List<Anime>> _loadSchedules() async {
    final registry = ProviderContainer.instance.registry;
    final provider = registry['nimegami'];
    if (provider == null || !provider.supportsSearch) {
      return const <Anime>[];
    }

    final seen = <String>{};
    final results = <Anime>[];

    // Semua seed paralel supaya beranda cepat terisi.
    final responses = await Future.wait(
      _seedQueries.map((query) async {
        try {
          return await provider.search(query);
        } catch (error) {
          logDev('gagal memuat seed "$query": $error', prefix: 'HomeScreen:');
          return const <AnimeDto>[];
        }
      }),
    );

    for (final dtos in responses) {
      for (final dto in dtos) {
        if (!seen.add(dto.id.composite)) continue;
        results.add(animeDtoToModel(dto));
      }
    }

    return results;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Anime>>(
      future: _schedulesFuture,
      builder: (context, snapshot) {
        final homeAnimes = (snapshot.data?.isNotEmpty ?? false)
            ? snapshot.data!
            : buildDummyAnimes();
        final featuredAnime = homeAnimes.first;
        final topRated = List<Anime>.from(homeAnimes)
          ..sort((a, b) => b.rating.compareTo(a.rating));

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AnimeDetailScreen(anime: featuredAnime),
                    ),
                  );
                },
                child: Stack(
                  children: [
                    ShaderMask(
                      shaderCallback: (rect) {
                        return const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black, Colors.transparent],
                        ).createShader(
                          Rect.fromLTRB(0, 0, rect.width, rect.height),
                        );
                      },
                      blendMode: BlendMode.dstIn,
                      child: buildSafeAnimeImage(
                        featuredAnime.imageUrl,
                        height: 450,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: featuredAnime.genres
                                .map(
                                  (g) => Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        g,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            featuredAnime.title,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            featuredAnime.synopsis,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              // Buka Video Player langsung saat klik Watch Now
                              // Navigator.push(context, MaterialPageRoute(
                              //   builder: (_) => AnimeVideoPlayerScreen(
                              //     title: featuredAnime.title,
                              //     episodeName: 'Episode 1'
                              //   )
                              // ));
                            },
                            icon: const Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Watch Noww',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF7A00),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              _buildHorizontalList('🔥 Latest Releases', homeAnimes, context),
              _buildHorizontalList('⭐ Top Rated', topRated, context),
              _buildHorizontalList('📡 Ongoing', homeAnimes, context),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHorizontalList(
    String title,
    List<Anime> animes,
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: animes.length,
            itemBuilder: (context, index) {
              final anime = animes[index];
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AnimeDetailScreen(anime: anime),
                  ),
                ),
                child: Container(
                  width: 120,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              buildSafeAnimeImage(
                                anime.imageUrl,
                                fit: BoxFit.cover,
                              ),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.black87,
                                        Colors.transparent,
                                      ],
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.star,
                                        color: Colors.orange,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${anime.rating}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        anime.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
