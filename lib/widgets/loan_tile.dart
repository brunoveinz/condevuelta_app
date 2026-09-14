import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';
import 'countdown_ring.dart';
import 'pressable.dart';

/// Loans due today/tomorrow (or late) are "urgent" and turn pink.
bool isUrgent(Loan loan, DateTime now) => loan.daysLeft(now) <= 1;

Color loanAccent(Loan loan, DateTime now) => isUrgent(loan, now) ? AppColors.pink : AppColors.green;

Color loanTrack(Loan loan, DateTime now) =>
    isUrgent(loan, now) ? AppColors.pinkMist : AppColors.green.withValues(alpha: 0.25);

/// "Café Raíz" or "Café Raíz o Poke Nómade" — driven by the API, never
/// assumed to be the lending local.
String returnPlacesLabel(Loan loan) {
  final names = loan.returnPlaces.map((p) => p.name).toList();
  if (names.isEmpty) return loan.place.name;
  if (names.length == 1) return names.first;
  return '${names.sublist(0, names.length - 1).join(', ')} o ${names.last}';
}

/// Ring showing days left, used across the app.
class LoanRing extends StatelessWidget {
  const LoanRing({super.key, required this.loan, this.size = 56});

  final Loan loan;
  final double size;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final left = loan.daysLeft(now);
    return CountdownRing(
      progress: left <= 0 ? 0.02 : left / loan.totalDays,
      size: size,
      strokeWidth: size * 0.12,
      color: loanAccent(loan, now),
      trackColor: loanTrack(loan, now),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${left < 0 ? 0 : left}',
            style: AppText.headline.copyWith(fontSize: size * 0.36, height: 0.95),
          ),
          Text(left == 1 ? 'día' : 'días', style: AppText.caption.copyWith(fontSize: size * 0.17, height: 1)),
        ],
      ),
    );
  }
}

/// Compact row for the carnet screen summary.
class CompactLoanTile extends StatelessWidget {
  const CompactLoanTile({super.key, required this.loan, this.onTap});

  final Loan loan;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Row(
          children: [
            LoanRing(loan: loan, size: 52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loan.containerType, style: AppText.label.copyWith(fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(
                    'Devuélvelo en ${returnPlacesLabel(loan)}',
                    style: AppText.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _DueChip(loan: loan, now: now),
          ],
        ),
      ),
    );
  }
}

class _DueChip extends StatelessWidget {
  const _DueChip({required this.loan, required this.now});

  final Loan loan;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final urgent = isUrgent(loan, now);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: urgent ? AppColors.pinkMist : AppColors.green.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        formatDaysLeft(loan.daysLeft(now)),
        style: AppText.caption.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: urgent ? AppColors.pinkDark : AppColors.navy,
        ),
      ),
    );
  }
}
