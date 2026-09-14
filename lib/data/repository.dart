import 'models.dart';

/// Everything the app needs from the backend. The customer-facing endpoints
/// don't exist yet in ../web (see AGENTS.txt, section 6), so the app runs on
/// [MockRepository] until an ApiRepository is written against the real API.
abstract class CondevueltaRepository {
  Future<AppConfig> fetchConfig();

  /// Sends a one-time login code to [email].
  Future<void> requestLoginCode(String email);

  /// Exchanges the code for a session. Returns the customer account.
  Future<Customer> verifyLoginCode({required String email, required String code});

  Future<Customer> updateName(String name);

  Future<List<Loan>> fetchLoans();

  Future<List<Place>> fetchPlaces();
}

/// In-memory backend with realistic sample data, for building the UI.
class MockRepository implements CondevueltaRepository {
  static const _latency = Duration(milliseconds: 650);

  Customer? _customer;

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
  Future<AppConfig> fetchConfig() async {
    return const AppConfig(cardRegistrationEnabled: true);
  }

  @override
  Future<void> requestLoginCode(String email) => Future.delayed(_latency);

  @override
  Future<Customer> verifyLoginCode({required String email, required String code}) async {
    await Future.delayed(_latency);
    if (code.length != 6) {
      throw const FormatException('El código tiene 6 dígitos.');
    }
    return _customer = Customer(
      email: email,
      name: '',
      carnetToken: 'CDV-${email.hashCode.toUnsigned(32).toRadixString(36).toUpperCase()}',
    );
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
}
