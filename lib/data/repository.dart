import 'dart:math';

import 'api_client.dart';
import 'models.dart';
import 'operator_models.dart';

/// A signed-in session: the app shows the customer or the operator views.
sealed class Session {
  const Session();
}

class CustomerSession extends Session {
  const CustomerSession(this.customer, {this.isNewAccount = false, this.canReturnToOperator = false});

  final Customer customer;

  /// False for a customer who already had an account (welcome back).
  final bool isNewAccount;

  /// An operator opened their own carnet and can go back to operator mode.
  final bool canReturnToOperator;
}

class OperatorSession extends Session {
  const OperatorSession(this.profile);

  final OperatorProfile profile;
}

/// Everything the app needs from the backend. [ApiRepository] talks to ../web
/// (app clientes_app, /api/app/); [MockRepository] serves sample data.
abstract class CondevueltaRepository {
  /// The stored session, or null if there is none.
  Future<Session?> restoreSession();

  Future<AppConfig> fetchConfig();

  /// Sends a one-time login code to [email].
  Future<void> requestLoginCode(String email);

  /// Exchanges the code for a session. The backend decides whether the email
  /// belongs to a store operator or a customer.
  Future<Session> verifyLoginCode({required String email, required String code});

  Future<Customer> updateName(String name);

  Future<List<Loan>> fetchLoans();

  Future<List<Place>> fetchPlaces();

  /// Tells what a scanned QR is (a local, a container...).
  Future<ScanResult> resolveScan(String rawValue);

  /// Ends every session on this device (operator and customer).
  Future<void> signOut();

  // --- Operator mode ---------------------------------------------------------

  Future<OperatorProfile> fetchOperatorProfile();

  Future<OperatorSummary> fetchOperatorSummary();

  /// Tells what the operator scanned: a customer's carnet or a container.
  Future<OperatorScan> operatorScan(String rawValue);

  Future<LoanPage> fetchOperatorLoans({required LoanFilter filter, String query = '', int page = 1});

  Future<OperatorLoan> fetchOperatorLoan(int id);

  /// Lends [containerCodes] in one checkout. Reusing [requestId] on a retry
  /// returns the same loans instead of lending twice.
  Future<List<OperatorLoan>> lend({
    required String requestId,
    required List<String> containerCodes,
    String? carnetToken,
    GuaranteeMethod guarantee = GuaranteeMethod.none,
    String notes = '',
  });

  /// Receives a container by its scanned QR (code or URL).
  Future<ReturnResult> returnContainer(String rawValue);

  Future<OperatorLoan> returnLoan(int id);

  Future<OperatorLoan> markLoanLost(int id);

  Future<OperatorLoan> chargeGuarantee(int id);

  /// Opens the operator's own customer carnet (same email) without signing in again.
  Future<Customer> switchToCustomer();

  /// Back to the operator session kept on the device.
  Future<OperatorProfile> switchToOperator();
}

/// Random UUID v4 for retry-safe writes (no uuid package).
String newRequestId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// In-memory backend with realistic sample data, for building the UI.
class MockRepository implements CondevueltaRepository {
  static const _latency = Duration(milliseconds: 650);

  Customer? _customer;

  /// Emails that start with "operador" or "local" sign in as an operator.
  static bool _isOperatorEmail(String email) => email.startsWith('operador') || email.startsWith('local');

  final _operatorMock = _MockOperatorBackend();
  bool _operatorSignedIn = false;

  static const _places = [
    Place(
      id: 1,
      name: 'Café Raíz',
      category: 'Cafetería',
      address: 'Av. Italia 1180, Providencia',
      distanceMeters: 350,
      mapX: 0.30,
      mapY: 0.36,
    ),
    Place(
      id: 2,
      name: 'Poke Nómade',
      category: 'Poke y bowls',
      address: 'Condell 540, Providencia',
      distanceMeters: 800,
      mapX: 0.68,
      mapY: 0.24,
      requiresGuarantee: true,
    ),
    Place(
      id: 3,
      name: 'La Olla Verde',
      category: 'Comida casera',
      address: 'Irarrázaval 2210, Ñuñoa',
      distanceMeters: 1200,
      mapX: 0.56,
      mapY: 0.62,
    ),
    Place(
      id: 4,
      name: 'Sushi Norte',
      category: 'Sushi',
      address: 'Manuel Montt 95, Providencia',
      distanceMeters: 1900,
      mapX: 0.18,
      mapY: 0.70,
      isOpen: false,
    ),
    Place(
      id: 5,
      name: 'Panadería Alba',
      category: 'Panadería',
      address: 'Los Leones 310, Providencia',
      distanceMeters: 2400,
      mapX: 0.84,
      mapY: 0.52,
    ),
  ];

