
class DataAnim {
  final String title;
  final String? japaneseTitle;
  final String synopsis;
  final String imageUrl;
  final String score;
  final String genres;
  final String sourceUrl;


  DataAnim({
    required this.title,
    this.japaneseTitle,
    required this.synopsis,
    required this.imageUrl,
    required this.score,
    required this.genres,
    required this.sourceUrl,
  });


  factory DataAnim.fromMap(Map<String, dynamic> map) {
    return DataAnim(
      title: map['title'] ?? '',
      japaneseTitle: map['japaneseTitle'] ?? '',
      synopsis: map['synopsis'] ?? '',
      imageUrl: map['images'] ? ['jpg'] ? ['image_url'] ?? '',
      score: (map['score'] ?? 0).toDouble(),
      genres: List<String>.from(map['genres'] ?? []).join(', '),
      sourceUrl: map['sourceUrl'] ?? '',
    );
  }
}