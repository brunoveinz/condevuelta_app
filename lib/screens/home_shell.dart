import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/pressable.dart';
import 'carnet_screen.dart';
import 'loans_screen.dart';
import 'places_screen.dart';
import 'profile_screen.dart';

class _TabSpec {
  const _TabSpec(this.label, this.icon);

  final String label;
  final IconData icon;
}

const _tabs = [
  _TabSpec('Carnet', Icons.qr_code_2_rounded),
  _TabSpec('Envases', Icons.takeout_dining_rounded),
  _TabSpec('Locales', Icons.location_on_rounded),
  _TabSpec('Perfil', Icons.person_rounded),
];

/// Signed-in home: four tabs under a floating tab bar.
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
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      CarnetScreen(onOpenLoans: () => _select(1), onOpenProfile: () => _select(3)),
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
        bottomNavigationBar: _FloatingTabBar(index: _index, onSelect: _select),
      ),
    );
  }
}

class _FloatingTabBar extends StatelessWidget {
  const _FloatingTabBar({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 12 + MediaQuery.paddingOf(context).bottom),
      child: Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(34),
          boxShadow: const [BoxShadow(color: Color(0x401E264A), blurRadius: 30, offset: Offset(0, 14))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < _tabs.length; i++)
              _TabItem(spec: _tabs[i], isActive: i == index, onTap: () => onSelect(i)),
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.spec, required this.isActive, required this.onTap});

  final _TabSpec spec;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.medium,
        curve: AppMotion.emphasized,
        height: 48,
        padding: EdgeInsets.symmetric(horizontal: isActive ? 18 : 14),
        decoration: BoxDecoration(
          color: isActive ? AppColors.pink : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(spec.icon, size: 24, color: isActive ? AppColors.white : AppColors.white.withValues(alpha: 0.6)),
            AnimatedSize(
              duration: AppMotion.medium,
              curve: AppMotion.emphasized,
              child: isActive
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        spec.label,
                        style: const TextStyle(
                          fontFamily: AppText.bodyFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.white,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
