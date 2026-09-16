import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';
import 'models.dart';
import 'operator_models.dart';
import 'repository.dart';

/// [CondevueltaRepository] backed by the Django API (../web, app clientes_app).
class ApiRepository implements CondevueltaRepository {
  ApiRepository(this._client, {FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Token of the session on screen.
  static const _tokenKey = 'auth_token';

  /// 'customer' or 'operator': which views [_tokenKey] opens.
  static const _roleKey = 'auth_role';

  /// Kept while an operator uses their own customer carnet, to switch back.
  static const _operatorTokenKey = 'operator_token';

  static const _roleOperator = 'operator';
  static const _roleCustomer = 'customer';

  final ApiClient _client;

  /// Keychain (iOS) / Keystore-backed storage (Android), never plain prefs.
  final FlutterSecureStorage _storage;

  @override
  Future<Session?> restoreSession() async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null) return null;
    _client.token = token;
    final role = await _storage.read(key: _roleKey);
    try {
      if (role == _roleOperator) {
        return OperatorSession(await fetchOperatorProfile());
      }
      final customer = Customer.fromJson(await _client.get('me/') as Map<String, dynamic>);
      final operatorToken = await _storage.read(key: _operatorTokenKey);
      return CustomerSession(customer, canReturnToOperator: operatorToken != null);
    } on ApiException catch (e) {
      if (e.isUnauthorized) await _clearSession();
      // Offline: keep the token and let the user sign in again later.
      return null;
    }
  }

  @override
  Future<AppConfig> fetchConfig() async =>
      AppConfig.fromJson(await _client.get('config/') as Map<String, dynamic>);

  @override
  Future<void> requestLoginCode(String email) => _client.post('auth/request-code/', {'email': email});

  @override
  Future<Session> verifyLoginCode({required String email, required String code}) async {
    final json = await _client.post('auth/verify-code/', {'email': email, 'code': code}) as Map<String, dynamic>;
    final token = json['token'] as String;
    if (json['role'] == _roleOperator) {
      await _storeSession(token, _roleOperator);
      await _storage.write(key: _operatorTokenKey, value: token);
      return OperatorSession(OperatorProfile.fromJson(json['operator'] as Map<String, dynamic>));
    }
    await _storage.delete(key: _operatorTokenKey);
    await _storeSession(token, _roleCustomer);
    return CustomerSession(
      Customer.fromJson(json['customer'] as Map<String, dynamic>),
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
    final role = await _storage.read(key: _roleKey);
    final operatorToken = await _storage.read(key: _operatorTokenKey);
    try {
      if (_client.token != null) {
        await _client.post(role == _roleOperator ? 'operator/logout/' : 'auth/logout/');
      }
      if (operatorToken != null && operatorToken != _client.token) {
        _client.token = operatorToken;
        await _client.post('operator/logout/');
      }
    } on ApiException {
      // The local session is dropped anyway.
    }
    await _clearSession();
  }

  // --- Operator mode ---------------------------------------------------------

  @override
  Future<OperatorProfile> fetchOperatorProfile() async =>
      OperatorProfile.fromJson(await _client.get('operator/me/') as Map<String, dynamic>);

  @override
  Future<OperatorSummary> fetchOperatorSummary() async =>
      OperatorSummary.fromJson(await _client.get('operator/summary/') as Map<String, dynamic>);

  @override
  Future<OperatorScan> operatorScan(String rawValue) async =>
      OperatorScan.fromJson(await _client.post('operator/scan/', {'value': rawValue}) as Map<String, dynamic>);

  @override
  Future<LoanPage> fetchOperatorLoans({required LoanFilter filter, String query = '', int page = 1}) async {
    final json = await _client.get('operator/loans/', {
      'status': filter.name,
      if (query.trim().isNotEmpty) 'q': query.trim(),
      'page': '$page',
    });
    return LoanPage.fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<OperatorLoan> fetchOperatorLoan(int id) async => _loan(await _client.get('operator/loans/$id/'));

  @override
  Future<List<OperatorLoan>> lend({
    required String requestId,
    required List<String> containerCodes,
    String? carnetToken,
    GuaranteeMethod guarantee = GuaranteeMethod.none,
    String notes = '',
  }) async {
    final json = await _client.post('operator/loans/', {
      'request_id': requestId,
      'containers': containerCodes,
      'carnet_token': ?carnetToken,
      'payment_method': guarantee.name,
      'notes': notes.trim(),
    }) as Map<String, dynamic>;
    return (json['loans'] as List<dynamic>).map((e) => OperatorLoan.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<ReturnResult> returnContainer(String rawValue) async {
    final json = await _client.post('operator/returns/', {'code': rawValue}) as Map<String, dynamic>;
    return ReturnResult(
      loan: OperatorLoan.fromJson(json['loan'] as Map<String, dynamic>),
      alreadyReturned: (json['already_returned'] as bool?) ?? false,
    );
  }

  @override
  Future<OperatorLoan> returnLoan(int id) async => _loan(await _client.post('operator/loans/$id/return/'));

  @override
  Future<OperatorLoan> markLoanLost(int id) async => _loan(await _client.post('operator/loans/$id/mark-lost/'));

  @override
  Future<OperatorLoan> chargeGuarantee(int id) async =>
      _loan(await _client.post('operator/loans/$id/charge-guarantee/'));

  @override
  Future<Customer> switchToCustomer() async {
    final json = await _client.post('operator/switch-to-customer/') as Map<String, dynamic>;
    await _storeSession(json['token'] as String, _roleCustomer);
    return Customer.fromJson(json['customer'] as Map<String, dynamic>);
  }

  @override
  Future<OperatorProfile> switchToOperator() async {
    final operatorToken = await _storage.read(key: _operatorTokenKey);
    if (operatorToken == null) {
      throw const ApiException('Tu sesión de operador expiró. Vuelve a entrar.', statusCode: 401);
    }
    final customerToken = _client.token;
    _client.token = operatorToken;
    try {
      final profile = await fetchOperatorProfile();
      await _storeSession(operatorToken, _roleOperator);
      return profile;
    } on ApiException {
      _client.token = customerToken;
      rethrow;
    }
  }

  static OperatorLoan _loan(dynamic json) => OperatorLoan.fromJson(json as Map<String, dynamic>);

  Future<void> _storeSession(String token, String role) async {
    _client.token = token;
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _roleKey, value: role);
  }

  Future<void> _clearSession() async {
    _client.token = null;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _roleKey);
    await _storage.delete(key: _operatorTokenKey);
  }
}