  @override
  Future<Session?> restoreSession() async => null;

  @override
  Future<void> signOut() async {
    _customer = null;
    _operatorSignedIn = false;
  }

  @override
  Future<AppConfig> fetchConfig() async {
    return const AppConfig(cardRegistrationEnabled: true);
  }

  @override
  Future<void> requestLoginCode(String email) => Future.delayed(_latency);

  @override
  Future<Session> verifyLoginCode({required String email, required String code}) async {
    await Future.delayed(_latency);
    if (code.length != 6) {
      throw const FormatException('El código tiene 6 dígitos.');
    }
    if (_isOperatorEmail(email)) {
      _operatorSignedIn = true;
      return OperatorSession(_operatorMock.profile(email));
    }
    final customer = _customer = Customer(
      email: email,
      name: '',
      carnetToken: 'CDV-${email.hashCode.toUnsigned(32).toRadixString(36).toUpperCase()}',
    );
    return CustomerSession(customer, isNewAccount: true);
  }

  @override
  Future<Customer> updateName(String name) async {
    await Future.delayed(_latency);
    final current = _customer;
    if (current == null) {
      throw StateError('No hay sesión activa.');
    }
    return _customer = current.copyWith(name: name.trim());
  }

  @override
  Future<List<Loan>> fetchLoans() async {
    await Future.delayed(_latency);
    final today = DateTime.now();
    DateTime day(int offset) => DateTime(today.year, today.month, today.day + offset);
    final raiz = _places[0];
    final poke = _places[1];
    final olla = _places[2];
    return [
      Loan(
        id: 101,
        containerType: 'Vaso 12 oz',
        containerCode: 'PK-0412',
        place: poke,
        returnPlaces: [poke],
        createdAt: day(-6),
        dueDate: day(1),
        status: LoanStatus.active,
      ),
      Loan(
        id: 102,
        containerType: 'Bowl mediano',
        containerCode: 'CR-1187',
        place: raiz,
        returnPlaces: [raiz],
        createdAt: day(-3),
        dueDate: day(4),
        status: LoanStatus.active,
      ),
      Loan(
        id: 90,
        containerType: 'Bowl grande',
        containerCode: 'OV-0033',
        place: olla,
        returnPlaces: [olla],
        createdAt: day(-19),
        dueDate: day(-12),
        returnedAt: day(-13),
        status: LoanStatus.returned,
      ),
      Loan(
        id: 84,
        containerType: 'Vaso 12 oz',
        containerCode: 'CR-0950',
        place: raiz,
        returnPlaces: [raiz],
        createdAt: day(-26),
        dueDate: day(-19),
        returnedAt: day(-21),
        status: LoanStatus.returned,
      ),
    ];
  }

  @override
  Future<List<Place>> fetchPlaces() async {
    await Future.delayed(_latency);
    return _places;
  }

  @override
  Future<ScanResult> resolveScan(String rawValue) async {
    await Future.delayed(_latency);
    final value = rawValue.trim().toUpperCase();
    if (value.contains('/R/')) return ScannedPlace(_places.first);
    if (value.startsWith('CDV-')) return const ScannedCustomer();
    if (RegExp(r'^[A-Z]{2}-?\d+$').hasMatch(value)) {
      return ScannedContainer(code: value, containerType: 'Bowl mediano', place: _places[1], status: 'available');
    }
    return const ScannedUnknown();
  }

  // --- Operator mode ---------------------------------------------------------

  Future<T> _operator<T>(T Function(_MockOperatorBackend backend) action) async {
    await Future.delayed(_latency);
    if (!_operatorSignedIn) throw StateError('No hay sesión de operador.');
    return action(_operatorMock);
  }

  @override
  Future<OperatorProfile> fetchOperatorProfile() => _operator((b) => b.profile(null));

  @override
  Future<OperatorSummary> fetchOperatorSummary() => _operator((b) => b.summary());

