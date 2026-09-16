import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'pressable.dart';

class AppTab {
  const AppTab(this.label, this.icon, this.activeIcon);

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// White bar docked to the bottom edge, friendly and calm: an even number of
/// tabs and, in the middle, a raised round action button.
class AppTabBar extends StatelessWidget {
  const AppTabBar({
    super.key,
    required this.tabs,
    required this.index,
    required this.onSelect,
    required this.centerLabel,
    required this.centerIcon,
    required this.centerSemantics,
    required this.onCenter,
    this.centerColor = AppColors.pink,
  });

  static const _barHeight = 64.0;
  static const _buttonSize = 62.0;
  static const _raise = 22.0;

  /// Even count: half on each side of the button.
  final List<AppTab> tabs;
  final int index;
  final ValueChanged<int> onSelect;
  final String centerLabel;
  final IconData centerIcon;
  final String centerSemantics;
  final VoidCallback onCenter;
  final Color centerColor;

  Widget _item(int i) => Expanded(
    child: _TabItem(tab: tabs[i], isActive: i == index, onTap: () => onSelect(i)),
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
                for (var i = 0; i < tabs.length ~/ 2; i++) _item(i),
                Expanded(
                  child: _CenterSlotLabel(label: centerLabel, color: centerColor, onTap: onCenter),
                ),
                for (var i = tabs.length ~/ 2; i < tabs.length; i++) _item(i),
              ],
            ),
          ),
          Positioned(
            top: 0,
            child: _CenterButton(
              size: _buttonSize,
              icon: centerIcon,
              color: centerColor,
              semantics: centerSemantics,
              onTap: onCenter,
            ),
          ),
        ],
      ),
    );
  }
}

/// Round button with a white ring, raised over the bar.
class _CenterButton extends StatelessWidget {
  const _CenterButton({
    required this.size,
    required this.icon,
    required this.color,
    required this.semantics,
    required this.onTap,
  });

  final double size;
  final IconData icon;
  final Color color;
  final String semantics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semantics,
      child: Pressable(
        onTap: onTap,
        scale: 0.92,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.white, width: 4),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.28), blurRadius: 14, offset: const Offset(0, 5))],
          ),
          child: Icon(icon, color: AppColors.white, size: 27),
        ),
      ),
    );
  }
}

/// Label under the raised button, lined up with the other labels.
class _CenterSlotLabel extends StatelessWidget {
  const _CenterSlotLabel({required this.label, required this.color, required this.onTap});

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        alignment: Alignment.bottomCenter,
        padding: const EdgeInsets.only(bottom: _TabItem.labelBottom),
        child: Text(label, style: _TabItem.labelStyle(color, true)),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.tab, required this.isActive, required this.onTap});

  static const labelBottom = 10.0;

  static TextStyle labelStyle(Color color, bool strong) => TextStyle(
    fontFamily: AppText.bodyFamily,
    fontSize: 11.5,
    fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
    color: color,
  );

  final AppTab tab;
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
              child: Icon(isActive ? tab.activeIcon : tab.icon, key: ValueKey(isActive), size: 25, color: color),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: AppMotion.fast,
              style: labelStyle(color, isActive),
              child: Text(tab.label),
            ),
          ],
        ),
      ),
    );
  }
}
