/// Models of the operator mode. They mirror ../web clientes_app
/// (/api/app/operator/): the operator (OperadorLocal), their local and the
/// local's loans (prestamos_local.LocalLoan).
library;

import 'models.dart';

class OperatorProfile {
  const OperatorProfile({
    required this.fullName,
    required this.email,
    required this.roleTitle,
    required this.canSwitchToCustomer,
    required this.local,
    required this.rules,
  });

  final String fullName;
  final String email;

  /// Job title as set in the web panel ("Cajera", "Administrador"...).
  final String roleTitle;

  /// The operator can open their own customer carnet with the same email.
  final bool canSwitchToCustomer;
  final OperatorLocal local;
  final LoanRules rules;

  String get firstName => fullName.trim().split(' ').first;

  String get initial => fullName.trim().isEmpty ? '?' : fullName.trim()[0].toUpperCase();

  /// Lending and returns are only possible in an active local with loans on.
  bool get canOperate => local.loansEnabled && !local.blocked;

  factory OperatorProfile.fromJson(Map<String, dynamic> json) => OperatorProfile(
    fullName: (json['full_name'] as String?)?.trim() ?? '',
    email: (json['email'] as String?) ?? '',
    roleTitle: (json['role_title'] as String?) ?? '',
    canSwitchToCustomer: (json['can_switch_to_customer'] as bool?) ?? false,
    local: OperatorLocal.fromJson(json['local'] as Map<String, dynamic>),
    rules: LoanRules.fromJson(json['loan_config'] as Map<String, dynamic>),
  );
}

class OperatorLocal {
  const OperatorLocal({
    required this.id,
    required this.name,
    required this.address,
    required this.loansEnabled,
    required this.blocked,
  });

  final int id;
  final String name;
  final String address;
  final bool loansEnabled;

  /// Manually blocked from Condevuelta's control center.
  final bool blocked;

  factory OperatorLocal.fromJson(Map<String, dynamic> json) => OperatorLocal(
    id: json['id'] as int,
    name: json['name'] as String,
    address: (json['address'] as String?) ?? '',
    loansEnabled: (json['loans_enabled'] as bool?) ?? false,
    blocked: (json['blocked'] as bool?) ?? false,
  );
}

/// The local's LocalLoanConfig.
class LoanRules {
  const LoanRules({required this.maxLoanDays, required this.maxActiveLoansPerCustomer, required this.requireGuarantee});

  final int maxLoanDays;
  final int maxActiveLoansPerCustomer;

  /// A suggestion for the operator, never a hard block.
  final bool requireGuarantee;

  factory LoanRules.fromJson(Map<String, dynamic> json) => LoanRules(
    maxLoanDays: (json['max_loan_days'] as int?) ?? 7,
    maxActiveLoansPerCustomer: (json['max_active_loans_per_customer'] as int?) ?? 3,
    requireGuarantee: (json['require_guarantee'] as bool?) ?? false,
  );
}

class OperatorSummary {
  const OperatorSummary({
    required this.open,
    required this.overdue,
    required this.dueToday,
    required this.lentToday,
    required this.returnedToday,
    required this.usage,
  });

  static const empty = OperatorSummary(
    open: 0,
    overdue: 0,
    dueToday: 0,
    lentToday: 0,
    returnedToday: 0,
    usage: PlanUsage.none,
  );

  final int open;
  final int overdue;
  final int dueToday;
  final int lentToday;
  final int returnedToday;
  final PlanUsage usage;

  factory OperatorSummary.fromJson(Map<String, dynamic> json) => OperatorSummary(
    open: json['open'] as int,
    overdue: json['overdue'] as int,
    dueToday: json['due_today'] as int,
    lentToday: json['lent_today'] as int,
    returnedToday: json['returned_today'] as int,
    usage: PlanUsage.fromJson(json['usage'] as Map<String, dynamic>),
  );
}

/// Monthly free movements of the local's SaaS plan (pay-per-use gate).
class PlanUsage {
  const PlanUsage({
    required this.applies,
    required this.used,
    required this.quota,
    required this.near,
    required this.over,
    required this.needsCard,
  });

  static const none = PlanUsage(applies: false, used: 0, quota: 0, near: false, over: false, needsCard: false);

  final bool applies;
  final int used;
  final int quota;
  final bool near;
  final bool over;

