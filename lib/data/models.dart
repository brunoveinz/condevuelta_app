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
}

class Place {
  const Place({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    required this.distanceMeters,
    required this.mapX,
    required this.mapY,
    this.isOpen = true,
    this.requiresGuarantee = false,
  });

  final int id;
  final String name;
  final String category;
  final String address;
  final int distanceMeters;

  /// Normalized position (0..1) on the stylized map.
  final double mapX;
  final double mapY;
  final bool isOpen;

  /// Mirrors LocalLoanConfig.require_guarantee.
  final bool requiresGuarantee;

  String get distanceLabel => distanceMeters < 1000
      ? '$distanceMeters m'
      : '${(distanceMeters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
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
}

/// Global switches served by the backend (app config endpoint), so they can
/// change without publishing a new app version.
class AppConfig {
  const AppConfig({required this.cardRegistrationEnabled});

  final bool cardRegistrationEnabled;
}
