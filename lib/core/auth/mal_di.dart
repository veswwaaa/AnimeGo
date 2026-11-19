import 'mal_auth_provider.dart';
import 'mal_auth_service.dart';
import 'mal_gateway.dart';
import 'mal_gateway_impl.dart';
import 'mal_watch_sync_service.dart';

/// Dependency injection sederhana untuk fitur MAL.
///
/// Dependency dapat dioverride di test lewat [overrideDependencies].
class MalDi {
  MalDi._();

  static MalGateway? _gatewayOverride;
  static MalAuthProvider? _providerOverride;

  /// Instance shared supaya seluruh featurelayer melihat sesi login yang sama.
  static MalGateway? _gatewayInstance;
  static MalAuthProvider? _providerInstance;
  static MalWatchSyncService? _watchSyncInstance;

  /// Inject dependency untuk test.
  static void overrideDependencies({
    MalGateway? gateway,
    MalAuthProvider? provider,
  }) {
    _gatewayOverride = gateway;
    _providerOverride = provider;
  }

  /// Hapus override (dipakai setelah test selesai).
  static void resetDependencies() {
    _gatewayOverride = null;
    _providerOverride = null;
    _gatewayInstance = null;
    _providerInstance = null;
    _watchSyncInstance = null;
  }

  static MalGateway gateway() {
    final override = _gatewayOverride;
    if (override != null) return override;
    return _gatewayInstance ??= MalGatewayImpl(authService: MalAuthService());
  }

  static MalAuthProvider provider() {
    final override = _providerOverride;
    if (override != null) return override;
    return _providerInstance ??= MalAuthProvider(gateway: gateway());
  }

  /// Service sinkronisasi progress tonton ke MyAnimeList.
  static MalWatchSyncService watchSyncService() {
    return _watchSyncInstance ??= MalWatchSyncService(
      gateway: gateway(),
      auth: provider(),
    );
  }
}
