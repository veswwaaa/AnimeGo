import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'api_config.dart';

// void main() {
//   runApp(const AniStreamApp());
// }

// ==========================================
// MAIN APP & THEME
// ==========================================
class AniStreamApp extends StatelessWidget {
  const AniStreamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AniStream',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D12),
        primaryColor: const Color(0xFFFF7A00),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF7A00),
          secondary: Color(0xFFFF7A00),
          surface: Color(0xFF1C1C24),
        ),
        fontFamily: 'Roboto',
      ),
      home: const MainNavigationScreen(),
    );
  }
}

// ==========================================
// DUMMY DATA MODEL
// ==========================================
class Anime {
  final String title;
  final String imageUrl;
  final double rating;
  final List<String> genres;
  final String synopsis;
  String sourceUrl;
  String? detailUrl;
  int episodes;

  Anime({
    required this.title,
    required this.imageUrl,
    required this.rating,
    required this.genres,
    required this.sourceUrl,
    this.detailUrl,
    required this.episodes,
    this.synopsis =
        "Yuji Itadori is a boy with tremendous physical strength, though he lives a completely ordinary high school life. One day, to save a friend who has been attacked by Curses, he eats a finger of Ryomen Sukuna, taking the Curse into his own soul.",
  });
}

List<Anime> dummyAnimes = [
  Anime(
    title: 'Jujutsu Kaisen',
    imageUrl: 'https://picsum.photos/seed/jujutsu/400/600',
    rating: 8.6,
    genres: ['Action', 'Fantasy', 'Supernatural'],
    sourceUrl: 'https://myanimelist.net/anime/40748/Jujutsu_Kaisen',
    episodes: 24,
  ),
  Anime(
    title: 'Attack on Titan',
    imageUrl: 'https://picsum.photos/seed/aot/400/600',
    rating: 9.0,
    genres: ['Action', 'Drama', 'Fantasy'],
    sourceUrl: 'https://myanimelist.net/anime/16498/Shingeki_no_Kyojin',
    episodes: 24,
  ),
  Anime(
    title: 'Demon Slayer',
    imageUrl: 'https://picsum.photos/seed/demon/400/600',
    rating: 8.5,
    genres: ['Action', 'Fantasy'],
    sourceUrl: 'https://myanimelist.net/anime/38000/Kimetsu_no_Yaiba',
    episodes: 24,
  ),
  Anime(
    title: 'SPY x FAMILY',
    imageUrl: 'https://picsum.photos/seed/spy/400/600',
    rating: 8.6,
    genres: ['Action', 'Comedy'],
    sourceUrl: 'https://myanimelist.net/anime/50265/Spy_x_Family',
    episodes: 12,
  ),
  Anime(
    title: 'One Punch Man',
    imageUrl: 'https://picsum.photos/seed/onepunch/400/600',
    rating: 8.5,
    genres: ['Action', 'Comedy'],
    sourceUrl: 'https://myanimelist.net/anime/30276/One_Punch_Man',
    episodes: 24,
  ),
];

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
  await Hive.initFlutter();
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

String formatPlaybackPosition(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}

String formatHistoryDate(DateTime dateTime) {
  final day = dateTime.day.toString().padLeft(2, '0');
  final month = dateTime.month.toString().padLeft(2, '0');
  final year = dateTime.year;
  return '$day/$month/$year';
}

String _fallbackImageForTitle(String title) {
  return 'https://picsum.photos/seed/${Uri.encodeComponent(title)}/400/600';
}

String _normalizeAnimeImageUrl(
  String? rawUrl, {
  required String fallbackTitle,
}) {
  final value = rawUrl?.trim() ?? '';
  if (value.isEmpty) {
    return _fallbackImageForTitle(fallbackTitle);
  }

  final parsed = Uri.tryParse(value);
  if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
    return _fallbackImageForTitle(fallbackTitle);
  }

  var normalized = parsed;
  if (normalized.scheme == 'http') {
    normalized = normalized.replace(scheme: 'https');
  }

  if (normalized.host == 'myanimelist.net' &&
      normalized.pathSegments.isNotEmpty &&
      normalized.pathSegments.first == 'images') {
    normalized = normalized.replace(host: 'cdn.myanimelist.net');
  }

  return normalized.toString();
}

