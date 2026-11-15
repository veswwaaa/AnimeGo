import 'package:flutter/foundation.dart';

import 'package:animego/core/providers/provider_registry.dart';
import 'package:animego/core/repositories/provider_anime_repository.dart';

/// Container tunggal untuk registry provider dan repository.
///
/// Ini adalah "sesuatu" pada diagram arsitektur: satu titik yang memegang
/// semua provider dan meneruskan request ke layer di bawahnya.
class ProviderContainer {
  ProviderContainer._({required this.registry, required this.repository});

  factory ProviderContainer.create({ProviderRegistry? registry}) {
    final resolved = registry ?? appProviderRegistry;

    return ProviderContainer._(
      registry: resolved,
      repository: ProviderAnimeRepository(
        registry: resolved,
        providerOrder: resolved.ids,
      ),
    );
  }

  final ProviderRegistry registry;
  final ProviderAnimeRepository repository;

  static ProviderContainer? _instance;

  /// Instance global (lazy). Dipakai UI yang tidak punya DI container.
  static ProviderContainer get instance {
    return _instance ??= ProviderContainer.create();
  }

  /// Mengganti instance global (hanya untuk test).
  @visibleForTesting
  static set instance(ProviderContainer container) {
    _instance = container;
  }
}
