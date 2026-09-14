import 'package:condevuelta/data/repository.dart';
import 'package:condevuelta/screens/qr_hub_screen.dart';
import 'package:condevuelta/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpHub(WidgetTester tester, QrHubMode mode) async {
    await tester.pumpWidget(
      AppScope(
        state: AppState(MockRepository()),
        child: MaterialApp(home: QrHubScreen(initialMode: mode)),
      ),
    );
    // The QR view animates forever: pump a fixed time instead of settling.
    await tester.pump(const Duration(milliseconds: 800));
  }

  testWidgets('mode switch: icon + label centered in each segment, pill on the selected one', (tester) async {
    await pumpHub(tester, QrHubMode.myQr);

    for (final mode in QrHubMode.values) {
      final segment = tester.getRect(find.byKey(ValueKey('mode-segment-${mode.name}')));
      final label = tester.getRect(find.byKey(ValueKey('mode-label-${mode.name}')));
      expect((label.center.dx - segment.center.dx).abs(), lessThan(0.5), reason: '${mode.name} horizontal');
      expect((label.center.dy - segment.center.dy).abs(), lessThan(0.5), reason: '${mode.name} vertical');
    }

    final pill = tester.getRect(find.byKey(const ValueKey('mode-pill')));
    final selected = tester.getRect(find.byKey(const ValueKey('mode-segment-myQr')));
    expect(pill, rectMoreOrLessEquals(selected));
  });

  testWidgets('mode switch is centered on the screen', (tester) async {
    await pumpHub(tester, QrHubMode.myQr);

    final screenWidth = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final left = tester.getRect(find.byKey(const ValueKey('mode-segment-myQr')));
    final right = tester.getRect(find.byKey(const ValueKey('mode-segment-scan')));
    expect(((left.left + right.right) / 2 - screenWidth / 2).abs(), lessThan(0.5));
  });
}
