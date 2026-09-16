import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../data/operator_models.dart';
import '../../state/operator_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_format.dart';
import '../../utils/money.dart';
import '../../widgets/pressable.dart';
import '../../widgets/primary_button.dart';
import 'operator_widgets.dart';

/// One loan: status, dates, customer, guarantee and what can still be done.
class OperatorLoanDetailScreen extends StatefulWidget {
  const OperatorLoanDetailScreen({super.key, required this.loan});

  /// Shown right away (from the list) while the full detail loads.
  final OperatorLoan loan;

  @override
  State<OperatorLoanDetailScreen> createState() => _OperatorLoanDetailScreenState();
}

enum _Action { receive, lost, charge }

class _OperatorLoanDetailScreenState extends State<OperatorLoanDetailScreen> {
  late OperatorLoan _loan = widget.loan;
  bool _loadingDetail = true;
  _Action? _running;
  bool _changed = false;
  late OperatorController _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = OperatorScope.read(context);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    if (_changed) _controller.loansChanged();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final loan = await _controller.fetchLoan(_loan.id);
      if (mounted) setState(() => _loan = loan);
    } on ApiException catch (e) {
      if (mounted) showOperatorToast(context, e.message, isError: true, bottom: 24);
    } finally {
      if (mounted) setState(() => _loadingDetail = false);
    }
  }

  Future<bool> _confirm(_Action action) => switch (action) {
    _Action.receive => Future.value(true),
    _Action.lost => confirmAction(
      context,
      icon: Icons.help_outline_rounded,
      title: '¿Marcar como perdido?',
      body: '${_loan.containerCode} sale de circulación y el préstamo se cierra. No se puede deshacer desde la app.',
      confirmLabel: 'Marcar perdido',
      destructive: true,
    ),
    _Action.charge => confirmAction(
      context,
      icon: Icons.credit_card_rounded,
      title: 'Cobrar ${formatClp(_loan.guaranteeValue)}',
      body:
          'Se cobra la garantía a la tarjeta guardada de ${_loan.customerName}. '
          'El préstamo se cierra y el envase queda para el cliente.',
      confirmLabel: 'Cobrar garantía',
    ),
  };

  Future<void> _run(_Action action) async {
    final confirmed = await _confirm(action);
    if (!confirmed || !mounted) return;

    setState(() => _running = action);
    try {
      final updated = switch (action) {
        _Action.receive => await _controller.returnLoan(_loan.id),
        _Action.lost => await _controller.markLost(_loan.id),
        _Action.charge => await _controller.chargeGuarantee(_loan.id),
      };
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      _changed = true;
      setState(() => _loan = updated);
      _controller.replaceLoan(updated);
      showOperatorToast(context, switch (action) {
        _Action.receive => 'Envase recibido',
        _Action.lost => 'Marcado como perdido',
        _Action.charge => 'Garantía cobrada',
      }, bottom: 24);
    } on ApiException catch (e) {
      if (mounted) showOperatorToast(context, e.message, isError: true, bottom: 24);
    } finally {
      if (mounted) setState(() => _running = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loan = _loan;
    final now = DateTime.now();
    final style = loanStatusStyle(loan);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
                child: Row(
                  children: [
                    Pressable(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.hairline),
                        ),
                        child: const Icon(Icons.arrow_back_rounded, color: AppColors.navy),
                      ),
                    ),
                    const Spacer(),
                    if (_loadingDetail)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.pink),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    StaggeredIn(
                      index: 0,
                      child: _Hero(loan: loan, now: now),
                    ),
                    const SizedBox(height: 12),
                    StaggeredIn(index: 1, child: _Timeline(loan: loan)),
                    const SizedBox(height: 12),
                    StaggeredIn(index: 2, child: _CustomerCard(loan: loan)),
                    const SizedBox(height: 12),
                    StaggeredIn(index: 3, child: _GuaranteeCard(loan: loan)),
                    if ((loan.notes ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      StaggeredIn(
                        index: 4,
                        child: _InfoCard(
                          icon: Icons.sticky_note_2_outlined,
                          title: 'Nota',
                          child: Text(loan.notes!.trim(), style: AppText.body.copyWith(color: AppColors.navy)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Préstamo #${loan.id}',
                        style: AppText.caption.copyWith(color: style.foreground.withValues(alpha: 0.5)),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSize(
                duration: AppMotion.medium,
                curve: AppMotion.emphasized,
                child: loan.isOpen
                    ? Container(
                        padding: EdgeInsets.fromLTRB(20, 14, 20, 12 + MediaQuery.paddingOf(context).bottom * 0),
                        decoration: const BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                          boxShadow: [BoxShadow(color: Color(0x141E264A), blurRadius: 24, offset: Offset(0, -6))],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PrimaryButton(
                              label: 'Recibir envase',
                              color: AppColors.navy,
                              isLoading: _running == _Action.receive,
                              onPressed: _running == null ? () => _run(_Action.receive) : null,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _TextAction(
                                  label: 'Marcar perdido',
                                  loading: _running == _Action.lost,
                                  onTap: _running == null ? () => _run(_Action.lost) : null,
                                ),
                                if (loan.canChargeGuarantee) ...[
                                  Container(width: 1, height: 18, color: AppColors.hairline),
                                  _TextAction(
                                    label: 'Cobrar ${formatClp(loan.guaranteeValue)}',
                                    color: AppColors.pink,
                                    loading: _running == _Action.charge,
                                    onTap: _running == null ? () => _run(_Action.charge) : null,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.loan, required this.now});

  final OperatorLoan loan;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final style = loanStatusStyle(loan);
    final overdue = loan.status == LoanStatus.overdue;
    return AnimatedContainer(
      duration: AppMotion.medium,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: overdue ? AppColors.pink : AppColors.navy,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(Icons.takeout_dining_rounded, color: AppColors.white, size: 28),
              ),
              const Spacer(),
              AnimatedSwitcher(
                duration: AppMotion.medium,
                transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                child: Container(
                  key: ValueKey(loan.status),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: style.background, borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(style.icon, size: 15, color: style.foreground),
                      const SizedBox(width: 5),
                      Text(
                        style.label,
                        style: AppText.caption.copyWith(fontWeight: FontWeight.w600, color: style.foreground),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(loan.containerType, style: AppText.title.copyWith(color: AppColors.white)),
          Text(
            loan.containerCode,
            style: AppText.label.copyWith(color: AppColors.white.withValues(alpha: 0.7), letterSpacing: 1.2),
          ),
          const SizedBox(height: 14),
          Text(
            loanWhenLabel(loan, now),
            style: AppText.headline.copyWith(color: loan.isOpen && !overdue ? AppColors.lime : AppColors.white),
          ),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.loan});

  final OperatorLoan loan;

  @override
  Widget build(BuildContext context) {
    final returnedAt = loan.returnedAt;
    final closedLabel = switch (loan.status) {
      LoanStatus.returned => 'Devuelto',
      LoanStatus.lost => 'Marcado perdido',
      LoanStatus.charged => 'Garantía cobrada',
      _ => null,
    };
    final steps = <({String label, String value, bool done, bool alert})>[
      (
        label: 'Prestado',
        value: '${formatLongDate(loan.createdAt)}${loan.operatorName.isEmpty ? '' : ' · ${loan.operatorName}'}',
        done: true,
        alert: false,
      ),
      (
        label: 'Vence',
        value: formatLongDate(loan.dueDate),
        done: !loan.isOpen,
        alert: loan.status == LoanStatus.overdue,
      ),
      (
        label: closedLabel ?? 'Devolución',
        value: returnedAt != null ? formatLongDate(returnedAt) : (closedLabel != null ? 'Cerrado' : 'Pendiente'),
        done: closedLabel != null,
        alert: loan.status == LoanStatus.lost,
      ),
    ];
    return _InfoCard(
      icon: Icons.route_rounded,
      title: 'Recorrido',
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 22,
                    child: Column(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          margin: const EdgeInsets.only(top: 3),
                          decoration: BoxDecoration(
                            color: steps[i].alert
                                ? AppColors.pink
                                : steps[i].done
                                ? AppColors.green
                                : AppColors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: steps[i].alert
                                  ? AppColors.pink
                                  : (steps[i].done ? AppColors.green : AppColors.hairline),
                              width: 2,
                            ),
                          ),
                        ),
                        if (i < steps.length - 1) Expanded(child: Container(width: 2, color: AppColors.hairline)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: i < steps.length - 1 ? 14 : 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(steps[i].label, style: AppText.label.copyWith(fontSize: 14)),
                          Text(steps[i].value, style: AppText.caption),
                        ],
                      ),
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

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.loan});

  final OperatorLoan loan;

  @override
  Widget build(BuildContext context) {
    final customer = loan.customer;
    return _InfoCard(
      icon: Icons.person_outline_rounded,
      title: 'Cliente',
      child: customer == null
          ? Text('Préstamo sin cliente: se identifica solo por el envase.', style: AppText.body)
          : Row(
              children: [
                InitialAvatar(initial: customer.initial, size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customer.fullName, style: AppText.label.copyWith(fontSize: 16)),
                      if ((customer.email ?? '').isNotEmpty) Text(customer.email!, style: AppText.caption),
                      if ((customer.phone ?? '').isNotEmpty) Text(customer.phone!, style: AppText.caption),
                    ],
                  ),
                ),
                if (loan.customerHasCard)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.credit_card_rounded, size: 14, color: AppColors.navy),
                        const SizedBox(width: 4),
                        Text(
                          'Tarjeta',
                          style: AppText.caption.copyWith(
                            fontSize: 12,
                            color: AppColors.navy,
                            fontWeight: FontWeight.w500,
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

class _GuaranteeCard extends StatelessWidget {
  const _GuaranteeCard({required this.loan});

  final OperatorLoan loan;

  @override
  Widget build(BuildContext context) {
    final payment = loan.guarantee;
    final paymentLabel = switch (payment?.status) {
      'charged' => 'Cobrada',
      'refunded' => 'Devuelta',
      'retained' => 'Retenida',
      'pending' => 'Pendiente',
      _ => null,
    };
    return _InfoCard(
      icon: Icons.shield_outlined,
      title: 'Garantía',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loan.guaranteeMethod.label, style: AppText.label.copyWith(fontSize: 16)),
                Text(
                  paymentLabel != null
                      ? '$paymentLabel · ${formatClp(payment!.amount)}'
                      : loan.guaranteeValue > 0
                      ? 'Valor del envase: ${formatClp(loan.guaranteeValue)}'
                      : 'Este envase no tiene valor de garantía.',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(13)),
            child: Icon(
              switch (loan.guaranteeMethod) {
                GuaranteeMethod.none => Icons.handshake_rounded,
                GuaranteeMethod.cash => Icons.payments_rounded,
                GuaranteeMethod.card => Icons.credit_card_rounded,
              },
              color: AppColors.pink,
              size: 21,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.title, required this.child});

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: AppColors.muted),
              const SizedBox(width: 6),
              Text(
                title.toUpperCase(),
                style: AppText.caption.copyWith(fontSize: 11.5, letterSpacing: 1, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({required this.label, required this.onTap, this.loading = false, this.color = AppColors.navy});

  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: loading
            ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: color))
            : Text(label, style: AppText.label.copyWith(color: onTap == null ? color.withValues(alpha: 0.4) : color)),
      ),
    );
  }
}
