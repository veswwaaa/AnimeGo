import 'package:flutter/material.dart';
import '../../../core/utils/utils.dart';
import '../../anime-video-player-screen/presentation/anime-video-player-screen.dart';
import '../data/function.dart';

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
