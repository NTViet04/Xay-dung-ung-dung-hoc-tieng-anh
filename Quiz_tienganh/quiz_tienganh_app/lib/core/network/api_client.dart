import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

class ApiClient {
  Future<Map<String, String>> _headers() async {
    final t = await TokenStorage.getToken();
    return {
      'Content-Type': 'application/json; charset=utf-8',
      if (t != null && t.isNotEmpty) 'Authorization': 'Bearer $t',
    };
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = ApiConfig.baseUrl;
    final p = path.startsWith('/') ? path : '/$path';
    final u = Uri.parse('$base$p');
    if (query == null || query.isEmpty) return u;
    return u.replace(queryParameters: {...u.queryParameters, ...query});
  }

  dynamic _decode(http.Response r) {
    dynamic body;
    if (r.body.isNotEmpty) {
      try {
        body = jsonDecode(utf8.decode(r.bodyBytes));
      } on FormatException {
        body = null;
      }
    }
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return body;
    }
    final msg = body is Map && body['message'] is String
        ? body['message'] as String
        : 'Lỗi HTTP ${r.statusCode}';
    throw ApiException(msg, statusCode: r.statusCode);
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final r = await http.get(_uri(path, query), headers: await _headers());
    return _decode(r);
  }

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) async {
    final r = await http.post(
      _uri(path),
      headers: await _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(r);
  }

  Future<dynamic> put(String path, [Map<String, dynamic>? body]) async {
    final r = await http.put(
      _uri(path),
      headers: await _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(r);
  }

  Future<dynamic> delete(String path) async {
    final r = await http.delete(_uri(path), headers: await _headers());
    if (r.statusCode == 204) {
      return null;
    }
    return _decode(r);
  }
}
