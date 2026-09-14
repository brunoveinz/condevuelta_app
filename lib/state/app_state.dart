import 'package:flutter/widgets.dart';

import '../data/api_client.dart';
import '../data/models.dart';
import '../data/repository.dart';

/// Top-level stages of the app. The tutorial runs once, right after install.
enum AppStage { onboarding, email, code, name, ready, home }

/// Single source of truth for session and data. Plain ChangeNotifier to
/// avoid extra packages (state management package still to be decided).
class AppState extends ChangeNotifier {
  AppState(this._repository);

  final CondevueltaRepository _repository;

  AppStage stage = AppStage.onboarding;
  AppStage _previousStage = AppStage.onboarding;
  String email = '';
  Customer? customer;
  AppConfig config = const AppConfig(cardRegistrationEnabled: false);
  List<Loan> loans = const [];
  List<Place> places = const [];
  bool isBusy = false;
  bool isLoadingHome = false;
  String? errorMessage;

  /// True the first time the home appears after sign-up, to celebrate it.
  bool justSignedUp = false;

  /// The customer already had an account: the celebration says "welcome back".
  bool isReturning = false;

  /// Used by screens to pick the transition direction.
  bool get isGoingBack => stage.index < _previousStage.index;

  List<Loan> get openLoans => loans.where((l) => l.isOpen).toList()
    ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

  List<Loan> get closedLoans => loans.where((l) => !l.isOpen).toList()
    ..sort((a, b) => (b.returnedAt ?? b.dueDate).compareTo(a.returnedAt ?? a.dueDate));

  void _goTo(AppStage next) {
    _previousStage = stage;
    stage = next;
    errorMessage = null;
    notifyListeners();
  }

  /// Picks up a stored session while the tutorial plays.
  Future<void> restoreSession() async {
    final restored = await _repository.restoreSession();
    if (restored == null) return;
    customer = restored;
    email = restored.email;
    notifyListeners();
  }

  void finishOnboarding() => _goTo(customer == null ? AppStage.email : AppStage.home);

  void backTo(AppStage target) => _goTo(target);

  Future<void> requestCode(String value) async {
    final cleaned = value.trim().toLowerCase();
    if (!_looksLikeEmail(cleaned)) {
      errorMessage = 'Revisa tu email, parece que falta algo.';
      notifyListeners();
      return;
    }
    await _run(() async {
      await _repository.requestLoginCode(cleaned);
      email = cleaned;
      _goTo(AppStage.code);
    });
  }

  Future<void> resendCode() => _repository.requestLoginCode(email);

  Future<bool> verifyCode(String code) async {
    var ok = false;
    await _run(() async {
      final result = await _repository.verifyLoginCode(email: email, code: code);
      customer = result.customer;
      ok = true;
      isReturning = !result.isNewAccount;
      if (result.customer.name.isEmpty) {
        _goTo(AppStage.name);
      } else {
        justSignedUp = result.isNewAccount;
        _goTo(AppStage.ready);
      }
    });
    return ok;
  }

  Future<void> saveName(String name) async {
    if (name.trim().length < 2) {
      errorMessage = 'Cuéntanos tu nombre para saludarte en caja.';
      notifyListeners();
      return;
    }
    await _run(() async {
      customer = await _repository.updateName(name);
      // Finishing the profile is the sign-up moment (the backend sends the
      // welcome email here), even for an account created earlier but left
      // without a name.
      isReturning = false;
      justSignedUp = true;
      _goTo(AppStage.ready);
    });
  }

  /// Called by the welcome celebration when it finishes.
  void enterHome() => _goTo(AppStage.home);

  Future<void> loadHome() async {
    isLoadingHome = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repository.fetchLoans(),
        _repository.fetchPlaces(),
        _repository.fetchConfig(),
      ]);
      loans = results[0] as List<Loan>;
      places = results[1] as List<Place>;
      config = results[2] as AppConfig;
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        signOut();
        return;
      }
      errorMessage = e.message;
    } finally {
      isLoadingHome = false;
      notifyListeners();
    }
  }

  /// Resolves a scanned QR. Errors (ApiException) are shown by the scanner.
  Future<ScanResult> resolveScan(String rawValue) => _repository.resolveScan(rawValue);

  void acknowledgeWelcome() {
    justSignedUp = false;
    notifyListeners();
  }

  void replayTutorial() => _goTo(AppStage.onboarding);

  void signOut() {
    _repository.signOut();
    customer = null;
    email = '';
    loans = const [];
    _goTo(AppStage.email);
  }

  Future<void> _run(Future<void> Function() action) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
    } on ApiException catch (e) {
      errorMessage = e.message;
    } on FormatException catch (e) {
      errorMessage = e.message;
    } on StateError catch (e) {
      errorMessage = e.message;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  static bool _looksLikeEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
}

/// Exposes [AppState] to the widget tree and rebuilds dependents on change.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Reads the state without subscribing to changes (for callbacks).
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
