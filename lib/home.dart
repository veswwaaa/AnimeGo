import 'dart:async';
import 'package:flutter/material.dart';
import 'services/api_sevice.dart';
import 'widgets/card.dart';
import 'models/model_anime.dart';

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

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  double _currentPageValue = 0.0;

  bool _showContent = true;

  @override
  void initState() {
    super.initState();

    
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

    _pageController.addListener(() {
      if (!mounted) return;
      final page = _pageController.page;
      if (page == null || page.isNaN || page.isInfinite) return; // <-- validasi
      setState(() {
        _currentPageValue = page;
      });
    });

    _loadDataFromApi();
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

      // sembunyikan content dulu
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
      backgroundColor: Colors.black,
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
                            PageView.builder(
                              controller: _pageController,
                              onPageChanged: (index) {
                                setState(() {
                                  _currentPage = index;
                                });
                                // _animationController.reset();
                                // _animationController.forward();
                              },
                              itemCount: _banners.length,
                              itemBuilder: (context, index) {
                                double distance = 0.0;
                                double darkness = 0.0;

                                if (!_currentPageValue.isNaN &&
                                    !_currentPageValue.isInfinite) {
                                  distance = (_currentPageValue - index).abs();
                                  darkness = distance.clamp(0.0, 1.0);
                                }

                                // content hanya muncul di banner aktif dan saat _showContent true
                                bool isActiveBanner =
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
                                          // shape: BoxShape.circle,
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

                      //Section Latest Relases
                      Padding(
                        padding: const EdgeInsets.only(top: 10, left: 20, right: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Latest Relases',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(height: 200,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: 4,
                                itemBuilder: (context, index) {
                                  final data = _banners[index];
                                  final anime = DataAnim(
                                    title: data['title'],
                                    japaneseTitle: data['japaneseTitle'],
                                    synopsis: data['synopsis'],
                                    imageUrl: data['image'],
                                    score: data['score'].toString(),
                                    genres: List<String>.from(
                                      data['genre'].toList(),
                                    ).join(', '),
                                    sourceUrl: data['sourceUrl'] ?? '',
                                  );
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: SizedBox(
                                      width: 120,
                                      child: AnimCard(anime: anime),
                                    )
                                  );
                                },
                              ),
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

  //content
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
              colors: [
                const Color.fromARGB(0, 238, 47, 47),
                Colors.black.withOpacity(0.7),
                Colors.black,
                ],
                stops: const [0.0, 0.5, 0.9],
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
                      //genre
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
