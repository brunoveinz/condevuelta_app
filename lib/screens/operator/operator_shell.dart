import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../state/app_state.dart';
import '../../state/operator_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_tab_bar.dart';
import 'counter_screen.dart';
import 'operator_customers_screen.dart';
import 'operator_home_screen.dart';
import 'operator_loans_screen.dart';
import 'operator_stock_screen.dart';

// Even count: the bar splits them around the raised button.
const _tabs = [
  AppTab('Inicio', Icons.storefront_outlined, Icons.storefront_rounded),
  AppTab('Envases', Icons.inventory_2_outlined, Icons.inventory_2_rounded),
  AppTab('Clientes', Icons.people_outline_rounded, Icons.people_rounded),
  AppTab('Préstamos', Icons.receipt_long_outlined, Icons.receipt_long_rounded),
];

const _loansTab = 3;

/// Operator mode: the local's home, stock, customers and loans, with the
/// counter (lend / take back by scanning) on the raised button. Profile opens
/// from the avatar.
class OperatorShell extends StatefulWidget {
  const OperatorShell({super.key});

  @override
  State<OperatorShell> createState() => _OperatorShellState();
}

class _OperatorShellState extends State<OperatorShell> {
  OperatorController? _controller;
  int _index = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final controller = _controller = OperatorController(AppScope.read(context));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.refreshHome();
      controller.reloadLoans();
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (index == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller!;
    return OperatorScope(
      controller: controller,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: AppColors.background,
          extendBody: true,
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 380),
            switchInCurve: AppMotion.emphasized,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: Tween(begin: 0.985, end: 1.0).animate(animation), child: child),
            ),
            child: KeyedSubtree(
              key: ValueKey(_index),
              child: switch (_index) {
                0 => OperatorHomeScreen(onOpenLoans: () => _select(_loansTab)),
                1 => const OperatorStockScreen(),
                2 => const OperatorCustomersScreen(),
                _ => const OperatorLoansScreen(),
              },
            ),
          ),
          // Builder: the counter needs a context below OperatorScope.
          bottomNavigationBar: Builder(
            builder: (context) => AppTabBar(
              tabs: _tabs,
              index: _index,
              onSelect: _select,
              centerLabel: 'Escanear',
              centerIcon: Icons.qr_code_scanner_rounded,
              centerSemantics: 'Prestar o recibir envases',
              onCenter: () => openCounter(context),
            ),
          ),
        ),
      ),
    );
  }
}
