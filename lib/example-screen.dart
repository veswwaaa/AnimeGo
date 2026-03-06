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
  final String sourceUrl;
  final int episodes;

  Anime({
    required this.title,
    required this.imageUrl,
    required this.rating,
    required this.genres,
    required this.sourceUrl,
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

String _normalizeAnimeImageUrl(String? rawUrl, {required String fallbackTitle}) {
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
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: Colors.grey,
      ),
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
  final Anime anime;

  const AnimeDetailScreen({super.key, required this.anime});

  @override
  State<AnimeDetailScreen> createState() => _AnimeDetailScreenState();
}

class _AnimeDetailScreenState extends State<AnimeDetailScreen> {
  late Anime _anime;
  bool _isRefreshingDetail = false;

  @override
  void initState() {
    super.initState();
    _anime = widget.anime;
    _refreshAnimeDetail();
  }

  Future<void> _refreshAnimeDetail() async {
    final sourceUrl = _anime.sourceUrl.trim();
    if (sourceUrl.isEmpty) {
      return;
    }

    setState(() {
      _isRefreshingDetail = true;
    });

    try {
      final latestAnime = await detailAnime(sourceUrl);
      if (!mounted) {
        return;
      }

      setState(() {
        _anime = latestAnime;
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
    final parsedUri = Uri.tryParse(widget.videoUrl);
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
        'Video URL tidak valid, gunakan fallback video. Input: ${widget.videoUrl}',
      );
    }

    _player = Player();
    _videoController = VideoController(_player);
    _player.open(Media(videoUri.toString()), play: true);

    _durationSubscription = _player.stream.duration.listen(
      _seekToInitialPositionWhenReady,
    );
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

    final safeTarget = (target > totalDuration)
        ? totalDuration
        : target;
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

Future<List<Anime>> searchAnime(String query) async {
  late final http.Response response;

  try {
    response = await _httpGetWithRetry(
      Uri.parse(
        '$apiBaseUrl/api/nimegami/search?q=${Uri.encodeQueryComponent(query)}',
      ),
      timeout: const Duration(seconds: 45),
      maxAttempts: 2,
    );
  } on TimeoutException catch (error, stackTrace) {
    _logError('searchAnime timeout untuk query "$query"', error, stackTrace);
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
    throw Exception('Search API gagal dengan status ${response.statusCode}');
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

  final animeFutures = decoded.whereType<Map<String, dynamic>>().map((item) {
    final animeUrl = item['url']?.toString().trim() ?? '';
    print(item);
    if (animeUrl.isEmpty) {
      return Future<Anime?>.value(null);
    }

    return detailAnime(animeUrl).then<Anime?>((value) => value).catchError((
      error,
      stackTrace,
    ) {
      _logError('searchAnime skip item gagal detail url: $animeUrl', error, stackTrace);
      return null;
    });
  });

  final animeList = await Future.wait(animeFutures);
  return animeList.whereType<Anime>().toList();
}

Future<String?> animeEpisode(String rawUrl, int eps) async {
  try {
    final String encodedUrl = base64Encode(utf8.encode(rawUrl));
    final String apiUrl =
        '$apiBaseUrl/api/nimegami/media?url=$encodedUrl&eps=$eps';

    _logInfo('Requesting episode: $apiUrl');

    final response = await _httpGetWithRetry(
      Uri.parse(apiUrl),
      timeout: const Duration(seconds: 60),
      maxAttempts: 2,
    );

    if (response.statusCode == 200) {
      final dynamic decodedDynamic = jsonDecode(response.body);
      if (decodedDynamic is! Map<String, dynamic>) {
        _logInfo(
          'Error Log: Format response episode tidak valid (bukan object).',
        );
        return null;
      }

      // final urlEps = decodedDynamic['url'];
      // if (urlEps is! Map<String, dynamic>) {
      //   _logInfo('Error Log: key "url" tidak ditemukan atau bukan object.');
      //   return null;
      // }

      final bool isOk = decodedDynamic['ok'] == true;
      final String videoUrl = (decodedDynamic['url'] ?? '').toString().trim();

      if (isOk && videoUrl.isNotEmpty) {
        _logInfo('Success episode url: $videoUrl');
        return videoUrl;
      } else {
        _logInfo(
          'Error Log: API episode mengembalikan data tidak valid atau "ok" false.',
        );
        return null;
      }
    } else {
      _logInfo(
        'Error Log: Server error episode dengan status ${response.statusCode}',
      );
      return null;
    }
  } catch (error, stackTrace) {
    _logError(
      'Error Log: Terjadi kesalahan fatal saat ambil episode',
      error,
      stackTrace,
    );
    return null;
  }
}

Future<Anime> detailAnime(String url) async {
  final trimmedUrl = url.trim();
  if (trimmedUrl.isEmpty) {
    throw const FormatException('detailAnime url kosong');
  }

  _logInfo('detailAnime called with url: $trimmedUrl');

  final response = await _httpGetWithRetry(
    Uri.parse(
      '$apiBaseUrl/api/nimegami/anime?url=${toBase64(trimmedUrl)}',
    ),
    timeout: const Duration(seconds: 45),
    maxAttempts: 2,
  );
  print(response.body);
  print('$apiBaseUrl/api/nimegami/anime?url=${toBase64(trimmedUrl)}');

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

  final dynamic nameDynamic = decoded['name'];
  if (nameDynamic is! Map<String, dynamic>) {
    throw const FormatException('detailAnime field "name" tidak valid');
  }

  final rawTitle = nameDynamic['title']?.toString().trim() ?? '';
  final safeTitle = rawTitle.isEmpty ? 'Untitled Anime' : rawTitle;

  return Anime(
    title: safeTitle,
    imageUrl: _extractBestImageUrl(
      nameDynamic['images'],
      fallbackTitle: safeTitle,
    ),
    rating: (nameDynamic['score'] is num)
        ? (nameDynamic['score'] as num).toDouble()
        : 0.0,
    genres:
        (nameDynamic['genres'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map((g) => g['name']?.toString() ?? 'Unknown')
            .toList() ??
        ['Unknown'],
    synopsis: (nameDynamic['synopsis']?.toString().trim().isEmpty ?? true)
        ? 'No synopsis available'
        : nameDynamic['synopsis'].toString().trim(),
    sourceUrl: trimmedUrl,
    episodes: _parseEpisodeCount(nameDynamic['last_episode']),
  );
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
