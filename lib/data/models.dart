/// Domain models. They mirror the backend in ../web:
/// Place ~ locales.Local, Loan ~ prestamos_local.LocalLoan,
/// Customer ~ the (future) global customer account.
library;

class Customer {
  const Customer({
    required this.email,
    required this.name,
    required this.carnetToken,
  });

  final String email;
  final String name;

  /// Opaque value encoded in the carnet QR. The backend must issue it
  /// (signed or rotating) — never a raw database id.
  final String carnetToken;

  String get firstName => name.trim().split(' ').first;

  String get initial => name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

  Customer copyWith({String? name}) =>
      Customer(email: email, name: name ?? this.name, carnetToken: carnetToken);

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        email: json['email'] as String,
        name: (json['full_name'] as String?) ?? '',
        carnetToken: json['carnet_token'] as String,
      );
}

class Place {
  const Place({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    required this.mapX,
    required this.mapY,
    this.distanceMeters,
    this.isOpen = true,
    this.requiresGuarantee = false,
  });

  final int id;
  final String name;
  final String category;
  final String address;

  /// Null until the backend has coordinates and we know the user's location.
  final int? distanceMeters;

  /// Normalized position (0..1) on the stylized map.
  final double mapX;
  final double mapY;
  final bool isOpen;

  /// Mirrors LocalLoanConfig.require_guarantee.
  final bool requiresGuarantee;

  /// First letter of the name, skipping symbols ("[SEED] Café" -> "S").
  String get initial {
    final match = RegExp(r'[A-Za-zÁÉÍÓÚÑáéíóúñ0-9]').firstMatch(name);
    return match == null ? '?' : match.group(0)!.toUpperCase();
  }

  String? get distanceLabel {
    final meters = distanceMeters;
    if (meters == null) return null;
    return meters < 1000 ? '$meters m' : '${(meters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  factory Place.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as int;
    return Place(
      id: id,
      name: json['name'] as String,
      category: (json['category'] as String?) ?? 'Local',
      address: (json['address'] as String?) ?? '',
      isOpen: (json['is_open'] as bool?) ?? true,
      requiresGuarantee: (json['requires_guarantee'] as bool?) ?? false,
      // Locals have no coordinates yet: spread pins deterministically by id.
      mapX: _spread(id, 1),
      mapY: _spread(id, 2),
    );
  }

  static double _spread(int id, int salt) {
    final hash = ((id + 1) * 2654435761 + salt * 40503) & 0xFFFFFFFF;
    return 0.12 + (hash / 0xFFFFFFFF) * 0.76;
  }
}

enum LoanStatus { active, overdue, returned, lost, charged }

class Loan {
  const Loan({
    required this.id,
    required this.containerType,
    required this.containerCode,
    required this.place,
    required this.returnPlaces,
    required this.createdAt,
    required this.dueDate,
    required this.status,
    this.returnedAt,
  });

  final int id;
  final String containerType;
  final String containerCode;

  /// Where the container was borrowed.
  final Place place;

  /// Where it can be returned. Today the backend only allows the lending
  /// local, but this comes from the API so it can grow (shared network,
  /// events) without app changes.
  final List<Place> returnPlaces;

  final DateTime createdAt;
  final DateTime dueDate;
  final DateTime? returnedAt;
  final LoanStatus status;

  bool get isOpen => status == LoanStatus.active || status == LoanStatus.overdue;

  int get totalDays => dueDate.difference(_dateOnly(createdAt)).inDays.clamp(1, 365);

  int daysLeft(DateTime now) => _dateOnly(dueDate).difference(_dateOnly(now)).inDays;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  factory Loan.fromJson(Map<String, dynamic> json) {
    final place = Place.fromJson(json['place'] as Map<String, dynamic>);
    final returnPlaces = (json['return_places'] as List<dynamic>? ?? const [])
        .map((e) => Place.fromJson(e as Map<String, dynamic>))
        .toList();
    final returnedAt = json['returned_at'] as String?;
    return Loan(
      id: json['id'] as int,
      containerType: json['container_type'] as String,
      containerCode: json['container_code'] as String,
      place: place,
      returnPlaces: returnPlaces,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      // Plain dates ("2026-09-20") parse as local midnight.
      dueDate: DateTime.parse(json['due_date'] as String),
      returnedAt: returnedAt == null ? null : DateTime.parse(returnedAt),
      status: LoanStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => LoanStatus.active,
      ),
    );
  }
}

/// Global switches served by the backend (app config endpoint), so they can
/// change without publishing a new app version.
class AppConfig {
  const AppConfig({required this.cardRegistrationEnabled});

  final bool cardRegistrationEnabled;

  factory AppConfig.fromJson(Map<String, dynamic> json) =>
      AppConfig(cardRegistrationEnabled: (json['card_registration_enabled'] as bool?) ?? false);
}

/// What a scanned QR turned out to be. The backend resolves the raw value,
/// so new QR kinds (events...) can be added without an app release.
sealed class ScanResult {
  const ScanResult();

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    switch (json['kind']) {
      case 'place':
        return ScannedPlace(Place.fromJson(json['place'] as Map<String, dynamic>));
      case 'container':
        final container = json['container'] as Map<String, dynamic>;
        final myLoan = container['my_loan'] as Map<String, dynamic>?;
        return ScannedContainer(
          code: container['code'] as String,
          containerType: container['container_type'] as String,
          place: Place.fromJson(container['place'] as Map<String, dynamic>),
          status: container['status'] as String,
          myLoan: myLoan == null ? null : Loan.fromJson(myLoan),
        );
      case 'customer':
        return const ScannedCustomer();
      default:
        return const ScannedUnknown();
    }
  }
}

/// QR of a local (e.g. the in-store sign).
class ScannedPlace extends ScanResult {
  const ScannedPlace(this.place);

  final Place place;
}

/// QR printed on a container.
class ScannedContainer extends ScanResult {
  const ScannedContainer({
    required this.code,
    required this.containerType,
    required this.place,
    required this.status,
    this.myLoan,
  });

  final String code;
  final String containerType;

  /// The local that owns the container.
  final Place place;

  /// available | loaned | damaged | lost | retired
  final String status;

  /// The customer's own open loan of this container, if any.
  final Loan? myLoan;

  bool get isAvailable => status == 'available';
}

/// Someone else's QR (a customer's). Only locals scan those.
class ScannedCustomer extends ScanResult {
  const ScannedCustomer();
}

class ScannedUnknown extends ScanResult {
  const ScannedUnknown();
}
