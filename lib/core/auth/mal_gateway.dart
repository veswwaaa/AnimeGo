import 'mal_models.dart';

/// Kontrak tunggal untuk semua akses data MyAnimeList.
///
/// Feature layer WAJIB memakai interface ini, tidak boleh melakukan request
/// HTTP ke MAL secara langsung. Dengan begitu migrasi ke backend BFF cukup
/// menambah implementasi baru dan mengganti satu baris DI.
abstract class MalGateway {
  /// Login dan ambil profil user.
  Future<MalUser> login();

  /// Ambil profil user yang sedang login.
  Future<MalUser> me();

  /// Refresh list anime milik user.
  Future<List<MalListEntry>> getList({int limit = 100, int offset = 0});

  /// Update status/score untuk satu anime (HTTP PUT).
  Future<void> upsert({
    required int malAnimeId,
    required int status,
    int? score,
    int? numWatchedEpisodes,
  });

  /// Hapus anime dari list user (HTTP DELETE).
  Future<void> delete(int malAnimeId);

  /// Logout dan hapus token lokal.
  Future<void> logout();

  /// Username tersimpan, atau null bila belum login.
  Future<String?> cachedUsername();

  /// True bila masih ada sesi login tersimpan.
  Future<bool> isLoggedIn();
}
