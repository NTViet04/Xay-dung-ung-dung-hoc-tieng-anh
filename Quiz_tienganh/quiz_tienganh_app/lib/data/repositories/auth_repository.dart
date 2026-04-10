import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/token_storage.dart';
import '../models/auth_user.dart';

class AuthRepository {
  AuthRepository(this._client);

  final ApiClient _client;

  Future<({String token, AuthUser user})> login({
    required String username,
    required String password,
  }) async {
    final data = await _client.post('/auth/login', {
      'username': username.trim(),
      'password': password,
    }) as Map<String, dynamic>;
    final token = data['token'] as String;
    final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
    await TokenStorage.setToken(token);
    return (token: token, user: user);
  }

  Future<({String token, AuthUser user})> register({
    required String username,
    required String password,
  }) async {
    final data = await _client.post('/auth/register', {
      'username': username.trim(),
      'password': password,
    }) as Map<String, dynamic>;
    final token = data['token'] as String;
    final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
    await TokenStorage.setToken(token);
    return (token: token, user: user);
  }

  Future<AuthUser> me() async {
    final data = await _client.get('/auth/me') as Map<String, dynamic>;
    return AuthUser.fromJson(data);
  }

  Future<void> logout() async {
    await TokenStorage.setToken(null);
  }

  Future<AuthUser?> tryRestoreSession() async {
    final t = await TokenStorage.getToken();
    if (t == null || t.isEmpty) {
      return null;
    }
    try {
      return await me();
    } on ApiException {
      await TokenStorage.setToken(null);
      return null;
    }
  }
}
