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

  /// Kunci episode yang sudah pernah disinkronkan pada sesi ini.
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
  Future<void> onPlaybackProgress({
    required int? malAnimeId,
    required int episodeNumber,
    required Duration position,
    required Duration duration,
  }) async {
    if (malAnimeId == null || malAnimeId <= 0) return;
    if (episodeNumber <= 0) return;
    if (duration <= Duration.zero) return;

    final ratio = position.inMilliseconds / duration.inMilliseconds;
    if (ratio < watchThreshold) return;

    final key = '$malAnimeId:$episodeNumber';
    if (_syncedKeys.contains(key)) return;

    if (!await isAvailable) return;

    // Tandai sebelum request supaya tidak ada request paralel untuk episode
    // yang sama. Kalau request gagal, kunci dilepas agar bisa dicoba lagi.
    _syncedKeys.add(key);
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
    } catch (error) {
      _syncedKeys.remove(key);
      logDev(
        'Sinkronisasi MAL gagal (diabaikan): $error',
        prefix: 'MalWatchSync:',
      );
    }
  }
}
