import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Build-time configuration, set with `--dart-define`.
///
///   flutter run                                   -> local dev backend
///   flutter run --dart-define=USE_MOCK=true       -> in-memory sample data
///   flutter run --dart-define=API_BASE_URL=https://condevuelta.cl
abstract final class Env {
  static const _apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');

  /// Run on MockRepository instead of the backend.
  static const useMockData = bool.fromEnvironment('USE_MOCK');

  /// Backend origin, without a trailing slash.
  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) return _apiBaseUrlOverride;
    if (kReleaseMode) return 'https://condevuelta.cl';
    // Android emulators reach the host machine through 10.0.2.2.
    return Platform.isAndroid ? 'http://10.0.2.2:8000' : 'http://localhost:8000';
  }
}
