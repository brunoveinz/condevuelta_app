import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models.dart';
import '../../data/operator_models.dart';
import '../../state/operator_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_format.dart';
import '../../widgets/pressable.dart';
import '../../widgets/primary_button.dart';

/// Look of a loan status across the operator mode.
({String label, Color background, Color foreground, IconData icon}) loanStatusStyle(OperatorLoan loan) =>
    switch (loan.status) {
      LoanStatus.active => (
        label: 'Activo',
        background: AppColors.green.withValues(alpha: 0.28),
        foreground: AppColors.navy,
        icon: Icons.schedule_rounded,
      ),
      LoanStatus.overdue => (
        label: 'Vencido',
        background: AppColors.pinkMist,
        foreground: AppColors.pinkDark,
        icon: Icons.priority_high_rounded,
      ),
      LoanStatus.returned => (
        label: 'Devuelto',
        background: AppColors.skyMist,
        foreground: AppColors.navy,
        icon: Icons.check_rounded,
      ),
      LoanStatus.lost => (
        label: 'Perdido',
        background: AppColors.hairline,
        foreground: AppColors.navy,
        icon: Icons.help_outline_rounded,
      ),
      LoanStatus.charged => (
        label: 'Garantía cobrada',
        background: AppColors.yellow,
        foreground: AppColors.navy,
        icon: Icons.payments_rounded,
      ),
    };

/// One line about when: "Vence mañana", "Venció hace 3 días", "Devuelto el 18 de septiembre".
String loanWhenLabel(OperatorLoan loan, DateTime now) {
  if (loan.isOpen) return formatDaysLeft(loan.daysLeft(now));
  final returnedAt = loan.returnedAt;
  if (loan.status == LoanStatus.returned && returnedAt != null) return 'Devuelto el ${formatDayMonth(returnedAt)}';
  return 'Prestado el ${formatDayMonth(loan.createdAt)}';
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.loan});

  final OperatorLoan loan;

  @override
  Widget build(BuildContext context) {
    final style = loanStatusStyle(loan);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: style.background, borderRadius: BorderRadius.circular(12)),
      child: Text(
        style.label,
        style: AppText.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: style.foreground),
      ),
    );
  }
}

/// Row of the loans list: status badge, container, customer and when.
class OperatorLoanTile extends StatelessWidget {
  const OperatorLoanTile({super.key, required this.loan, this.onTap});

  final OperatorLoan loan;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final style = loanStatusStyle(loan);
    final urgent = loan.isOpen && loan.daysLeft(now) <= 0;
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: urgent ? AppColors.pinkSoft : AppColors.hairline, width: urgent ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: style.background, borderRadius: BorderRadius.circular(15)),
              child: Icon(style.icon, color: style.foreground, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loan.customerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.label.copyWith(
                      fontSize: 16,
                      color: loan.customer == null ? AppColors.muted : AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${loan.containerType} · ${loan.containerCode}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusPill(loan: loan),
                const SizedBox(height: 6),
                Text(
                  loanWhenLabel(loan, now),
                  style: AppText.caption.copyWith(
                    fontSize: 12,
                    color: urgent ? AppColors.pink : AppColors.muted,
                    fontWeight: urgent ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Round avatar with an initial.
class InitialAvatar extends StatelessWidget {
  const InitialAvatar({
    super.key,
    required this.initial,
    this.size = 48,
    this.background = AppColors.pinkSoft,
    this.foreground = AppColors.pinkDark,
  });

  final String initial;
  final double size;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Text(
        initial,
        style: AppText.headline.copyWith(color: foreground, fontSize: size * 0.46),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, this.count, this.actionLabel, this.onAction});

  final String title;
  final int? count;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: AppText.headline),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
            decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(10)),
            child: Text(
              '$count',
              style: AppText.caption.copyWith(color: AppColors.white, fontWeight: FontWeight.w500),
            ),
          ),
        ],
        const Spacer(),
        if (actionLabel != null)
          Pressable(
            onTap: onAction,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(actionLabel!, style: AppText.label.copyWith(color: AppColors.pink)),
            ),
          ),
      ],
    );
  }
}

/// Fade + rise, staggered by list position.
class StaggeredIn extends StatelessWidget {
  const StaggeredIn({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + 90 * index.clamp(0, 8)),
      curve: AppMotion.emphasized,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 20 * (1 - v)), child: child),
      ),
      child: child,
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, required this.height, this.radius = 24});

  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1),
      duration: const Duration(milliseconds: 800),
      builder: (context, v, child) => Opacity(opacity: v, child: child),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.navy.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Floating navy (or pink, for errors) message above the tab bar.
void showOperatorToast(BuildContext context, String message, {bool isError = false, double bottom = 100}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_rounded, color: AppColors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(fontFamily: AppText.bodyFamily)),
          ),
        ],
      ),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError ? AppColors.pinkDark : AppColors.navy,
      margin: EdgeInsets.fromLTRB(20, 0, 20, bottom),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

/// Bottom sheet asking to confirm an action that is hard to undo.
Future<bool> confirmAction(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String body,
  required String confirmLabel,
  bool destructive = false,
}) async {
  HapticFeedback.mediumImpact();
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => Container(
      padding: EdgeInsets.fromLTRB(24, 12, 24, 20 + MediaQuery.paddingOf(sheetContext).bottom),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const SizedBox(height: 22),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: destructive ? AppColors.pinkMist : AppColors.yellow,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: destructive ? AppColors.pink : AppColors.navy, size: 28),
          ),
          const SizedBox(height: 14),
          Text(title, style: AppText.headline),
          const SizedBox(height: 8),
          Text(body, style: AppText.body),
          const SizedBox(height: 22),
          PrimaryButton(
            label: confirmLabel,
            showArrow: false,
            color: destructive ? AppColors.pink : AppColors.navy,
            onPressed: () => Navigator.of(sheetContext).pop(true),
          ),
          const SizedBox(height: 6),
          Center(
            child: Pressable(
              onTap: () => Navigator.of(sheetContext).pop(false),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text('Cancelar', style: AppText.label.copyWith(color: AppColors.muted)),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  return confirmed ?? false;
}

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 5,
        decoration: BoxDecoration(color: AppColors.hairline, borderRadius: BorderRadius.circular(3)),
      ),
    );
  }
}

/// Opens a full operator screen. Routes live above the shell, so the
/// controller is handed down again.
Future<T?> pushOperatorPage<T>(BuildContext context, Widget page) {
  final controller = OperatorScope.read(context);
  return Navigator.of(context).push(_operatorRoute<T>(OperatorScope(controller: controller, child: page)));
}

/// Fade + slight rise.
Route<T> _operatorRoute<T>(Widget page) => PageRouteBuilder<T>(
  transitionDuration: const Duration(milliseconds: 480),
  reverseTransitionDuration: const Duration(milliseconds: 340),
  pageBuilder: (_, _, _) => page,
  transitionsBuilder: (_, animation, _, child) {
    final curved = CurvedAnimation(parent: animation, curve: AppMotion.emphasized, reverseCurve: Curves.easeIn);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  },
);