String _extractBestImageUrl(dynamic images, {required String fallbackTitle}) {
  if (images is! Map<String, dynamic>) {
    return _fallbackImageForTitle(fallbackTitle);
  }

  final webp = images['webp'];
  if (webp is Map<String, dynamic>) {
    final large = webp['large_image_url']?.toString();
    if (large != null && large.trim().isNotEmpty) {
      return _normalizeAnimeImageUrl(large, fallbackTitle: fallbackTitle);
    }

    final normal = webp['image_url']?.toString();
    if (normal != null && normal.trim().isNotEmpty) {
      return _normalizeAnimeImageUrl(normal, fallbackTitle: fallbackTitle);
    }
  }

  final jpg = images['jpg'];
  if (jpg is Map<String, dynamic>) {
    final large = jpg['large_image_url']?.toString();
    if (large != null && large.trim().isNotEmpty) {
      return _normalizeAnimeImageUrl(large, fallbackTitle: fallbackTitle);
    }

    final normal = jpg['image_url']?.toString();
    if (normal != null && normal.trim().isNotEmpty) {
      return _normalizeAnimeImageUrl(normal, fallbackTitle: fallbackTitle);
    }
  }

  return _fallbackImageForTitle(fallbackTitle);
}

Widget buildSafeAnimeImage(
  String imageUrl, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
}) {
  return Image.network(
    _normalizeAnimeImageUrl(imageUrl, fallbackTitle: 'unknown'),
    width: width,
    height: height,
    fit: fit,
    filterQuality: FilterQuality.medium,
    errorBuilder: (_, __, ___) => Container(
      width: width,
      height: height,
      color: const Color(0xFF1C1C24),
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
    ),
  );
}