  @override
  Future<OperatorScan> operatorScan(String rawValue) => _operator((b) => b.scan(rawValue));

  @override
  Future<LoanPage> fetchOperatorLoans({required LoanFilter filter, String query = '', int page = 1}) =>
      _operator((b) => b.page(filter, query));

  @override
  Future<OperatorLoan> fetchOperatorLoan(int id) => _operator((b) => b.byId(id));

  @override
  Future<List<OperatorLoan>> lend({
    required String requestId,
    required List<String> containerCodes,
    String? carnetToken,
    GuaranteeMethod guarantee = GuaranteeMethod.none,
    String notes = '',
  }) =>
      _operator((b) => b.lend(containerCodes, carnetToken, guarantee));

  @override
  Future<ReturnResult> returnContainer(String rawValue) => _operator((b) => b.returnCode(rawValue));

  @override
  Future<OperatorLoan> returnLoan(int id) => _operator((b) => b.returnCode(b.byId(id).containerCode).loan);

  @override
  Future<OperatorLoan> markLoanLost(int id) => _operator((b) => b.update(id, status: LoanStatus.lost));

  @override
  Future<OperatorLoan> chargeGuarantee(int id) => _operator((b) => b.update(id, status: LoanStatus.charged));

  @override
  Future<Customer> switchToCustomer() async {
    await Future.delayed(_latency);
    return _customer = const Customer(email: 'operador@demo.cl', name: 'Ana Caja', carnetToken: 'CDV-DEMO0PERA');
  }

  @override
  Future<OperatorProfile> switchToOperator() => _operator((b) => b.profile(null));
}

/// In-memory local for the operator mode demo.
class _MockOperatorBackend {
  _MockOperatorBackend() {
    final today = DateTime.now();
    DateTime day(int offset) => DateTime(today.year, today.month, today.day + offset);
    _loans.addAll([
      _loan(1, 'BW-0012', 'Bowl mediano', _customers[0], day(-9), day(-2)),
      _loan(2, 'VS-0301', 'Vaso 12 oz', _customers[1], day(-6), day(1)),
      _loan(3, 'BW-0044', 'Bowl mediano', null, day(-1), day(6)),
      _loan(4, 'VS-0310', 'Vaso 12 oz', _customers[0], day(-12), day(-5), returnedAt: day(-6)),
    ]);
  }

  static const _types = {'BW': ('Bowl mediano', 3000), 'VS': ('Vaso 12 oz', 1500)};
  static const _customers = [
    LoanCustomer(id: 1, fullName: 'María Pérez', email: 'maria@correo.cl', phone: '+56 9 8765 4321'),
    LoanCustomer(id: 2, fullName: 'Tomás Rivas', email: 'tomas@correo.cl'),
  ];

  final _loans = <OperatorLoan>[];
  var _nextId = 10;

  OperatorLoan _loan(int id, String code, String type, LoanCustomer? customer, DateTime created, DateTime due,
      {DateTime? returnedAt, LoanStatus? status, GuaranteeMethod guarantee = GuaranteeMethod.none}) {
    final now = DateTime.now();
    final overdue = returnedAt == null && due.isBefore(DateTime(now.year, now.month, now.day));
    return OperatorLoan(
      id: id,
      containerCode: code,
      containerType: type,
      guaranteeValue: _types[code.substring(0, 2)]?.$2 ?? 0,
      customer: customer,
      operatorName: 'Ana Caja',
      status: status ?? (returnedAt != null ? LoanStatus.returned : (overdue ? LoanStatus.overdue : LoanStatus.active)),
      guaranteeMethod: guarantee,
      createdAt: created,
      dueDate: due,
      returnedAt: returnedAt,
      daysOverdue: overdue ? now.difference(due).inDays : 0,
      customerHasCard: customer?.id == 1,
      canChargeGuarantee: customer?.id == 1 && returnedAt == null && status == null,
    );
  }

  OperatorProfile profile(String? email) => OperatorProfile(
        fullName: 'Ana Caja',
        email: email ?? 'operador@demo.cl',
        roleTitle: 'Cajera',
        canSwitchToCustomer: true,
        local: const OperatorLocal(id: 1, name: 'Café Raíz', address: 'Av. Italia 1180, Providencia', loansEnabled: true, blocked: false),
        rules: const LoanRules(maxLoanDays: 7, maxActiveLoansPerCustomer: 3, requireGuarantee: false),
      );

