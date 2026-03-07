import 'dart:async';
import 'package:flutter/material.dart';
import 'api_sevice.dart';
import 'widgets/card.dart';
import 'models/model_anime.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<Homepage>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;
  bool _isLoading = true;

  List<Map<String, dynamic>> _banners = [];
  List<DataAnim> _latestAnime = [];

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _showContent = true;

  @override
  void initState() {
    super.initState();

    initializeLatestAnime();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _loadDataFromApi();
  }

  void initializeLatestAnime() async {
    try {
      final latestAnime = await getLatestAnime();
      setState(() {
        _latestAnime = latestAnime;
      });
    } catch (e) {
      print('Error initializing latest anime: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadDataFromApi() async {
    try {
      final apiData = await ApiService.fetchData();

      if (apiData.isNotEmpty) {
        setState(() {
          for (var anime in apiData) {
            final imageUrl =
                (anime['images']?['jpg']?['large_image_url'] as String?) ?? '';
            _banners.add({
              'image': imageUrl,
              'title': anime['title'],
              'japaneseTitle': anime['japanese_title'],
              'synopsis': anime['synopsis'],
              'genre': List<String>.from(anime['genres']),
              'score': anime['score'],
              'sourceUrl': anime['sourceUrl'],
              'isFromApi': true,
            });
          }
          _isLoading = false;
        });
        _startAutoScroll();
      }
      ;
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startAutoScroll() {
    if (_banners.isEmpty) return;

    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _showContent = false;
      });

      if (_currentPage < _banners.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );

        setState(() {
          _showContent = true;
        });
        _animationController.reset();
        _animationController.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: Color.fromARGB(255, 255, 153, 0),
              ),
            )
          : _banners.isEmpty
          ? Center(
              child: Text(
                'no data available',
                style: TextStyle(color: Colors.white),
              ),
            )
          : Stack(
              children: [
                SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(
                        height: 420,
                        child: Stack(
                          children: [
                            AnimatedBuilder(
                              animation: _pageController,
                              builder: (context, child) {
                                final pageValue =
                                    _pageController.hasClients &&
                                        _pageController.position.haveDimensions
                                    ? (_pageController.page ??
                                          _currentPage.toDouble())
                                    : _currentPage.toDouble();

                                return PageView.builder(
                                  controller: _pageController,
                                  onPageChanged: (index) {
                                    setState(() {
                                      _currentPage = index;
                                    });
                                  },
                                  itemCount: _banners.length,
                                  itemBuilder: (context, index) {
                                    final distance =
                                        (pageValue - index).abs();
                                    final darkness = distance.clamp(0.0, 1.0);

                                    final isActiveBanner =
                                        index == _currentPage && _showContent;

                                    return Stack(
                                      children: [
                                        _buildBanner(
                                          _banners[index],
                                          showContent: isActiveBanner,
                                        ),

                                        Positioned.fill(
                                          child: Container(
                                            color: Colors.black.withOpacity(
                                              darkness,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            ),
                            Positioned(
                              bottom: 26,
                              left: 20,
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 15),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: List.generate(
                                    _banners.length,
                                    (index) => GestureDetector(
                                      onTap: () =>
                                          _pageController.animateToPage(
                                            index,
                                            duration: Duration(
                                              milliseconds: 800,
                                            ),
                                            curve: Curves.easeInOut,
                                          ),
                                      child: AnimatedContainer(
                                        duration: Duration(milliseconds: 300),
                                        width: _currentPage == index ? 30 : 8,
                                        height: 8,
                                        margin: EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          color: _currentPage == index
                                              ? Color.fromARGB(255, 255, 153, 0)
                                              : Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Latest Relases',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    childAspectRatio: 0.65,
                                    mainAxisSpacing: 8,
                                    crossAxisSpacing: 8,
                                  ),

                              itemCount: _latestAnime.length,
                              itemBuilder: (context, index) {
                                final data = _latestAnime[index];
                                return AnimCard(anime: data);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildBanner(Map<String, dynamic> data, {bool showContent = true}) {
    final imagePath = ((data['image'] as String?) ?? '').trim();

    return Stack(
      children: [
        Image.network(
          imagePath,
          height: 450,
          width: double.infinity,
          fit: BoxFit.cover,
          webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              height: 450,
              color: Colors.grey[900],
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color.fromARGB(255, 255, 153, 0),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 450,
              color: Colors.grey[900],
              child: const Center(
                child: Icon(Icons.broken_image, color: Colors.white, size: 50),
              ),
            );
          },
        ),
        Container(
          height: 450,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
            ),
          ),
        ),
        if (showContent)
          Positioned(
            bottom: 70,
            left: 20,
            child: Opacity(
              opacity: 1.0,
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: child,
                    ),
                  );
                },
                child: SizedBox(
                  width: 350,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        children: data['genre'].map<Widget>((genre) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              genre,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [],
                      ),
                      const SizedBox(height: 2),
                      SizedBox(
                        width: 450,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 20),
                          child: Text(
                            data['title'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),

                      Text(
                        data['japaneseTitle'] ?? '',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      SizedBox(height: 4),

                      SizedBox(
                        width: 250,
                        child: Text(
                          data['synopsis'],
                          maxLines: 2,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: () => print('Button Triggered'),
                        icon: Icon(Icons.play_arrow, color: Colors.white),
                        label: Text(
                          'Watch Now',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(
                            255,
                            255,
                            153,
                            0,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

Future<List<DataAnim>> getLatestAnime() async {
  print('Fetching latest anime from API...');
  try {
    final response = await http.get(
      Uri.parse('https://kevinapienim.vercel.app/api/nimegami/schedules'),
    );
    print('API Response Status: ${response.statusCode}');

    final decodedJson = jsonDecode(response.body);
    print('Decoded JSON Keys: ${decodedJson.keys}');
    final apiData = decodedJson['animeUpdates'] as List<dynamic>;

    List<DataAnim> latestAnime = apiData.map((data) => DataAnim(
      title: data['title'],
      synopsis: data['synopsis'],
      imageUrl: data['images']['jpg']['large_image_url'],
      score: data['score'].toString(),
      genres: data['genres'].toString(),
      sourceUrl: data['sourceUrl']
    )).toList();

    return latestAnime;
  } catch (e) {
    print('Error fetching latest anime: $e');
    return [DataAnim(title: 'Error', japaneseTitle: '', synopsis: '', imageUrl: '', score: '0.0', genres: '', sourceUrl: '')];
  }
}
