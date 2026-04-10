import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  TokenStorage._();

  static const _keyToken = 'auth_token';

  static Future<String?> getToken() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_keyToken);
  }

  static Future<void> setToken(String? token) async {
    final p = await SharedPreferences.getInstance();
    if (token == null || token.isEmpty) {
      await p.remove(_keyToken);
    } else {
      await p.setString(_keyToken, token);
    }
  }
}
