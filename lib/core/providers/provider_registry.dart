import '../dto/anime_dto.dart';
import 'anime_provider.dart';
import 'nimegami/nimegami_provider_v2.dart';
import 'otakudesu/otakudesu_provider.dart';
import 'zoronime/zoronime_provider.dart';

/// Manager/aggregator ("sesuatu" pada diagram).
///
/// Mengatur daftar provider, urutan prioritas, dan fallback berurutan ketika
/// satu provider gagal (timeout, 403, hasil kosong).
class ProviderRegistry {
  ProviderRegistry({List<AnimeProvider>? providers})
    : _providers = {
        for (final provider in providers ?? const <AnimeProvider>[])
          provider.id: provider,
      };

  final Map<String, AnimeProvider> _providers;

  List<AnimeProvider> get all => _providers.values.toList(growable: false);

  List<String> get ids => _providers.keys.toList(growable: false);

  AnimeProvider? operator [](String id) => _providers[id];

  void register(AnimeProvider provider) {
    _providers[provider.id] = provider;
  }

  /// Search berurutan dengan fallback.
  ///
  /// Provider pertama yang berhasil (dan tidak kosong) akan mengembalikan
  /// hasil. Kalau provider gagal atau kosong, lanjut ke provider berikutnya.
  Future<List<AnimeDto>> searchAll(
    String query, {
    List<String>? providerOrder,
  }) async {
    final order = providerOrder ?? ids;
    for (final id in order) {
      final provider = _providers[id];
      if (provider == null || !provider.supportsSearch) continue;
      try {
        final result = await provider.search(query);
        if (result.isNotEmpty) return result;
      } catch (_) {
        // Lanjut ke provider berikutnya.
        continue;
      }
    }
    return const <AnimeDto>[];
  }
}

/// Membangun registry default dengan semua provider yang tersedia.
///
/// Urutan default: scraping dulu (gratis, tanpa backend), lalu REST.
ProviderRegistry buildDefaultProviderRegistry() {
  return ProviderRegistry(
    providers: <AnimeProvider>[
      const OtakudesuProvider(),
      NimegamiProviderV2(),
      ZoronimeProvider(),
    ],
  );
}

/// Registry global dipakai seluruh layer UI.
final ProviderRegistry appProviderRegistry = buildDefaultProviderRegistry();
