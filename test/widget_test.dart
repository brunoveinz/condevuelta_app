import 'package:flutter_test/flutter_test.dart';

import 'package:condevuelta/data/repository.dart';
import 'package:condevuelta/main.dart';
import 'package:condevuelta/state/app_state.dart';

void main() {
  testWidgets('shows the tutorial on first launch', (tester) async {
    await tester.pumpWidget(CondevueltaApp(state: AppState(MockRepository())));
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('Pide tu comida en retornable'), findsOneWidget);
    expect(find.text('Siguiente'), findsOneWidget);
  });
}