  /// Quota spent and no card on file: new loans are blocked until one is added.
  final bool needsCard;

  factory PlanUsage.fromJson(Map<String, dynamic> json) => PlanUsage(
    applies: (json['applies'] as bool?) ?? false,
    used: (json['used'] as int?) ?? 0,
    quota: (json['quota'] as int?) ?? 0,
    near: (json['near'] as bool?) ?? false,
    over: (json['over'] as bool?) ?? false,
    needsCard: (json['needs_card'] as bool?) ?? false,
  );
}

enum GuaranteeMethod {
  none('Sin garantía'),
  cash('Efectivo'),
  card('Tarjeta');

  const GuaranteeMethod(this.label);

  final String label;

  static GuaranteeMethod fromApi(String? value) =>
      GuaranteeMethod.values.firstWhere((m) => m.name == value, orElse: () => GuaranteeMethod.none);
}

class LoanCustomer {
  const LoanCustomer({required this.id, required this.fullName, this.email, this.phone});

  final int id;
  final String fullName;
  final String? email;
  final String? phone;

  String get initial => fullName.trim().isEmpty ? '?' : fullName.trim()[0].toUpperCase();

  factory LoanCustomer.fromJson(Map<String, dynamic> json) => LoanCustomer(
    id: json['id'] as int,
    fullName: (json['full_name'] as String?) ?? '',
    email: json['email'] as String?,
    phone: json['phone'] as String?,
  );
}

class GuaranteePayment {
  const GuaranteePayment({required this.method, required this.status, required this.amount});

  final String method;

  /// pending | charged | refunded | retained
  final String status;
  final int amount;

  factory GuaranteePayment.fromJson(Map<String, dynamic> json) => GuaranteePayment(
    method: json['method'] as String,
    status: json['status'] as String,
    amount: json['amount'] as int,
  );
}

/// A loan of the operator's local.
class OperatorLoan {
  const OperatorLoan({
    required this.id,
    required this.containerCode,
    required this.containerType,
    required this.guaranteeValue,
    required this.operatorName,
    required this.status,
    required this.guaranteeMethod,
    required this.createdAt,
    required this.dueDate,
    required this.daysOverdue,
    this.customer,
    this.returnedAt,
    this.notes,
    this.guarantee,
    this.customerHasCard = false,
    this.canChargeGuarantee = false,
  });

  final int id;
  final String containerCode;
  final String containerType;

  /// Guarantee of the container type, in CLP.
  final int guaranteeValue;

  /// Null = lent without a customer.
  final LoanCustomer? customer;
  final String operatorName;
  final LoanStatus status;
  final GuaranteeMethod guaranteeMethod;
  final DateTime createdAt;
  final DateTime dueDate;
  final DateTime? returnedAt;
  final int daysOverdue;
  final String? notes;
  final GuaranteePayment? guarantee;

  /// Detail only.
  final bool customerHasCard;
  final bool canChargeGuarantee;

  bool get isOpen => status == LoanStatus.active || status == LoanStatus.overdue;

  String get customerName => customer?.fullName ?? 'Sin cliente';

  int daysLeft(DateTime now) =>
      DateTime(dueDate.year, dueDate.month, dueDate.day).difference(DateTime(now.year, now.month, now.day)).inDays;

  factory OperatorLoan.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>?;
    final guarantee = json['guarantee'] as Map<String, dynamic>?;
    final returnedAt = json['returned_at'] as String?;
    return OperatorLoan(
      id: json['id'] as int,
      containerCode: json['container_code'] as String,
      containerType: json['container_type'] as String,
      guaranteeValue: (json['guarantee_value'] as int?) ?? 0,
      customer: customer == null ? null : LoanCustomer.fromJson(customer),
      operatorName: (json['operator_name'] as String?)?.trim() ?? '',
      status: LoanStatus.values.firstWhere((s) => s.name == json['status'], orElse: () => LoanStatus.active),
      guaranteeMethod: GuaranteeMethod.fromApi(json['payment_method'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      // Plain dates ("2026-09-20") parse as local midnight.
      dueDate: DateTime.parse(json['due_date'] as String),
      returnedAt: returnedAt == null ? null : DateTime.parse(returnedAt),
      daysOverdue: (json['days_overdue'] as int?) ?? 0,
      notes: json['notes'] as String?,
      guarantee: guarantee == null ? null : GuaranteePayment.fromJson(guarantee),
      customerHasCard: (json['customer_has_card'] as bool?) ?? false,
      canChargeGuarantee: (json['can_charge_guarantee'] as bool?) ?? false,
    );
  }
}

/// Filters of the loans list (the API's `status` query param).
enum LoanFilter {
  open('Abiertos'),
  overdue('Vencidos'),
  returned('Devueltos'),
  closed('Cerrados'),
  all('Todos');

