import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'pressable.dart';

/// Pink pill button with an optional trailing arrow and a loading state.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.showArrow = true,
    this.expanded = true,
    this.color = AppColors.pink,
    this.foreground = AppColors.white,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool showArrow;
  final bool expanded;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final content = AnimatedSwitcher(
      duration: AppMotion.fast,
      child: isLoading
          ? SizedBox(
              key: const ValueKey('loading'),
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.6, color: foreground),
            )
          : Row(
              key: const ValueKey('label'),
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppText.bodyFamily,
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: foreground,
                  ),
                ),
                if (showArrow) ...[
                  const SizedBox(width: 10),
                  Icon(Icons.arrow_forward_rounded, size: 20, color: foreground),
                ],
              ],
            ),
    );

    return Pressable(
      onTap: enabled ? onPressed : null,
      child: AnimatedContainer(
        duration: AppMotion.medium,
        curve: AppMotion.emphasized,
        height: 58,
        width: expanded ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 26),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled || isLoading ? color : color.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(29),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.32),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ]
              : const [],
        ),
        child: content,
      ),
    );
  }
}
