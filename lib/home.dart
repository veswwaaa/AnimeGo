import 'dart:async';
import 'package:flutter/material.dart';
import 'api_sevice.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<Homepage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;
  bool _isLoading = true;

  List<Map<String, dynamic>> _banners = [];

  @override
  void initState() {
    super.initState();
    _loadDataFromApi();
  }

  Future<void> _loadDataFromApi() async {
    try {
      final apiData = await ApiService.fetchData();

      if (apiData.isNotEmpty) {
        setState(() {
          for (var anime in apiData) {
            _banners.add({
              'image': anime['images']['jpg']['large_image_url'],
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
      if (_currentPage < _banners.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
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
            ? Center( child: Text('no data available', style: TextStyle(color: Colors.white),),)
            : Stack(
              children: [
                SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(
                        height: 450,
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() {
                              _currentPage = index;
                            });
                          },
                          itemCount: _banners.length,
                          itemBuilder: (context, index) {
                            return _buildBanner(_banners[index]);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                //dot
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
                          onTap: () => _pageController.animateToPage(
                            index,
                            duration: Duration(milliseconds: 800),
                            curve: Curves.easeInOut,
                          ),
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 300),
                            width: _currentPage == index ? 30 : 8,
                            height: 8,
                            margin: EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              // shape: BoxShape.circle,
                              borderRadius: BorderRadius.circular(8),
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
    );
  }

  //content
  Widget _buildBanner(Map<String, dynamic> data) {
    bool isFromApi = data['isFromApi'] ?? false;


    return Stack(
      children: [
        isFromApi
            ? Image.network(
                data['image'],
                height: 450,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 450,
                    color: Colors.grey[900],
                    child: Center(
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.white,
                        size: 50,
                      ),
                    ),
                  );
                },
              )
            : Image.asset(
                data['image'],
                height: 450,
                width: double.infinity,
                fit: BoxFit.cover,
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
        Container(
          height: 450,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
            ),
          ),
        ),

        Positioned(
          bottom: 70,
          left: 20,
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
                SizedBox(height: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['japaneseTitle'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  data['title'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),

                Text(
                  data['synopsis'],
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                const SizedBox(height: 12),
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
                    backgroundColor: const Color.fromARGB(255, 255, 153, 0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