  const LoanFilter(this.label);

  final String label;
}

class LoanPage {
  const LoanPage({required this.loans, required this.count, required this.hasMore});

  final List<OperatorLoan> loans;
  final int count;
  final bool hasMore;

  factory LoanPage.fromJson(Map<String, dynamic> json) => LoanPage(
    loans: (json['results'] as List<dynamic>).map((e) => OperatorLoan.fromJson(e as Map<String, dynamic>)).toList(),
    count: json['count'] as int,
    hasMore: json['next'] != null,
  );
}

/// A customer identified by their carnet, as seen from the operator's local.
class CarnetCustomer {
  const CarnetCustomer({
    required this.carnetToken,
    required this.fullName,
    required this.email,
    required this.isNewInLocal,
    required this.activeLoans,
    required this.maxActiveLoans,
    required this.hasCard,
  });

  final String carnetToken;
  final String fullName;
  final String email;

  /// First time in this local: the loan will register them.
  final bool isNewInLocal;
  final int activeLoans;
  final int maxActiveLoans;
  final bool hasCard;

  String get displayName => fullName.trim().isEmpty ? email : fullName.trim();

  String get initial => displayName.isEmpty ? '?' : displayName[0].toUpperCase();

  int get remainingLoans => (maxActiveLoans - activeLoans).clamp(0, maxActiveLoans);

  factory CarnetCustomer.fromJson(Map<String, dynamic> json) => CarnetCustomer(
    carnetToken: json['carnet_token'] as String,
    fullName: (json['full_name'] as String?) ?? '',
    email: (json['email'] as String?) ?? '',
    isNewInLocal: (json['is_new_in_local'] as bool?) ?? false,
    activeLoans: (json['active_loans'] as int?) ?? 0,
    maxActiveLoans: (json['max_active_loans'] as int?) ?? 3,
    hasCard: (json['has_card'] as bool?) ?? false,
  );
}

/// A container read by the operator's scanner.
class StockContainer {
  const StockContainer({
    required this.code,
    required this.containerType,
    required this.guaranteeValue,
    required this.status,
    required this.belongsToLocal,
    this.openLoan,
  });

  final String code;
  final String containerType;
  final int guaranteeValue;

  /// available | loaned | damaged | lost | retired
  final String status;
  final bool belongsToLocal;
  final OperatorLoan? openLoan;

  bool get isAvailable => status == 'available';

  factory StockContainer.fromJson(Map<String, dynamic> json) {
    final openLoan = json['open_loan'] as Map<String, dynamic>?;
    return StockContainer(
      code: json['code'] as String,
      containerType: json['container_type'] as String,
      guaranteeValue: (json['guarantee_value'] as int?) ?? 0,
      status: json['status'] as String,
      belongsToLocal: (json['belongs_to_local'] as bool?) ?? false,
      openLoan: openLoan == null ? null : OperatorLoan.fromJson(openLoan),
    );
  }
}

sealed class OperatorScan {
  const OperatorScan();

  factory OperatorScan.fromJson(Map<String, dynamic> json) => switch (json['kind']) {
    'customer' => ScannedCarnet(CarnetCustomer.fromJson(json['customer'] as Map<String, dynamic>)),
    'container' => ScannedStock(StockContainer.fromJson(json['container'] as Map<String, dynamic>)),
    _ => const ScannedNothing(),
  };
}

class ScannedCarnet extends OperatorScan {
  const ScannedCarnet(this.customer);

  final CarnetCustomer customer;
}

class ScannedStock extends OperatorScan {
  const ScannedStock(this.container);

  final StockContainer container;
}

class ScannedNothing extends OperatorScan {
  const ScannedNothing();
}

class ReturnResult {
  const ReturnResult({required this.loan, required this.alreadyReturned});

  final OperatorLoan loan;

  /// The container had already been received (e.g. a retried request).
  final bool alreadyReturned;
}
