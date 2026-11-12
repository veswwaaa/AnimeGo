import 'package:flutter/material.dart';

import 'package:animego/example-demo-apk/core/utils/utils.dart';

/// Widget terpisah untuk hasil pencarian Otakudesu.
///
/// Dipisah dari [SearchScreen] supaya tampilan dan perilakunya mudah
/// diedit sendiri.
class OtakudesuSearchResults extends StatelessWidget {
  final List<Anime> results;
  final bool isLoading;
  final String? errorMessage;
  final void Function(Anime anime) onTapAnime;

  const OtakudesuSearchResults({
    super.key,
    required this.results,
    required this.isLoading,
    required this.errorMessage,
    required this.onTapAnime,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF7A00)),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Text(
          errorMessage!,
          style: const TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (results.isEmpty) {
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
      itemCount: results.length,
      itemBuilder: (context, index) {
        final anime = results[index];
        return GestureDetector(
          onTap: () => onTapAnime(anime),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          anime.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (anime.status.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            anime.status,
                            style: const TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
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