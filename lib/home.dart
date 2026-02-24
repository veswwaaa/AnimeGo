import 'dart:async';

import 'package:flutter/material.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<Homepage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  final List<Map<String, dynamic>> _banners = [
    {
      'image': 'assets/images/posterjjk.jpg',
      'title': 'Jujutsu Kaisen',
      'japaneseTitle': '呪術廻戦',
      'synopsis':
          'Yuji Itadori is a boy with tremendous physical strength, though he lives a completely ordinary...',
      'genre': ['Fantasy', 'Action', 'Supernatural'],
    },
    {
      'image': 'assets/images/gambar2.jpg',
      'title': 'Demon Slayer',
      'japaneseTitle': '呪術廻戦',
      'synopsis':
          'Ever since the death of his father, the burden of supporting the family has fallen upon Tanjirou',
      'genre': ['Action', 'Fantasy', 'Supernatural'],
    },
    {
      'image': 'assets/images/gaciakuta.jpg',
      'title': 'Gachiakuta',
      'japaneseTitle': '呪術廻戦',
      'synopsis':
          'Set in a world divided between a wealthy floating city and a surface-level slum, Gachiakuta follows Rudo, a boy who survives by scavenging "trash" that others discard.',
      'genre': ['Action', 'Comedy', 'Supernatural'],
    },
  ];

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_currentPage < _banners.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }

      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
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

            //dots
          ],
        ),
      ),
    );
  }

  //content
  Widget _buildBanner(Map<String, dynamic> data) {
    return Stack(
      children: [
        Image.asset(
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
                      data['japaneseTitle'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
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
                  style: const TextStyle(
                    color:  Colors.white,
                    fontSize: 12
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => print('Button Triggered'), 
                  icon:  Icon(Icons.play_arrow, color: Colors.white,),
                  label: Text('Watch Now',style: TextStyle(color:  Colors.white, fontSize: 12,fontWeight: FontWeight.bold) ),
                  style: ElevatedButton.styleFrom( 
                    backgroundColor: const Color.fromARGB(255, 255, 153, 0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    )
                  ),
                  ),

                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 15) ,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: List.generate(
                      _banners.length,
                      (index) => GestureDetector(
                        onTap: () => _pageController.animateToPage( 
                          index,
                          duration: Duration(milliseconds: 800),
                          curve: Curves.easeInOut
                        ),
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 300),
                          width: _currentPage == index ? 20 : 8 ,
                          height: 8,
                          margin: EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration( 
                            // shape: BoxShape.circle,
                            borderRadius: BorderRadius.circular(8),
                            color: _currentPage == index ? Color.fromARGB(255, 255, 153, 0)
                            : Colors.white
                          ),
                          
                        ),
                      )
                      )
                    ),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }
}
