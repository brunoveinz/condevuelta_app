import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// A failed API call. [message] is user-facing (Spanish).
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Thin JSON client for the customer endpoints under /api/app/.
class ApiClient {
  ApiClient({required String baseUrl, http.Client? httpClient})
      : _base = Uri.parse('$baseUrl/api/app/'),
        _http = httpClient ?? http.Client();

  static const _timeout = Duration(seconds: 15);

  final Uri _base;
  final http.Client _http;

  /// DRF token, sent as `Authorization: Token <token>` when set.
  String? token;

  Future<dynamic> get(String path) => _send('GET', path);

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) => _send('POST', path, body);

  Future<dynamic> patch(String path, Map<String, dynamic> body) => _send('PATCH', path, body);

  Future<dynamic> _send(String method, String path, [Map<String, dynamic>? body]) async {
    final request = http.Request(method, _base.resolve(path))
      ..headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Token $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      response = await http.Response.fromStream(await _http.send(request).timeout(_timeout));
    } on SocketException {
      throw const ApiException('No pudimos conectar con Condevuelta. Revisa tu conexión.');
    } on TimeoutException {
      throw const ApiException('Condevuelta está tardando en responder. Inténtalo de nuevo.');
    } on http.ClientException {
      throw const ApiException('No pudimos conectar con Condevuelta. Revisa tu conexión.');
    }

    final text = utf8.decode(response.bodyBytes);
    final decoded = text.isEmpty ? null : _tryDecode(text);
    final status = response.statusCode;
    if (status >= 200 && status < 300) return decoded;
    throw ApiException(_errorMessage(status, decoded), statusCode: status);
  }

  static dynamic _tryDecode(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }

  static String _errorMessage(int status, dynamic body) {
    switch (status) {
      case 401:
        return 'Tu sesión expiró. Vuelve a entrar.';
      case 403:
        return 'No tienes permisos para hacer esto.';
      case 429:
        return 'Demasiados intentos. Espera un momento y vuelve a probar.';
    }
    if (status >= 500) return 'Tuvimos un problema. Inténtalo de nuevo en un rato.';
    return _firstMessage(body) ?? 'Algo salió mal. Inténtalo de nuevo.';
  }

  /// DRF errors: {"detail": "..."} or {"field": ["..."]}.
  static String? _firstMessage(dynamic body) {
    if (body is String) return body;
    if (body is List && body.isNotEmpty) return _firstMessage(body.first);
    if (body is Map) {
      if (body['detail'] is String) return body['detail'] as String;
      for (final value in body.values) {
        final message = _firstMessage(value);
        if (message != null) return message;
      }
    }
    return null;
  }
}
