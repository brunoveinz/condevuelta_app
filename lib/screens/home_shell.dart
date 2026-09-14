import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/pressable.dart';
import 'home_screen.dart';
import 'loans_screen.dart';
import 'places_screen.dart';
import 'profile_screen.dart';
import 'qr_hub_screen.dart';

class _TabSpec {
  const _TabSpec(this.label, this.icon, this.activeIcon);

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

const _tabs = [
  _TabSpec('Inicio', Icons.home_outlined, Icons.home_rounded),
  _TabSpec('Envases', Icons.takeout_dining_outlined, Icons.takeout_dining_rounded),
  _TabSpec('Locales', Icons.location_on_outlined, Icons.location_on_rounded),
  _TabSpec('Perfil', Icons.person_outline_rounded, Icons.person_rounded),
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
        bottomNavigationBar: _BottomBar(
          index: _index,
          onSelect: _select,
          onQr: () => openQrHub(context),
        ),
      ),
    );
  }
}

/// White bar docked to the bottom edge, friendly and calm; the QR button
/// sits slightly above it in the middle.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.index, required this.onSelect, required this.onQr});

  static const _barHeight = 64.0;
  static const _buttonSize = 62.0;
  static const _raise = 22.0;

  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onQr;

  Widget _item(int i) => Expanded(
        child: _TabItem(spec: _tabs[i], isActive: i == index, onTap: () => onSelect(i)),
      );

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return SizedBox(
      height: _barHeight + _raise + bottomInset,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            height: _barHeight + bottomInset,
            padding: EdgeInsets.fromLTRB(8, 0, 8, bottomInset),
            decoration: const BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              boxShadow: [BoxShadow(color: Color(0x141E264A), blurRadius: 24, offset: Offset(0, -6))],
            ),
            child: Row(
              children: [
                _item(0),
                _item(1),
                Expanded(child: _QrSlotLabel(onTap: onQr)),
                _item(2),
                _item(3),
              ],
            ),
          ),
          Positioned(top: 0, child: _QrButton(size: _buttonSize, onTap: onQr)),
        ],
      ),
    );
  }
}

/// Pink round button with a white ring, raised over the bar.
class _QrButton extends StatelessWidget {
  const _QrButton({required this.size, required this.onTap});

  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Mi QR y escanear',
      child: Pressable(
        onTap: onTap,
        scale: 0.92,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.pink,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.white, width: 4),
            boxShadow: [
              BoxShadow(color: AppColors.pink.withValues(alpha: 0.28), blurRadius: 14, offset: const Offset(0, 5)),
            ],
          ),
          child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.white, size: 27),
        ),
      ),
    );
  }
}

/// "Mi QR" label under the raised button, lined up with the other labels.
class _QrSlotLabel extends StatelessWidget {
  const _QrSlotLabel({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        alignment: Alignment.bottomCenter,
        padding: const EdgeInsets.only(bottom: _TabItem.labelBottom),
        child: Text('Mi QR', style: _TabItem.labelStyle(AppColors.pink, true)),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.spec, required this.isActive, required this.onTap});

  static const labelBottom = 10.0;

  static TextStyle labelStyle(Color color, bool strong) => TextStyle(
        fontFamily: AppText.bodyFamily,
        fontSize: 11.5,
        fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
        color: color,
      );

  final _TabSpec spec;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.pink : AppColors.muted;
    return Pressable(
      onTap: onTap,
      child: Container(
        // Transparent fill makes the whole slot tappable.
        color: Colors.transparent,
        padding: const EdgeInsets.only(bottom: labelBottom),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AnimatedSwitcher(
              duration: AppMotion.fast,
              transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
              child: Icon(
                isActive ? spec.activeIcon : spec.icon,
                key: ValueKey(isActive),
                size: 25,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: AppMotion.fast,
              style: labelStyle(color, isActive),
              child: Text(spec.label),
            ),
          ],
        ),
      ),
    );
  }
}
