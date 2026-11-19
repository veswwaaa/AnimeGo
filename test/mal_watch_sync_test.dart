import 'package:animego/core/auth/mal_auth_provider.dart';
import 'package:animego/core/auth/mal_gateway.dart';
import 'package:animego/core/auth/mal_models.dart';
import 'package:animego/core/auth/mal_watch_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Gateway palsu yang mencatat panggilan upsert.
class _FakeGateway implements MalGateway {
  _FakeGateway({this.loggedIn = true});

  bool loggedIn;
  final List<Map<String, dynamic>> upserts = <Map<String, dynamic>>[];
  bool throwOnUpsert = false;

  @override
  Future<void> upsert({
    required int malAnimeId,
    required int status,
    int? score,
    int? numWatchedEpisodes,
  }) async {
    if (throwOnUpsert) {
      throw const MalAuthException('gagal');
    }
    upserts.add(<String, dynamic>{
      'malAnimeId': malAnimeId,
      'status': status,
      'numWatchedEpisodes': numWatchedEpisodes,
    });
  }

  @override
  Future<MalUser> login() async => throw UnimplementedError();

  @override
  Future<MalUser> me() async => throw UnimplementedError();

  @override
  Future<List<MalListEntry>> getList({int limit = 100, int offset = 0}) async =>
      const <MalListEntry>[];

  @override
  Future<void> delete(int malAnimeId) async {}

  @override
  Future<void> logout() async {}

  @override
  Future<String?> cachedUsername() async => null;

  @override
  Future<bool> isLoggedIn() async => loggedIn;
}

MalWatchSyncService _service(
  _FakeGateway gateway,
  MalAuthProvider provider,
) {
  return MalWatchSyncService(gateway: gateway, auth: provider);
}

void main() {
  group('MalWatchSyncService', () {
    test('tidak trigger sebelum 80% durasi', () async {
      final gateway = _FakeGateway();
      final provider = MalAuthProvider(gateway: gateway);
      await provider.restore();
      final service = _service(gateway, provider);

      await service.onPlaybackProgress(
        malAnimeId: 21,
        episodeNumber: 3,
        position: const Duration(seconds: 79),
        duration: const Duration(seconds: 100),
      );

      expect(gateway.upserts, isEmpty);
    });

    test('trigger tepat pada 80% durasi dengan status watching', () async {
      final gateway = _FakeGateway();
      final provider = MalAuthProvider(gateway: gateway);
      await provider.restore();
      final service = _service(gateway, provider);

      await service.onPlaybackProgress(
        malAnimeId: 21,
        episodeNumber: 3,
        position: const Duration(seconds: 80),
        duration: const Duration(seconds: 100),
      );

      expect(gateway.upserts.length, 1);
      expect(gateway.upserts.first['malAnimeId'], 21);
      expect(gateway.upserts.first['status'], MalListStatus.watching);
      expect(gateway.upserts.first['numWatchedEpisodes'], 3);
    });

    test('hanya trigger sekali per episode', () async {
      final gateway = _FakeGateway();
      final provider = MalAuthProvider(gateway: gateway);
      await provider.restore();
      final service = _service(gateway, provider);

      for (var i = 0; i < 5; i++) {
        await service.onPlaybackProgress(
          malAnimeId: 21,
          episodeNumber: 3,
          position: const Duration(seconds: 90),
          duration: const Duration(seconds: 100),
        );
      }

      expect(gateway.upserts.length, 1);
    });

    test('tidak trigger kalau belum login MAL', () async {
      final gateway = _FakeGateway(loggedIn: false);
      final provider = MalAuthProvider(gateway: gateway);
      await provider.restore();
      final service = _service(gateway, provider);

      await service.onPlaybackProgress(
        malAnimeId: 21,
        episodeNumber: 3,
        position: const Duration(seconds: 95),
        duration: const Duration(seconds: 100),
      );

      expect(gateway.upserts, isEmpty);
    });

    test('tidak trigger kalau malId null', () async {
      final gateway = _FakeGateway();
      final provider = MalAuthProvider(gateway: gateway);
      await provider.restore();
      final service = _service(gateway, provider);

      await service.onPlaybackProgress(
        malAnimeId: null,
        episodeNumber: 3,
        position: const Duration(seconds: 95),
        duration: const Duration(seconds: 100),
      );

      expect(gateway.upserts, isEmpty);
    });

    test('error gateway tidak melempar ke pemanggil', () async {
      final gateway = _FakeGateway()..throwOnUpsert = true;
      final provider = MalAuthProvider(gateway: gateway);
      await provider.restore();
      final service = _service(gateway, provider);

      await service.onPlaybackProgress(
        malAnimeId: 21,
        episodeNumber: 3,
        position: const Duration(seconds: 95),
        duration: const Duration(seconds: 100),
      );

      expect(gateway.upserts, isEmpty);
    });
  });
}
