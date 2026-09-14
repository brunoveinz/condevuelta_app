import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';
import 'models.dart';
import 'repository.dart';

/// [CondevueltaRepository] backed by the Django API (../web, app clientes_app).
class ApiRepository implements CondevueltaRepository {
  ApiRepository(this._client, {FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'auth_token';

  final ApiClient _client;

  /// Keychain (iOS) / Keystore-backed storage (Android), never plain prefs.
  final FlutterSecureStorage _storage;

  @override
  Future<Customer?> restoreSession() async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null) return null;
    _client.token = token;
    try {
      return Customer.fromJson(await _client.get('me/') as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.isUnauthorized) await _clearToken();
      // Offline: keep the token and let the customer sign in again later.
      return null;
    }
  }

  @override
  Future<AppConfig> fetchConfig() async =>
      AppConfig.fromJson(await _client.get('config/') as Map<String, dynamic>);

  @override
  Future<void> requestLoginCode(String email) => _client.post('auth/request-code/', {'email': email});

  @override
  Future<({Customer customer, bool isNewAccount})> verifyLoginCode({required String email, required String code}) async {
    final json = await _client.post('auth/verify-code/', {'email': email, 'code': code}) as Map<String, dynamic>;
    final token = json['token'] as String;
    await _storage.write(key: _tokenKey, value: token);
    _client.token = token;
    return (
      customer: Customer.fromJson(json['customer'] as Map<String, dynamic>),
      isNewAccount: (json['is_new_account'] as bool?) ?? false,
    );
  }

  @override
  Future<Customer> updateName(String name) async =>
      Customer.fromJson(await _client.patch('me/', {'full_name': name.trim()}) as Map<String, dynamic>);

  @override
  Future<List<Loan>> fetchLoans() async {
    final json = await _client.get('loans/') as List<dynamic>;
    return json.map((e) => Loan.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<Place>> fetchPlaces() async {
    final json = await _client.get('places/') as List<dynamic>;
    return json.map((e) => Place.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<ScanResult> resolveScan(String rawValue) async =>
      ScanResult.fromJson(await _client.post('scan/', {'value': rawValue}) as Map<String, dynamic>);

  @override
  Future<void> signOut() async {
    try {
      if (_client.token != null) await _client.post('auth/logout/');
    } on ApiException {
      // The local session is dropped anyway.
    }
    await _clearToken();
  }

  Future<void> _clearToken() async {
    _client.token = null;
    await _storage.delete(key: _tokenKey);
  }
}
