import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_tab_bar.dart';
import 'home_screen.dart';
import 'loans_screen.dart';
import 'places_screen.dart';
import 'profile_screen.dart';
import 'qr_hub_screen.dart';

const _tabs = [
  AppTab('Inicio', Icons.home_outlined, Icons.home_rounded),
  AppTab('Envases', Icons.takeout_dining_outlined, Icons.takeout_dining_rounded),
  AppTab('Locales', Icons.location_on_outlined, Icons.location_on_rounded),
  AppTab('Perfil', Icons.person_outline_rounded, Icons.person_rounded),
];

/// Signed-in home: four tabs and, in the middle of the tab bar, the raised
/// QR button (show my QR / scan a QR).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => AppScope.read(context).loadHome());
  }

  void _select(int index) {
    if (index == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        onOpenLoans: () => _select(1),
        onOpenPlaces: () => _select(2),
        onOpenProfile: () => _select(3),
      ),
      const LoansScreen(),
      const PlacesScreen(),
      const ProfileScreen(),
    ];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        extendBody: true,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 380),
          switchInCurve: AppMotion.emphasized,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween(begin: 0.985, end: 1.0).animate(animation),
              child: child,
            ),
          ),
          child: KeyedSubtree(key: ValueKey(_index), child: pages[_index]),
        ),
        bottomNavigationBar: AppTabBar(
          tabs: _tabs,
          index: _index,
          onSelect: _select,
          centerLabel: 'Mi QR',
          centerIcon: Icons.qr_code_scanner_rounded,
          centerSemantics: 'Mi QR y escanear',
          onCenter: () => openQrHub(context),
        ),
      ),
    );
  }
}
