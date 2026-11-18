import 'package:flutter/foundation.dart';

import 'mal_gateway.dart';
import 'mal_models.dart';

/// Status UI untuk alur login MAL.
enum MalAuthStatus { unknown, loggedOut, loading, loggedIn, error }

/// State holder sederhana untuk alur login MAL.
///
/// Dipakai lewat [MalAuthScope] sehingga feature layer tidak perlu package
/// state management tambahan.
class MalAuthProvider extends ChangeNotifier {
  MalAuthProvider({required MalGateway gateway}) : _gateway = gateway;

  final MalGateway _gateway;

  MalAuthStatus _status = MalAuthStatus.unknown;
  MalUser? _user;
  String? _errorMessage;
  String? _cachedUsername;

  MalAuthStatus get status => _status;
  MalUser? get user => _user;
  String? get errorMessage => _errorMessage;
  String? get cachedUsername => _cachedUsername;
  bool get isLoggedIn => _status == MalAuthStatus.loggedIn;

  /// Cek status login saat app dibuka (restore session dari secure storage).
  Future<void> restore() async {
    _cachedUsername = await _gateway.cachedUsername();
    final loggedIn = await _gateway.isLoggedIn();
    _status = loggedIn ? MalAuthStatus.loggedIn : MalAuthStatus.loggedOut;
    notifyListeners();
  }

  /// Jalankan login MAL.
  Future<bool> login() async {
    _status = MalAuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _gateway.login();
      _user = user;
      _cachedUsername = user.username;
      _status = MalAuthStatus.loggedIn;
      notifyListeners();
      return true;
    } on MalAuthException catch (e) {
      _errorMessage = e.message;
      _status = MalAuthStatus.error;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Terjadi kesalahan tak terduga saat login MyAnimeList.';
      _status = MalAuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Logout dan hapus seluruh credential MAL.
  Future<void> logout() async {
    try {
      await _gateway.logout();
    } finally {
      _user = null;
      _cachedUsername = null;
      _status = MalAuthStatus.loggedOut;
      _errorMessage = null;
      notifyListeners();
    }
  }
}
