import 'package:animego/core/utils/utils.dart';

import 'mal_auth_provider.dart';
import 'mal_gateway.dart';
import 'mal_models.dart';

/// Sinkronisasi progress tonton ke list MyAnimeList.
///
/// Aturan:
/// - Baru aktif kalau user sudah login MyAnimeList (sesi MAL valid).
/// - Baru aktif kalau anime punya `malId` (backend sudah mencocokkan anime
///   yang sama di MyAnimeList).
/// - Trigger saat durasi video yang sudah diputar mencapai [watchThreshold]
///   (80%).
/// - Kirim `status=watching` dan `num_watched_episodes` sesuai episode yang
///   selesai ditonton.
/// - Idempoten per (anime, episode) agar tidak menembak rate limit MAL
///   (60 request/menit per token).
///
/// Kegagalan jaringan diam-diam diabaikan: fitur ini hanya bonus, bukan
/// alur utama, dan tidak boleh mengganggu playback.
class MalWatchSyncService {
  MalWatchSyncService({
    required MalGateway gateway,
    required MalAuthProvider auth,
  })  : _gateway = gateway,
        _auth = auth;

  final MalGateway _gateway;
  final MalAuthProvider _auth;

  /// Rasio durasi yang memicu sinkronisasi.
  static const double watchThreshold = 0.8;

  /// Kunci episode yang sedang diproses atau sudah pernah disinkronikan
  /// pada sesi ini.
  ///
  /// Dipakai sekaligus sebagai "in-flight guard": kunci ditambahkan sebelum
  /// `await` pertama supaya dua tick posisi playback yang berdekatan tidak
  /// menembak request paralel ke MAL (rate limit 60 request/menit per token).
  final Set<String> _syncedKeys = <String>{};

  /// True kalau service ini punya sesi MAL yang bisa dipakai.
  Future<bool> get isAvailable async {
    if (!_auth.isLoggedIn) return false;
    try {
      return await _gateway.isLoggedIn();
    } catch (_) {
      return false;
    }
  }

  /// Panggil setiap ada update posisi playback.
  ///
  /// Aman dipanggil sering: trigger hanya terjadi sekali per episode.
  ///
  /// Mengembalikan `true` kalau sinkronisasi untuk episode ini sudah
  /// terkirim (atau sudah pernah terkirim sebelumnya). Mengembalikan `false`
  /// kalau belum bisa dikirim, sehingga pemanggil boleh mencoba lagi di
  /// tick berikutnya.
  Future<bool> onPlaybackProgress({
    required int? malAnimeId,
    required int episodeNumber,
    required Duration position,
    required Duration duration,
  }) async {
    if (malAnimeId == null || malAnimeId <= 0) return false;
    if (episodeNumber <= 0) return false;
    if (duration <= Duration.zero) return false;

    final ratio = position.inMilliseconds / duration.inMilliseconds;
    if (ratio < watchThreshold) return false;

    final key = '$malAnimeId:$episodeNumber';
    if (_syncedKeys.contains(key)) return true;

    // Kunci ditambahkan SEBELUM `await isAvailable` supaya dua tick posisi
    // yang berdekatan tidak mengirim request paralel ke MAL (rate limit
    // 60 request/menit per token).
    _syncedKeys.add(key);

    if (!await isAvailable) {
      // Belum login / sesi tidak valid: lepaskan kunci agar bisa dicoba
      // lagi di tick berikutnya setelah user login.
      _syncedKeys.remove(key);
      return false;
    }

    try {
      await _gateway.upsert(
        malAnimeId: malAnimeId,
        status: MalListStatus.watching,
        numWatchedEpisodes: episodeNumber,
      );
      logDev(
        'Sinkronisasi MAL: anime $malAnimeId, episode $episodeNumber, status watching.',
        prefix: 'MalWatchSync:',
      );
      return true;
    } catch (error) {
      _syncedKeys.remove(key);
      logDev(
        'Sinkronisasi MAL gagal (diabaikan): $error',
        prefix: 'MalWatchSync:',
      );
      return false;
    }
  }
}
