import '../dto/anime_dto.dart';
import '../dto/episode_dto.dart';
import '../dto/stream_dto.dart';

/// Kontrak untuk semua sumber data (REST atau client-side scraper).
///
/// Setiap provider wajib mengembalikan DTO dengan bentuk yang sama,
/// sehingga layer UI/Repository tidak perlu tahu asal datanya.
abstract class AnimeProvider {
  const AnimeProvider();

  /// ID unik provider, misal `otakudesu`, `nimegami`.
  String get id;

  /// Nama yang ditampilkan ke user.
  String get displayName;

  /// Tipe sumber: `scraping` (client-side) atau `rest` (backend HTTP).
  String get kind;

  bool get supportsSearch;
  bool get supportsDetail;
  bool get supportsEpisodes;
  bool get supportsStream;

  /// Apakah provider punya endpoint jadwal rilis (schedule).
  ///
  /// Default `false` supaya provider baru tidak wajib mengimplementasikan
  /// [getSchedules].
  bool get supportsSchedules => false;

  /// Mengambil jadwal rilis anime dari provider.
  ///
  /// Opsional: provider yang tidak mendukung schedule boleh tidak
  /// meng-override method ini. Implementasi default mengembalikan list kosong.
  Future<List<AnimeDto>> getSchedules() async => const <AnimeDto>[];

  Future<List<AnimeDto>> search(String query);

  Future<AnimeDto> getDetail(String sourceUrl);

  Future<List<EpisodeDto>> getEpisodes(String sourceUrl);

  Future<StreamDto> getStreamUrl(EpisodeDto episode);
}
