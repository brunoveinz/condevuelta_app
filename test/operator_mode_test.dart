import 'package:condevuelta/data/operator_models.dart';
import 'package:condevuelta/data/repository.dart';
import 'package:condevuelta/screens/operator/lend_review_sheet.dart';
import 'package:condevuelta/screens/operator/operator_shell.dart';
import 'package:condevuelta/state/app_state.dart';
import 'package:condevuelta/state/operator_state.dart';
import 'package:condevuelta/utils/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<AppState> signedInOperator() async {
    final state = AppState(MockRepository());
    await state.requestCode('operador@cafe.cl');
    await state.verifyCode('123456');
    return state;
  }

  testWidgets('an operator email opens the operator mode', (tester) async {
    await tester.runAsync(() async {
      final state = await signedInOperator();

      expect(state.stage, AppStage.operatorHome);
      expect(state.operator?.local.name, 'Café Raíz');
      expect(state.customer, isNull);
    });
  });

  testWidgets('a customer email keeps the customer flow', (tester) async {
    await tester.runAsync(() async {
      final state = AppState(MockRepository());
      await state.requestCode('maria@correo.cl');
      await state.verifyCode('123456');

      expect(state.stage, AppStage.name);
      expect(state.operator, isNull);
    });
  });

  testWidgets('operator can open their carnet and come back', (tester) async {
    await tester.runAsync(() async {
      final state = await signedInOperator();

      await state.switchToCustomer();
      expect(state.stage, AppStage.home);
      expect(state.canReturnToOperator, isTrue);

      await state.switchToOperator();
      expect(state.stage, AppStage.operatorHome);
      expect(state.canReturnToOperator, isFalse);
    });
  });

  testWidgets('operator home shows the local, the counter actions and overdue loans', (tester) async {
    late AppState state;
    await tester.runAsync(() async => state = await signedInOperator());

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(home: OperatorShell()),
      ),
    );
    // Mock latency runs on the fake clock: advance it, then let the lists rebuild.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    expect(find.text('Café Raíz'), findsOneWidget);
    expect(find.text('Prestar'), findsOneWidget);
    expect(find.text('Recibir'), findsOneWidget);
    // Overdue loans sit below the fold of the test screen.
    await tester.scrollUntilVisible(find.text('María Pérez'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Vencidos'), findsOneWidget);

    await tester.tap(find.text('Préstamos').last);
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.text('Abiertos'), findsOneWidget);
    expect(find.text('Tomás Rivas'), findsOneWidget);
  });

  testWidgets('review sheet: card needs a saved card; confirming lends', (tester) async {
    late AppState state;
    await tester.runAsync(() async => state = await signedInOperator());
    final controller = OperatorController(state);
    List<OperatorLoan>? result;

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          home: OperatorScope(
            controller: controller,
            child: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () async {
                      result = await showModalBottomSheet<List<OperatorLoan>>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => OperatorScope(
                          controller: controller,
                          child: LendReviewSheet(
                            requestId: newRequestId(),
                            customer: const CarnetCustomer(
                              carnetToken: 'CDV-ABC',
                              fullName: 'Tomás Rivas',
                              email: 'tomas@correo.cl',
                              isNewInLocal: true,
                              activeLoans: 0,
                              maxActiveLoans: 3,
                              hasCard: false,
                            ),
                            containers: const [
                              StockContainer(
                                code: 'BW-0100',
                                containerType: 'Bowl mediano',
                                guaranteeValue: 3000,
                                status: 'available',
                                belongsToLocal: true,
                              ),
                            ],
                            rules: state.operator!.rules,
                          ),
                        ),
                      );
                    },
                    child: const Text('abrir'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Revisa el préstamo'), findsOneWidget);
    expect(find.text('Sin tarjeta'), findsOneWidget);
    expect(find.text('Queda registrado en tu local con este préstamo.'), findsOneWidget);

    await tester.ensureVisible(find.text('Confirmar préstamo'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Confirmar préstamo'));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    expect(result, isNotNull);
    expect(result!.single.containerCode, 'BW-0100');
    expect(result!.single.customer, isNotNull);
  });

  test('CLP amounts use dots for thousands', () {
    expect(formatClp(0), '\$0');
    expect(formatClp(3000), '\$3.000');
    expect(formatClp(1250000), '\$1.250.000');
  });

  test('request ids are UUID v4', () {
    final id = newRequestId();
    expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(id), isTrue);
    expect(newRequestId(), isNot(id));
  });
}