// ==========================================
// MAIN NAVIGATION (BOTTOM NAVBAR)
// ==========================================
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    SearchScreen(),
    const HistoryScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: const Color(0xFF14141A),
        selectedItemColor: const Color(0xFFFF7A00),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search_outlined),
            activeIcon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

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
    _schedulesFuture = getSchedules();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Anime>>(
      future: _schedulesFuture,
      builder: (context, snapshot) {
        final homeAnimes = (snapshot.data?.isNotEmpty ?? false)
            ? snapshot.data!
            : dummyAnimes;
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
                              'Watch Now',
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

// ==========================================
// 2. SEARCH SCREEN
// ==========================================
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _categories = [
    'All',
    'Action',
    'Adventure',
    'Comedy',
    'Drama',
    'Fantasy',
  ];

  int _selectedCategoryIndex = 0;
  bool _isLoading = false;
  String? _errorMessage;
  List<Anime> _searchResults = dummyAnimes;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onSearch(String value) async {
    final query = value.trim();
    if (query.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await searchAnime(query);
      if (!mounted) {
        return;
      }

      setState(() {
        _searchResults = results;
      });
    } catch (error, stackTrace) {
      _logError(
        'SearchScreen._onSearch gagal untuk query "$query"',
        error,
        stackTrace,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Gagal mencari anime. Cek koneksi lalu coba lagi.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search anime...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF1C1C24),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: _onSearch,
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final isSelected = index == _selectedCategoryIndex;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(
                      _categories[index],
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        _selectedCategoryIndex = index;
                      });
                    },
                    selectedColor: const Color(0xFFFF7A00),
                    backgroundColor: const Color(0xFF1C1C24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Expanded(child: _buildSearchContent()),
        ],
      ),
    );
  }

  Widget _buildSearchContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF7A00)),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Text(
          _errorMessage!,
          style: const TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return const Center(
        child: Text(
          'Anime tidak ditemukan',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final anime = _searchResults[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AnimeDetailScreen(anime: anime),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                buildSafeAnimeImage(anime.imageUrl, fit: BoxFit.cover),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black, Colors.transparent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                    child: Text(
                      anime.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ==========================================
// 3. HISTORY SCREEN
// ==========================================
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Watch History',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: () {
                    clearWatchHistory();
                  },
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                    size: 18,
                  ),
                  label: const Text(
                    'Clear',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<List<WatchHistoryItem>>(
              valueListenable: watchHistoryNotifier,
              builder: (context, history, _) {
                if (history.isEmpty) {
                  return const Center(
                    child: Text(
                      'Belum ada riwayat tontonan',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final item = history[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14141A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AnimeVideoPlayerScreen(
                                title: item.animeTitle,
                                animeImageUrl: item.animeImageUrl,
                                episodeName: item.episodeName,
                                videoUrl: item.videoUrl,
                                startAt: item.position,
                              ),
                            ),
                          );
                        },
                        contentPadding: const EdgeInsets.all(8),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: buildSafeAnimeImage(
                            item.animeImageUrl,
                            width: 60,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                        title: Text(
                          item.animeTitle,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              item.episodeName,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Terakhir: ${formatPlaybackPosition(item.position)} • ${formatHistoryDate(item.updatedAt)}',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 4. PROFILE SCREEN
// ==========================================
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.orange, Colors.purpleAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.person, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text(
              'Anime Fan',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'anime.fan@anistream.app',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),

            _buildProfileMenu(
              Icons.settings_outlined,
              'Settings',
              'Preferences and notifications',
            ),
            const SizedBox(height: 12),
            _buildProfileMenu(
              Icons.info_outline,
              'About AniStream',
              'Version 1.0.0',
            ),
            const SizedBox(height: 12),
            _buildProfileMenu(
              Icons.open_in_new,
              'Help & Support',
              'FAQs and contact',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileMenu(IconData icon, String title, String subtitle) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF14141A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.grey),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ),
    );
  }
}

// ==========================================
// 5. DETAIL SCREEN
// ==========================================
class AnimeDetailScreen extends StatefulWidget {
  Anime anime;

  AnimeDetailScreen({super.key, required this.anime});

  @override
  State<AnimeDetailScreen> createState() => _AnimeDetailScreenState();
}

class _AnimeDetailScreenState extends State<AnimeDetailScreen> {
  late Anime _anime;
  late final Anime _initialAnime;
  int serverId = 1;
  bool _isRefreshingDetail = false;

  Anime _cloneAnime(Anime source) {
    return Anime(
      title: source.title,
      imageUrl: source.imageUrl,
      rating: source.rating,
      genres: List<String>.from(source.genres),
      synopsis: source.synopsis,
      sourceUrl: source.sourceUrl,
      detailUrl: source.detailUrl,
      episodes: source.episodes,
    );
  }

  @override
  void initState() {
    super.initState();
    _anime = _cloneAnime(widget.anime);
    _initialAnime = _cloneAnime(widget.anime);
    _refreshAnimeDetail();
  }

  Future<void> _refreshAnimeDetail({
    String? sourceUrl,
    int? serverOverride,
  }) async {
    final activeServer = serverOverride ?? serverId;
    final targetSourceUrl = (sourceUrl ?? _anime.sourceUrl).trim();
    if (targetSourceUrl.isEmpty) {
      return;
    }

    setState(() {
      _isRefreshingDetail = true;
    });

    try {
      final latestAnime = await detailAnime(
        targetSourceUrl,
        serverId: activeServer,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _anime.sourceUrl = latestAnime.sourceUrl;
        _anime.episodes = latestAnime.episodes;
      });
    } catch (error, stackTrace) {
      _logError(
        'Gagal refresh detail anime: ${_anime.title}',
        error,
        stackTrace,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingDetail = false;
        });
      }
    }
  }

  Future<void> _changeServer(int targetServerId) async {
    print('Pindah ke server $targetServerId');
    if (targetServerId == serverId) {
      return;
    }

    setState(() {
      serverId = targetServerId;
    });

    if (targetServerId == 1) {
      print('Kembali ke server 1 dengan URL: ${_initialAnime.sourceUrl}');
      await _refreshAnimeDetail(
        sourceUrl: _initialAnime.sourceUrl,
        serverOverride: 1,
      );
      return;
    }

    try {
      final candidates = await searchAnime(_anime.title, serverId: 2);
      if (!mounted) {
        return;
      }

      if (candidates.isEmpty) {
        _showErrorSnackBar(context, 'Anime tidak ditemukan di Server 2.');
        return;
      }

      final selectedAnime = candidates.first;
      print(selectedAnime.title);
      print(selectedAnime.detailUrl);
      setState(() {
        _anime.sourceUrl = selectedAnime.sourceUrl;
        _anime.episodes = selectedAnime.episodes;
      });

      await _refreshAnimeDetail(
        sourceUrl: selectedAnime.detailUrl,
        serverOverride: 2,
      );
    } catch (error, stackTrace) {
      _logError(
        'Gagal pindah ke server 2 untuk anime: ${_anime.title}',
        error,
        stackTrace,
      );
      if (!mounted) {
        return;
      }
      _showErrorSnackBar(context, 'Gagal memuat data dari Server 2.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final episodeCount = _anime.episodes;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: const Color(0xFF0D0D12),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  buildSafeAnimeImage(_anime.imageUrl, fit: BoxFit.cover),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF0D0D12),
                          Colors.transparent,
                          Color(0xFF0D0D12),
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        stops: [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: buildSafeAnimeImage(
                          _anime.imageUrl,
                          width: 100,
                          height: 150,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _anime.title,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Status - 2020',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Colors.orange,
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${_anime.rating}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              children: _anime.genres
                                  .map(
                                    (g) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1C1C24),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        g,
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Synopsis',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _anime.synopsis,
                    style: const TextStyle(color: Colors.grey, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Select Server',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _changeServer(1),
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: serverId == 1
                                  ? const Color(0xFFFF7A00)
                                  : const Color(0xFF1C1C24),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Server 1',
                                  style: TextStyle(
                                    color: serverId == 1
                                        ? Colors.white
                                        : Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '2 eps',
                                  style: TextStyle(
                                    color: serverId == 1
                                        ? Colors.white
                                        : Colors.orangeAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _changeServer(2),
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: serverId == 2
                                  ? const Color(0xFFFF7A00)
                                  : const Color(0xFF1C1C24),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Server 2',
                                  style: TextStyle(
                                    color: serverId == 2
                                        ? Colors.white
                                        : Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '12 eps',
                                  style: TextStyle(
                                    color: serverId == 2
                                        ? Colors.white
                                        : Colors.orangeAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Episodes ($episodeCount)',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_isRefreshingDetail)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  if (episodeCount <= 0)
                    const Text(
                      'Episode belum tersedia',
                      style: TextStyle(color: Colors.grey),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: episodeCount,
                      padding: EdgeInsets.zero,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () async {
                            final sourceUrl = _anime.sourceUrl.trim();
                            if (sourceUrl.isEmpty) {
                              _showErrorSnackBar(
                                context,
                                'Episode belum tersedia untuk anime ini.',
                              );
                              _logInfo(
                                'Source URL kosong untuk anime: ${_anime.title}',
                              );
                              return;
                            }

                            final episodeUrl = await animeEpisode(
                              sourceUrl,
                              index + 1,
                              serverId,
                            );
                            if (!context.mounted) {
                              return;
                            }

                            if (episodeUrl == null || episodeUrl.isEmpty) {
                              _showErrorSnackBar(
                                context,
                                'Gagal memuat episode. Silakan coba lagi.',
                              );
                              return;
                            }

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AnimeVideoPlayerScreen(
                                  title: _anime.title,
                                  animeImageUrl: _anime.imageUrl,
                                  episodeName: 'Episode ${index + 1}',
                                  videoUrl: episodeUrl,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF14141A),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1C1C24),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_arrow,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                'Episode ${index + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: const Text(
                                '24 min',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 6. VIDEO PLAYER SCREEN (NEW)
// ==========================================
class AnimeVideoPlayerScreen extends StatefulWidget {
  final String title;
  final String animeImageUrl;
  final String episodeName;
  final String videoUrl;
  final Duration startAt;

  const AnimeVideoPlayerScreen({
    super.key,
    required this.title,
    required this.animeImageUrl,
    required this.episodeName,
    required this.videoUrl,
    this.startAt = Duration.zero,
  });

  @override
  State<AnimeVideoPlayerScreen> createState() => _AnimeVideoPlayerScreenState();
}

class _AnimeVideoPlayerScreenState extends State<AnimeVideoPlayerScreen> {
  late final Player _player;
  late final VideoController _videoController;
  StreamSubscription<Duration>? _durationSubscription;
  bool _didSaveHistory = false;
  bool _didSeekInitialPosition = false;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _videoController = VideoController(_player);
    _durationSubscription = _player.stream.duration.listen(
      _seekToInitialPositionWhenReady,
    );
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    // final hlsUrl = await getOdvidhideUrl("unx9ahyh9hzr");
    // print("URL HLS: $hlsUrl");

    // final targetUrl = (hlsUrl?.trim().isNotEmpty ?? false)
    //     ? hlsUrl!
    //     : widget.videoUrl;
    final targetUrl = widget.videoUrl;
    final parsedUri = Uri.tryParse(targetUrl);
    final fallbackUri = Uri.parse(
      'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
    );

    final videoUri =
        (parsedUri != null &&
            (parsedUri.isScheme('http') || parsedUri.isScheme('https')))
        ? parsedUri
        : fallbackUri;

    if (videoUri == fallbackUri) {
      _logInfo(
        'Video URL tidak valid, gunakan fallback video. Input: $targetUrl',
      );
    }

    if (!mounted) {
      return;
    }

    _player.open(Media(videoUri.toString()), play: true);
  }

  void _seekToInitialPositionWhenReady(Duration totalDuration) {
    if (_didSeekInitialPosition) {
      return;
    }

    if (totalDuration <= Duration.zero) {
      return;
    }

    _didSeekInitialPosition = true;
    final target = widget.startAt;
    if (target <= Duration.zero) {
      return;
    }

    final safeTarget = (target > totalDuration) ? totalDuration : target;
    _player.seek(safeTarget);
  }

  void _saveWatchHistory() {
    if (_didSaveHistory) {
      return;
    }

    _didSaveHistory = true;
    Duration currentPosition = widget.startAt;

    currentPosition = _player.state.position;
    final duration = _player.state.duration;
    if (duration > Duration.zero && currentPosition > duration) {
      currentPosition = duration;
    }

    upsertWatchHistory(
      WatchHistoryItem(
        animeTitle: widget.title,
        animeImageUrl: widget.animeImageUrl,
        episodeName: widget.episodeName,
        videoUrl: widget.videoUrl,
        positionSeconds: currentPosition.inSeconds,
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _saveWatchHistory();
    _durationSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _saveWatchHistory();
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                widget.episodeName,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        body: Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Video(
              controller: _videoController,
              fit: BoxFit.contain,
              controls: (state) => AdaptiveVideoControls(state),
            ),
          ),
        ),
      ),
    );
  }
}

Future<List<Anime>> searchAnime(String query, {int serverId = 1}) async {
  final trimmedQuery = query.trim();
  if (trimmedQuery.isEmpty) {
    return [];
  }

  late final http.Response response;

  switch (serverId) {
    case 1:
      try {
        response = await _httpGetWithRetry(
          Uri.parse(
            '$apiBaseUrl/api/nimegami/search?q=${Uri.encodeQueryComponent(trimmedQuery)}',
          ),
          timeout: const Duration(seconds: 45),
          maxAttempts: 2,
        );
      } on TimeoutException catch (error, stackTrace) {
        _logError(
          'searchAnime timeout untuk query "$query"',
          error,
          stackTrace,
        );
        rethrow;
      } catch (error, stackTrace) {
        _logError(
          'searchAnime request gagal untuk query "$query"',
          error,
          stackTrace,
        );
        rethrow;
      }

      if (response.statusCode != 200) {
        throw Exception(
          'Search API gagal dengan status ${response.statusCode}',
        );
      }

      late final dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (error, stackTrace) {
        _logError('searchAnime gagal parse response JSON', error, stackTrace);
        rethrow;
      }

      if (decoded is! List) {
        throw Exception('Invalid response format');
      }

      final animeFutures = decoded.whereType<Map<String, dynamic>>().map((
        item,
      ) {
        final animeUrl = item['url']?.toString().trim() ?? '';
        if (animeUrl.isEmpty) {
          return Future<Anime?>.value(null);
        }

        return detailAnime(
          animeUrl,
          serverId: 1,
        ).then<Anime?>((value) => value).catchError((error, stackTrace) {
          _logError(
            'searchAnime skip item gagal detail url: $animeUrl',
            error,
            stackTrace,
          );
          return null;
        });
      });

      final animeList = await Future.wait(animeFutures);
      return animeList.whereType<Anime>().toList();
    case 2:
      final normalizedQuery = _normalizeZoronimeSearchQuery(trimmedQuery);
      try {
        response = await _httpGetWithRetry(
          Uri.parse(
            '$apiBaseUrl/api/zoronime/search?q=${Uri.encodeQueryComponent(normalizedQuery)}',
          ),
          timeout: const Duration(seconds: 45),
          maxAttempts: 2,
        );
      } catch (error, stackTrace) {
        _logError(
          'searchAnime(zoronime) request gagal untuk query "$normalizedQuery"',
          error,
          stackTrace,
        );
        rethrow;
      }

      if (response.statusCode != 200) {
        throw Exception(
          'Search API zoronime gagal dengan status ${response.statusCode}',
        );
      }

      late final dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (error, stackTrace) {
        _logError(
          'searchAnime(zoronime) gagal parse response JSON',
          error,
          stackTrace,
        );
        rethrow;
      }

      if (decoded is! List) {
        throw const FormatException(
          'searchAnime(zoronime) response bukan list',
        );
      }

      final animeFutures = decoded.whereType<Map<String, dynamic>>().map((
        item,
      ) {
        final animeUrl =
            item['sourceUrl']?.toString().trim() ??
            item['url']?.toString().trim() ??
            '';

        final fallbackTitle =
            item['title']?.toString().trim() ?? 'Untitled Anime';
        final fallbackAnime = Anime(
          title: fallbackTitle.isEmpty ? 'Untitled Anime' : fallbackTitle,
          imageUrl: _normalizeAnimeImageUrl(
            item['imageUrl']?.toString(),
            fallbackTitle: fallbackTitle,
          ),
          rating: (item['rating'] is num)
              ? (item['rating'] as num).toDouble()
              : double.tryParse('${item['rating']}') ?? 0.0,
          genres: _parseGenres(item['genres']),
          synopsis: (item['synopsis']?.toString().trim().isEmpty ?? true)
              ? 'No synopsis available'
              : item['synopsis'].toString().trim(),
          sourceUrl: animeUrl,
          episodes: _parseEpisodeCount(item['episodes']),
        );

        if (animeUrl.isEmpty) {
          return Future<Anime?>.value(fallbackAnime);
        }

        return detailAnime(
          animeUrl,
          serverId: 2,
        ).then<Anime?>((value) => value).catchError((error, stackTrace) {
          _logError(
            'searchAnime(zoronime) fallback item url: $animeUrl',
            error,
            stackTrace,
          );
          return fallbackAnime;
        });
      });

      final animeList = await Future.wait(animeFutures);
      return animeList.whereType<Anime>().toList();
  }
  return [];
}

Future<String?> animeEpisode(String rawUrl, int eps, int server) async {
  Future<String?> fetchEpisodeFrom(String endpoint) async {
    try {
      final trimmedUrl = rawUrl.trim();
      if (trimmedUrl.isEmpty) {
        return null;
      }

      final String encodedUrl = (server == 2)
          ? Uri.encodeQueryComponent(trimmedUrl)
          : base64Encode(utf8.encode(trimmedUrl));
      final String apiUrl = '$apiBaseUrl$endpoint?url=$encodedUrl&eps=$eps';

      _logInfo('Requesting episode: $apiUrl');

      final response = await _httpGetWithRetry(
        Uri.parse(apiUrl),
        timeout: const Duration(seconds: 60),
        maxAttempts: 2,
      );

      print("Response status: ${response.body}");

      if (response.statusCode != 200) {
        _logInfo(
          'Error Log: Server error episode dengan status ${response.statusCode}',
        );
        return null;
      }

      final dynamic decodedDynamic = jsonDecode(response.body);

      if (decodedDynamic is String && decodedDynamic.trim().isNotEmpty) {
        return decodedDynamic.trim();
      }

      if (decodedDynamic is! Map<String, dynamic>) {
        _logInfo('Error Log: Format response episode tidak valid.');
        return null;
      }

      final directUrl = (server == 2)
        ? (await getOdvidhideUrl(decodedDynamic['url']))?.trim() ?? '' :
          decodedDynamic['url']?.toString().trim() ??
          decodedDynamic['videoUrl']?.toString().trim() ??
          decodedDynamic['streamUrl']?.toString().trim() ??
          '';
      
      print(directUrl);

      if (directUrl.isNotEmpty) {
        return directUrl;
      }

      final data = decodedDynamic['data'];
      if (data is Map<String, dynamic>) {
        final nestedUrl = (server == 2)
            ? (await getOdvidhideUrl(data['url']))?.trim() ?? ''
            : data['url']?.toString().trim() ??
              data['videoUrl']?.toString().trim() ??
              data['streamUrl']?.toString().trim() ??
              '';
        print("Nested URL: $nestedUrl");
        if (nestedUrl.isNotEmpty) {
          return nestedUrl;
        }
      }

      return null;
    } catch (error, stackTrace) {
      _logError(
        'Error Log: Terjadi kesalahan fatal saat ambil episode',
        error,
        stackTrace,
      );
      return null;
    }
  }

  switch (server) {
    case 1:
      return await fetchEpisodeFrom('/api/nimegami/media');
    case 2:
      return await fetchEpisodeFrom('/api/zoronime/media');
    default:
      _logInfo('server tidak dikenal: $server');
      return null;
  }
}

Future<Anime> detailAnime(String url, {int serverId = 1}) async {
  print('detailAnime called with url: $url, serverId: $serverId');
  final trimmedUrl = url.trim();
  if (trimmedUrl.isEmpty) {
    throw const FormatException('detailAnime url kosong');
  }

  _logInfo('detailAnime called with url: $trimmedUrl');

  final endpoint = serverId == 2
      ? '/api/zoronime/anime'
      : '/api/nimegami/anime';

  //jika serverid 1 itu pake tobase64, jika serverid 2 dia tidak pake tobase64
  // final response = await _httpGetWithRetry(
  //   Uri.parse('$apiBaseUrl$endpoint?url=${toBase64(trimmedUrl)}'),
  //   timeout: const Duration(seconds: 45),
  //   maxAttempts: 2,
  // );
  final response = await _httpGetWithRetry(
    Uri.parse(
      serverId == 2
          ? '$apiBaseUrl$endpoint?url=${Uri.encodeQueryComponent(trimmedUrl)}'
          : '$apiBaseUrl$endpoint?url=${toBase64(trimmedUrl)}',
    ),
    timeout: const Duration(seconds: 45),
    maxAttempts: 2,
  );

  if (response.statusCode != 200) {
    throw Exception('detailAnime gagal dengan status ${response.statusCode}');
  }

  late final dynamic decoded;
  try {
    decoded = jsonDecode(response.body);
  } catch (error, stackTrace) {
    _logError('detailAnime gagal parse response JSON', error, stackTrace);
    rethrow;
  }

  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('detailAnime response bukan object');
  }

  final Map<String, dynamic> animePayload =
      (decoded['name'] is Map<String, dynamic>)
      ? decoded['name'] as Map<String, dynamic>
      : decoded;

  final rawTitle =
      animePayload['title']?.toString().trim() ??
      animePayload['name']?.toString().trim() ??
      '';
  final safeTitle = rawTitle.isEmpty ? 'Untitled Anime' : rawTitle;
  final fallbackImage = _normalizeAnimeImageUrl(
    animePayload['imageUrl']?.toString(),
    fallbackTitle: safeTitle,
  );

  final imageUrl = (animePayload['images'] is Map<String, dynamic>)
      ? _extractBestImageUrl(animePayload['images'], fallbackTitle: safeTitle)
      : fallbackImage;

  return Anime(
    title: safeTitle,
    imageUrl: imageUrl,
    rating: (animePayload['score'] is num)
        ? (animePayload['score'] as num).toDouble()
        : (animePayload['rating'] is num)
        ? (animePayload['rating'] as num).toDouble()
        : double.tryParse(
                '${animePayload['score'] ?? animePayload['rating']}',
              ) ??
              0.0,
    genres: _parseGenres(animePayload['genres']),
    synopsis: (animePayload['synopsis']?.toString().trim().isEmpty ?? true)
        ? 'No synopsis available'
        : animePayload['synopsis'].toString().trim(),
    sourceUrl: animePayload['sourceUrl']?.toString().trim().isNotEmpty == true
        ? animePayload['sourceUrl'].toString().trim()
        : trimmedUrl,
    detailUrl: trimmedUrl,
    episodes: _parseEpisodeCount(
      animePayload['last_episode'] ?? animePayload['episodes'],
    ),
  );
}

String _normalizeZoronimeSearchQuery(String input) {
  return input
      .toLowerCase()
      // Remove only bracket characters, keep the text inside.
      .replaceAll(RegExp(r'[\[\]\(\)\{\}]'), ' ')
      // Convert ordinal suffixes: 3rd -> 3, 1st -> 1.
      .replaceAllMapped(
        RegExp(r'\b(\d+)(st|nd|rd|th)\b'),
        (match) => match.group(1)!,
      )
      .replaceAll(RegExp(r'[-_]'), ' ')
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

List<String> _parseGenres(dynamic rawGenres) {
  if (rawGenres is! List) {
    return ['Unknown'];
  }

  final genres = rawGenres
      .map((genre) {
        if (genre is Map<String, dynamic>) {
          return genre['name']?.toString().trim() ?? '';
        }
        return genre?.toString().trim() ?? '';
      })
      .where((genre) => genre.isNotEmpty)
      .toList();

  return genres.isEmpty ? ['Unknown'] : genres;
}

void _logInfo(String message) {
  developer.log(message, name: 'ExampleScreen');
}

void _logError(String message, Object error, StackTrace stackTrace) {
  developer.log(
    message,
    name: 'ExampleScreen',
    error: error,
    stackTrace: stackTrace,
  );
}

void _showErrorSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

String toBase64(String input) {
  List<int> bytes = utf8.encode(input);
  String base64Encoded = base64Encode(bytes);
  return base64Encoded;
}

Future<http.Response> _httpGetWithRetry(
  Uri uri, {
  required Duration timeout,
  int maxAttempts = 2,
}) async {
  Object? lastError;
  StackTrace? lastStackTrace;

  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await http.get(uri).timeout(timeout);
    } catch (error, stackTrace) {
      lastError = error;
      lastStackTrace = stackTrace;

      if (attempt >= maxAttempts) {
        Error.throwWithStackTrace(error, stackTrace);
      }

      await Future.delayed(Duration(milliseconds: 500 * attempt));
    }
  }

  if (lastError != null && lastStackTrace != null) {
    Error.throwWithStackTrace(lastError, lastStackTrace);
  }

  throw TimeoutException('Request gagal setelah retry', timeout);
}

Future<List<Anime>> getSchedules() async {
  _logInfo('schedules called');
  try {
    final response = await _httpGetWithRetry(
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
      final episode = _parseEpisodeCount(item['last_episode']);
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
        imageUrl: _extractBestImageUrl(
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
    _logError('schedules request failed', error, stackTrace);
    return [];
  }
}

int _parseEpisodeCount(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim()) ?? 0;
  }
  return 0;
}

Future<String?> getOdvidhideUrl(String fileId) async {
  final embedUrl = Uri.parse('https://odvidhide.com/embed/$fileId');

  try {
    // 1. Fetch HTML embed page
    final response = await http.get(
      embedUrl,
      headers: {
        "User-Agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Referer": "https://odvidhide.com/",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception("Gagal memuat halaman: HTTP ${response.statusCode}");
    }

    final html = response.body;

    // 2. Cari packed script
    final packerRegex = RegExp(r"eval\(function\(p,a,c,k,e,d\)[\s\S]+?\.split\('\|'\)\)\)");
    final packerMatch = packerRegex.firstMatch(html);
    if (packerMatch == null) throw Exception("Packed script tidak ditemukan");

    final packedScript = packerMatch.group(0)!;

    // Decode JavaScript Packer (p,a,c,k,e,d) secara inline
    final decodeRegex = RegExp(r"}\s*\(\s*'([\s\S]*?)'\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*'([\s\S]*?)'\.split\(\s*'\|'\s*\)");
    final decodeMatch = decodeRegex.firstMatch(packedScript);
    if (decodeMatch == null) throw Exception("Tidak bisa parse packed script");

    String p = decodeMatch.group(1)!;
    final int a = int.parse(decodeMatch.group(2)!);
    final int c = int.parse(decodeMatch.group(3)!);
    final List<String> k = decodeMatch.group(4)!.split('|');

    // Proses decoding
    for (int i = c - 1; i >= 0; i--) {
      // Sama seperti `if (k[i])` di JS
      if (i < k.length && k[i].isNotEmpty) {
        // toRadixString di Dart berfungsi persis seperti toString(radix) di JS (mendukung base 2-36)
        final radixStr = i.toRadixString(a); 
        p = p.replaceAll(RegExp(r'\b' + radixStr + r'\b'), k[i]);
      }
    }
    
    final decoded = p;

    // 3. Cari object links/o yang berisi video sources
    final objectRegex = RegExp(r"var\s+(?:links|o)\s*=\s*(\{[\s\S]*?\})\s*;");
    final objectMatch = objectRegex.firstMatch(decoded);
    if (objectMatch == null) throw Exception("Video sources tidak ditemukan");

    final objectStr = objectMatch.group(1)!;

    // 4. Ambil URL hls2
    final hls2Regex = RegExp(r'''["']hls2["']\s*:\s*["']([^"']+)["']''');
    final hls2Match = hls2Regex.firstMatch(objectStr);
    if (hls2Match == null) throw Exception("URL hls2 tidak ditemukan");

    final masterUrl = hls2Match.group(1)!;

    // 5. Convert master.m3u8 → index-v1-a1.m3u8
    final queryStart = masterUrl.indexOf("?");
    String basePath = masterUrl;
    String queryString = "";

    if (queryStart != -1) {
      basePath = masterUrl.substring(0, queryStart);
      queryString = masterUrl.substring(queryStart);
    }

    // Replace master.m3u8 di akhir path lalu gabungkan dengan query string
    final indexUrl = basePath.replaceAll(RegExp(r'master\.m3u8$'), 'index-v1-a1.m3u8') + queryString;

    return indexUrl;

  } catch (e) {
    // Print error untuk mempermudah debugging
    print("Error saat mengekstrak URL: $e");
    return null;
  }
}