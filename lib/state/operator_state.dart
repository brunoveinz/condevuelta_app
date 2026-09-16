import 'package:flutter/widgets.dart';

import '../data/api_client.dart';
import '../data/operator_models.dart';
import '../data/repository.dart';
import 'app_state.dart';

/// State of the operator mode: the local's counters and its loans list.
/// Lives as long as the operator shell (created there, exposed with
/// [OperatorScope]).
class OperatorController extends ChangeNotifier {
  OperatorController(this._app) : _lastProfile = _app.operator!;

  final AppState _app;

  CondevueltaRepository get _repository => _app.repository;

  /// Survives sign-out while the shell animates away.
  OperatorProfile _lastProfile;

  OperatorProfile get profile => _lastProfile = _app.operator ?? _lastProfile;

  OperatorSummary summary = OperatorSummary.empty;
  bool isLoadingSummary = false;
  bool hasLoadedSummary = false;
  String? summaryError;

  /// Overdue loans shown on the home (the first page is enough).
  List<OperatorLoan> overdueLoans = const [];

  LoanFilter filter = LoanFilter.open;
  String query = '';
  List<OperatorLoan> loans = const [];
  int loansCount = 0;
  bool isLoadingLoans = false;
  bool hasMoreLoans = false;
  String? loansError;
  int _page = 1;

  /// Increases on every list reload, so late pages of an old one are dropped.
  int _listGeneration = 0;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Refreshes profile, counters and overdue loans (home pull-to-refresh).
  Future<void> refreshHome() async {
    isLoadingSummary = true;
    summaryError = null;
    _notify();
    try {
      final results = await Future.wait([
        _repository.fetchOperatorProfile(),
        _repository.fetchOperatorSummary(),
        _repository.fetchOperatorLoans(filter: LoanFilter.overdue),
      ]);
      _app.updateOperator(results[0] as OperatorProfile);
      summary = results[1] as OperatorSummary;
      overdueLoans = (results[2] as LoanPage).loans;
      hasLoadedSummary = true;
    } on ApiException catch (e) {
      if (_handleAuth(e)) return;
      // A blocked local still reaches its profile: show that state instead of an error.
      if (e.statusCode == 403) {
        await _refreshProfileOnly();
      } else {
        summaryError = e.message;
      }
    } finally {
      isLoadingSummary = false;
      _notify();
    }
  }

  Future<void> _refreshProfileOnly() async {
    try {
      _app.updateOperator(await _repository.fetchOperatorProfile());
      hasLoadedSummary = true;
    } on ApiException catch (e) {
      summaryError = e.message;
    }
  }

  void setFilter(LoanFilter value) {
    if (value == filter) return;
    filter = value;
    reloadLoans();
  }

  void setQuery(String value) {
    if (value.trim() == query) return;
    query = value.trim();
    reloadLoans();
  }

  Future<void> reloadLoans() async {
    final generation = ++_listGeneration;
    _page = 1;
    isLoadingLoans = true;
    loansError = null;
    _notify();
    try {
      final page = await _repository.fetchOperatorLoans(filter: filter, query: query);
      if (generation != _listGeneration) return;
      loans = page.loans;
      loansCount = page.count;
      hasMoreLoans = page.hasMore;
    } on ApiException catch (e) {
      if (generation != _listGeneration || _handleAuth(e)) return;
      loansError = e.message;
    } finally {
      if (generation == _listGeneration) {
        isLoadingLoans = false;
        _notify();
      }
    }
  }

  Future<void> loadMoreLoans() async {
    if (isLoadingLoans || !hasMoreLoans) return;
    final generation = _listGeneration;
    isLoadingLoans = true;
    _notify();
    try {
      final page = await _repository.fetchOperatorLoans(filter: filter, query: query, page: _page + 1);
      if (generation != _listGeneration) return;
      _page += 1;
      loans = [...loans, ...page.loans];
      hasMoreLoans = page.hasMore;
    } on ApiException catch (e) {
      if (generation != _listGeneration || _handleAuth(e)) return;
      loansError = e.message;
    } finally {
      if (generation == _listGeneration) {
        isLoadingLoans = false;
        _notify();
      }
    }
  }

  /// A loan changed somewhere (lend, return, detail actions): refresh what shows it.
  void loansChanged() {
    refreshHome();
    reloadLoans();
  }

  /// Replaces a loan in the list after an action on its detail.
  void replaceLoan(OperatorLoan loan) {
    loans = [for (final l in loans) l.id == loan.id ? loan : l];
    _notify();
  }

  Future<OperatorScan> scan(String rawValue) => _guard(() => _repository.operatorScan(rawValue));

  Future<List<OperatorLoan>> lend({
    required String requestId,
    required List<String> containerCodes,
    String? carnetToken,
    required GuaranteeMethod guarantee,
    String notes = '',
  }) => _guard(
    () => _repository.lend(
      requestId: requestId,
      containerCodes: containerCodes,
      carnetToken: carnetToken,
      guarantee: guarantee,
      notes: notes,
    ),
  );

  Future<ReturnResult> returnContainer(String rawValue) => _guard(() => _repository.returnContainer(rawValue));

  Future<OperatorLoan> fetchLoan(int id) => _guard(() => _repository.fetchOperatorLoan(id));

  Future<OperatorLoan> returnLoan(int id) => _guard(() => _repository.returnLoan(id));

  Future<OperatorLoan> markLost(int id) => _guard(() => _repository.markLoanLost(id));

  Future<OperatorLoan> chargeGuarantee(int id) => _guard(() => _repository.chargeGuarantee(id));

  /// Runs a call; a 401 signs out, any other ApiException reaches the screen.
  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiException catch (e) {
      _handleAuth(e);
      rethrow;
    }
  }

  bool _handleAuth(ApiException e) {
    if (!e.isUnauthorized) return false;
    _app.signOut();
    return true;
  }
}

class OperatorScope extends InheritedNotifier<OperatorController> {
  const OperatorScope({super.key, required OperatorController controller, required super.child})
    : super(notifier: controller);

  static OperatorController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OperatorScope>()!.notifier!;

  static OperatorController read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<OperatorScope>()!.notifier!;
}
