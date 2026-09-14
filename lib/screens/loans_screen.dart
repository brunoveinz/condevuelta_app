import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';
import '../widgets/loan_tile.dart';
import '../widgets/pressable.dart';

/// "Mis envases": open loans with where/when to return them, plus history.
class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  bool _showHistory = false;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final open = state.openLoans;
    final closed = state.closedLoans;
    final items = _showHistory ? closed : open;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 130),
        children: [
          Text('Mis envases', style: AppText.title),
          const SizedBox(height: 18),
          _Segmented(
            left: 'Activos (${open.length})',
            right: 'Historial',
            showRight: _showHistory,
            onChanged: (value) => setState(() => _showHistory = value),
          ),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: AppMotion.medium,
            switchInCurve: AppMotion.emphasized,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(begin: Offset(_showHistory ? 0.06 : -0.06, 0), end: Offset.zero).animate(animation),
                child: child,
              ),
            ),
            child: Column(
              key: ValueKey(_showHistory),
              children: [
                if (state.isLoadingHome && state.loans.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: AppColors.pink, strokeWidth: 2.6),
                  )
                else if (items.isEmpty)
                  _EmptyState(history: _showHistory)
                else
                  for (final loan in items) ...[
                    _showHistory ? _HistoryTile(loan: loan) : _OpenLoanCard(loan: loan),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.left, required this.right, required this.showRight, required this.onChanged});

  final String left;
  final String right;
  final bool showRight;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget label(String text, bool active, bool value) => Expanded(
          child: Pressable(
            onTap: () => onChanged(value),
            child: SizedBox(
              height: 44,
              child: Center(
                child: AnimatedDefaultTextStyle(
                  duration: AppMotion.fast,
                  style: AppText.label.copyWith(color: active ? AppColors.white : AppColors.navy),
                  child: Text(text),
                ),
              ),
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(26)),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: AppMotion.medium,
            curve: AppMotion.emphasized,
            alignment: showRight ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                height: 44,
                decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(22)),
              ),
            ),
          ),
          Row(children: [label(left, !showRight, false), label(right, showRight, true)]),
        ],
      ),
    );
  }
}

class _OpenLoanCard extends StatelessWidget {
  const _OpenLoanCard({required this.loan});

  final Loan loan;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final urgent = isUrgent(loan, now);
    final returnPlace = loan.returnPlaces.isEmpty ? loan.place : loan.returnPlaces.first;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: urgent ? AppColors.pinkSoft : AppColors.hairline, width: urgent ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LoanRing(loan: loan, size: 68),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(loan.containerType, style: AppText.headline),
                    const SizedBox(height: 2),
                    Text('Pedido en ${loan.place.name} · ${loan.containerCode}', style: AppText.caption),
                    const SizedBox(height: 8),
                    Text(
                      formatDaysLeft(loan.daysLeft(now)),
                      style: AppText.label.copyWith(color: urgent ? AppColors.pink : AppColors.navy),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: urgent ? AppColors.pinkMist : AppColors.background,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.place_rounded, color: urgent ? AppColors.pink : AppColors.navy, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          style: AppText.body.copyWith(color: AppColors.navy, fontSize: 15, height: 1.35),
                          children: [
                            const TextSpan(text: 'Devuélvelo en '),
                            TextSpan(text: returnPlacesLabel(loan), style: const TextStyle(fontWeight: FontWeight.w500)),
                            const TextSpan(text: ' antes del '),
                            TextSpan(text: formatLongDate(loan.dueDate), style: const TextStyle(fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(returnPlace.address, style: AppText.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.loan});

  final Loan loan;

  @override
  Widget build(BuildContext context) {
    final returned = loan.status == LoanStatus.returned;
    final when = loan.returnedAt ?? loan.dueDate;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: returned ? AppColors.green.withValues(alpha: 0.25) : AppColors.pinkMist,
              shape: BoxShape.circle,
            ),
            child: Icon(
              returned ? Icons.check_rounded : Icons.priority_high_rounded,
              color: returned ? AppColors.navy : AppColors.pink,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loan.containerType, style: AppText.label.copyWith(fontSize: 16)),
                const SizedBox(height: 2),
                Text(
                  returned
                      ? 'Devuelto el ${formatDayMonth(when)} en ${loan.place.name}'
                      : 'No devuelto · ${loan.place.name}',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.history});

  final bool history;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Image.asset('assets/images/mascota.png', width: 170),
          const SizedBox(height: 12),
          Text(history ? 'Aún no hay historial' : 'Nada pendiente', style: AppText.headline),
          const SizedBox(height: 6),
          Text(
            history
                ? 'Aquí verás los envases que ya devolviste.'
                : 'Cuando pidas un envase con tu carnet, lo verás aquí con su fecha de devolución.',
            style: AppText.body,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
