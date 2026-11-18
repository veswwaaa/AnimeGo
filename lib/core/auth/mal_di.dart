import 'mal_auth_provider.dart';
import 'mal_auth_service.dart';
import 'mal_gateway.dart';
import 'mal_gateway_impl.dart';

/// Dependency injection sederhana untuk fitur MAL.
///
/// Dependency dapat dioverride di test lewat [overrideDependencies].
class MalDi {
  MalDi._();

  static MalGateway? _gatewayOverride;
  static MalAuthProvider? _providerOverride;

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
  }

  static MalGateway gateway() {
    return _gatewayOverride ?? MalGatewayImpl(authService: MalAuthService());
  }

  static MalAuthProvider provider() {
    return _providerOverride ?? MalAuthProvider(gateway: gateway());
  }
}
