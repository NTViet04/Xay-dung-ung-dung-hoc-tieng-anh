import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/models/auth_user.dart';
import '../../../data/repositories/auth_repository.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._authRepository);

  final AuthRepository _authRepository;

  bool _initializing = true;
  AuthUser? _user;
  String? _error;

  bool get isInitializing => _initializing;
  AuthUser? get user => _user;
  bool get isLoggedIn => _user != null;
  String? get lastError => _error;

  Future<void> init() async {
    _error = null;
    _initializing = true;
    notifyListeners();
    try {
      _user = await _authRepository.tryRestoreSession();
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  Future<void> login(String username, String password) async {
    _error = null;
    notifyListeners();
    try {
      final r = await _authRepository.login(username: username, password: password);
      _user = r.user;
    } on ApiException catch (e) {
      _error = e.message;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> register(String username, String password) async {
    _error = null;
    notifyListeners();
    try {
      final r =
          await _authRepository.register(username: username, password: password);
      _user = r.user;
    } on ApiException catch (e) {
      _error = e.message;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _authRepository.logout();
    _user = null;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Sau khi quiz / API cập nhật XP — gọi để đồng bộ profile.
  Future<void> refreshProfile() async {
    if (!isLoggedIn) {
      return;
    }
    try {
      _user = await _authRepository.me();
      notifyListeners();
    } catch (_) {
      /* bỏ qua */
    }
  }

  void applyUser(AuthUser u) {
    _user = u;
    notifyListeners();
  }
}
