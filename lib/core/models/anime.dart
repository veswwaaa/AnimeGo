/// Model internal yang dipakai layer UI.
///
/// Sumber data sudah dinormalisasi menjadi DTO di `core/dto/`, lalu
/// dikonversi ke model ini tepat di batas UI. Field [providerId]
/// memastikan anime dari provider berbeda bisa dibedakan.
class Anime {
  final String title;
  final String imageUrl;
  final double rating;
  final List<String> genres;
  final String synopsis;
  final String status;
  String sourceUrl;
  String? detailUrl;
  int episodes;

  /// ID provider sumber data, misal `otakudesu`, `nimegami`, `zoronime`.
  String providerId;

  /// ID komposit canonical: `providerId:localId`.
  String id;

  Anime({
    required this.title,
    required this.imageUrl,
    required this.rating,
    required this.genres,
    required this.sourceUrl,
    this.detailUrl,
    required this.episodes,
    this.status = '',
    this.synopsis = 'No synopsis available',
    this.providerId = '',
    this.id = '',
  });
}