  OperatorSummary summary() {
    final today = DateTime.now();
    bool isToday(DateTime? d) => d != null && d.year == today.year && d.month == today.month && d.day == today.day;
    return OperatorSummary(
      open: _loans.where((l) => l.isOpen).length,
      overdue: _loans.where((l) => l.status == LoanStatus.overdue).length,
      dueToday: _loans.where((l) => l.isOpen && isToday(l.dueDate)).length,
      lentToday: _loans.where((l) => isToday(l.createdAt)).length,
      returnedToday: _loans.where((l) => isToday(l.returnedAt)).length,
      usage: const PlanUsage(applies: true, used: 164, quota: 200, near: true, over: false, needsCard: false),
    );
  }

  OperatorScan scan(String raw) {
    final value = raw.trim().toUpperCase();
    if (value.startsWith('CDV-')) {
      final customer = _customers[value.hashCode.isEven ? 0 : 1];
      return ScannedCarnet(CarnetCustomer(
        carnetToken: value,
        fullName: customer.fullName,
        email: customer.email ?? '',
        isNewInLocal: false,
        activeLoans: _loans.where((l) => l.isOpen && l.customer?.id == customer.id).length,
        maxActiveLoans: 3,
        hasCard: customer.id == 1,
      ));
    }
    final code = value.split('/').last;
    final type = code.length >= 2 ? _types[code.substring(0, 2)] : null;
    if (type == null) return const ScannedNothing();
    final open = _loans.where((l) => l.isOpen && l.containerCode == code).firstOrNull;
    return ScannedStock(StockContainer(
      code: code,
      containerType: type.$1,
      guaranteeValue: type.$2,
      status: open == null ? 'available' : 'loaned',
      belongsToLocal: true,
      openLoan: open,
    ));
  }

  LoanPage page(LoanFilter filter, String query) {
    final q = query.trim().toLowerCase();
    final items = _loans.reversed.where((l) {
      final matches = switch (filter) {
        LoanFilter.open => l.isOpen,
        LoanFilter.overdue => l.status == LoanStatus.overdue,
        LoanFilter.returned => l.status == LoanStatus.returned,
        LoanFilter.closed => l.status == LoanStatus.lost || l.status == LoanStatus.charged,
        LoanFilter.all => true,
      };
      return matches && (q.isEmpty || '${l.containerCode} ${l.customerName}'.toLowerCase().contains(q));
    }).toList();
    return LoanPage(loans: items, count: items.length, hasMore: false);
  }

  OperatorLoan byId(int id) => _loans.firstWhere((l) => l.id == id);

  List<OperatorLoan> lend(List<String> codes, String? carnetToken, GuaranteeMethod guarantee) {
    final today = DateTime.now();
    final customer = carnetToken == null ? null : _customers[carnetToken.toUpperCase().hashCode.isEven ? 0 : 1];
    final created = [
      for (final code in codes)
        _loan(_nextId++, code, _types[code.substring(0, 2)]?.$1 ?? 'Envase', customer, today,
            DateTime(today.year, today.month, today.day + 7), guarantee: guarantee),
    ];
    _loans.addAll(created);
    return created;
  }

  ReturnResult returnCode(String raw) {
    final code = raw.trim().toUpperCase().split('/').last;
    final index = _loans.indexWhere((l) => l.isOpen && l.containerCode == code);
    if (index < 0) {
      throw const ApiException('Ese envase no tiene un préstamo abierto.', statusCode: 404, code: 'no_open_loan');
    }
    final loan = _loans[index];
    final today = DateTime.now();
    return ReturnResult(
      loan: _loans[index] = _loan(loan.id, loan.containerCode, loan.containerType, loan.customer, loan.createdAt,
          loan.dueDate, returnedAt: DateTime(today.year, today.month, today.day)),
      alreadyReturned: false,
    );
  }

  OperatorLoan update(int id, {required LoanStatus status}) {
    final index = _loans.indexWhere((l) => l.id == id);
    final loan = _loans[index];
    return _loans[index] = _loan(loan.id, loan.containerCode, loan.containerType, loan.customer, loan.createdAt,
        loan.dueDate, status: status, guarantee: loan.guaranteeMethod);
  }
}
