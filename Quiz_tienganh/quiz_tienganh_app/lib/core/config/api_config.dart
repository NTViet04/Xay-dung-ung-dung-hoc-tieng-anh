import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

/// Base URL API (backend Express, mặc định port 3000).
/// - Web / Windows / macOS: localhost
/// - Android emulator: 10.0.2.2
/// - iOS simulator: 127.0.0.1
class ApiConfig {
  ApiConfig._();

  static const int defaultPort = 3000;

  static String get baseUrl {
    const fromEnv = String.fromEnvironment(
      'API_BASE',
      defaultValue: '',
    );
    if (fromEnv.isNotEmpty) {
      return fromEnv.endsWith('/')
          ? fromEnv.substring(0, fromEnv.length - 1)
          : fromEnv;
    }
    if (kIsWeb) {
      return 'http://localhost:$defaultPort/api';
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:$defaultPort/api';
    }
    return 'http://127.0.0.1:$defaultPort/api';
  }
}
