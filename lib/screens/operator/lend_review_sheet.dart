import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/api_client.dart';
import '../../data/operator_models.dart';
import '../../state/operator_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_format.dart';
import '../../utils/money.dart';
import '../../widgets/brand.dart';
import '../../widgets/pressable.dart';
import '../../widgets/primary_button.dart';
import 'operator_widgets.dart';

/// Last step of a loan: who, which containers, the guarantee and confirm.
/// Pops with the created loans.
class LendReviewSheet extends StatefulWidget {
  const LendReviewSheet({
    super.key,
    required this.requestId,
    required this.customer,
    required this.containers,
    required this.rules,
  });

  final String requestId;
  final CarnetCustomer? customer;
  final List<StockContainer> containers;
  final LoanRules rules;

  @override
  State<LendReviewSheet> createState() => _LendReviewSheetState();
}

class _LendReviewSheetState extends State<LendReviewSheet> {
  late GuaranteeMethod _guarantee = _defaultGuarantee();
  final _notes = TextEditingController();
  bool _showNotes = false;
  bool _sending = false;
  String? _error;

  bool get _cardAvailable => widget.customer?.hasCard ?? false;

  int get _guaranteeTotal => widget.containers.fold(0, (sum, c) => sum + c.guaranteeValue);

  /// The local's setting is a suggestion: preselect a guarantee, never force it.
  GuaranteeMethod _defaultGuarantee() {
    if (!widget.rules.requireGuarantee) return GuaranteeMethod.none;
    return (widget.customer?.hasCard ?? false) ? GuaranteeMethod.card : GuaranteeMethod.cash;
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final loans = await OperatorScope.read(context).lend(
        requestId: widget.requestId,
        containerCodes: [for (final c in widget.containers) c.code],
        carnetToken: widget.customer?.carnetToken,
        guarantee: _guarantee,
        notes: _notes.text,
      );
      if (mounted) Navigator.of(context).pop(loans);
    } on ApiException catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _sending = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final due = DateTime(now.year, now.month, now.day + widget.rules.maxLoanDays);
    final customer = widget.customer;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(22, 12, 22, 20 + MediaQuery.paddingOf(context).bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              const SizedBox(height: 18),
              Text('Revisa el préstamo', style: AppText.title),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.event_rounded, size: 16, color: AppColors.muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Devolver antes del ${formatLongDate(due)}',
                      style: AppText.caption.copyWith(fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _Card(
                child: Column(
                  children: [
                    Row(
                      children: [
                        customer == null
                            ? const InitialAvatar(
                                initial: '–',
                                size: 44,
                                background: AppColors.hairline,
                                foreground: AppColors.muted,
                              )
                            : InitialAvatar(initial: customer.initial, size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(customer?.displayName ?? 'Sin cliente', style: AppText.label.copyWith(fontSize: 16)),
                              Text(
                                customer == null
                                    ? 'El préstamo no queda a nombre de nadie.'
                                    : customer.isNewInLocal
                                    ? 'Queda registrado en tu local con este préstamo.'
                                    : customer.email,
                                style: AppText.caption,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1, color: AppColors.hairline),
                    ),
                    for (final item in widget.containers)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: AppColors.pinkMist,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.takeout_dining_rounded, size: 17, color: AppColors.pink),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(item.containerType, style: AppText.label.copyWith(fontSize: 14))),
                            Text(item.code, style: AppText.caption.copyWith(letterSpacing: 0.5)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Text('Garantía', style: AppText.headline),
                  const SizedBox(width: 8),
                  if (widget.rules.requireGuarantee)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.yellow, borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        'Tu local la pide',
                        style: AppText.caption.copyWith(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (_guaranteeTotal > 0)
                    Text(formatClp(_guaranteeTotal), style: AppText.headline.copyWith(fontSize: 20)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _GuaranteeOption(
                      icon: Icons.handshake_rounded,
                      label: 'Sin garantía',
                      detail: 'Confianza',
                      selected: _guarantee == GuaranteeMethod.none,
                      onTap: () => setState(() => _guarantee = GuaranteeMethod.none),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _GuaranteeOption(
                      icon: Icons.payments_rounded,
                      label: 'Efectivo',
                      detail: _guaranteeTotal > 0 ? formatClp(_guaranteeTotal) : 'En caja',
                      selected: _guarantee == GuaranteeMethod.cash,
                      onTap: () => setState(() => _guarantee = GuaranteeMethod.cash),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _GuaranteeOption(
                      icon: Icons.credit_card_rounded,
                      label: 'Tarjeta',
                      detail: customer == null
                          ? 'Pide carnet'
                          : _cardAvailable
                          ? 'Guardada'
                          : 'Sin tarjeta',
                      selected: _guarantee == GuaranteeMethod.card,
                      enabled: _cardAvailable,
                      onTap: () => setState(() => _guarantee = GuaranteeMethod.card),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: AppMotion.fast,
                child: Text(
                  switch (_guarantee) {
                    GuaranteeMethod.none => 'El cliente se lleva el envase sin dejar garantía.',
                    GuaranteeMethod.cash =>
                      _guaranteeTotal > 0
                          ? 'Recibe ${formatClp(_guaranteeTotal)} en efectivo y devuélvelos cuando traiga el envase.'
                          : 'Recibe la garantía en efectivo en caja.',
                    GuaranteeMethod.card => 'No se cobra ahora. Si no devuelve el envase, puedes cobrar la garantía a su tarjeta desde el préstamo.',
                  },
                  key: ValueKey(_guarantee),
                  style: AppText.caption,
                ),
              ),
              const SizedBox(height: 18),
              AnimatedSize(
                duration: AppMotion.medium,
                curve: AppMotion.emphasized,
                alignment: Alignment.topLeft,
                child: _showNotes
                    ? TextField(
                        controller: _notes,
                        autofocus: true,
                        maxLines: 2,
                        maxLength: 500,
                        style: AppText.body.copyWith(color: AppColors.navy),
                        decoration: InputDecoration(
                          hintText: 'Nota para este préstamo',
                          hintStyle: AppText.body,
                          counterText: '',
                          filled: true,
                          fillColor: AppColors.white,
                          contentPadding: const EdgeInsets.all(16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(color: AppColors.hairline),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(color: AppColors.hairline),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(color: AppColors.pink, width: 1.5),
                          ),
                        ),
                      )
                    : Pressable(
                        onTap: () => setState(() => _showNotes = true),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.edit_note_rounded, color: AppColors.pink),
                            const SizedBox(width: 6),
                            Text('Agregar nota', style: AppText.label.copyWith(color: AppColors.pink)),
                          ],
                        ),
                      ),
              ),
              AnimatedSize(
                duration: AppMotion.fast,
                child: _error == null
                    ? const SizedBox(width: double.infinity)
                    : Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.pinkMist, borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppColors.pink, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: AppText.caption.copyWith(color: AppColors.pinkDark, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 20),
              PrimaryButton(label: 'Confirmar préstamo', isLoading: _sending, onPressed: _confirm),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.hairline),
      ),
      child: child,
    );
  }
}

class _GuaranteeOption extends StatelessWidget {
  const _GuaranteeOption({
    required this.icon,
    required this.label,
    required this.detail,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final String detail;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.white : AppColors.navy;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Pressable(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: AppMotion.medium,
          curve: AppMotion.emphasized,
          height: 96,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? AppColors.navy : AppColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? AppColors.navy : AppColors.hairline),
            boxShadow: selected
                ? [BoxShadow(color: AppColors.navy.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 8))]
                : const [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 22, color: selected ? AppColors.lime : AppColors.pink),
                  const Spacer(),
                  AnimatedScale(
                    scale: selected ? 1 : 0,
                    duration: AppMotion.medium,
                    curve: AppMotion.bouncy,
                    child: const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.lime),
                  ),
                ],
              ),
              const Spacer(),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(label, style: AppText.label.copyWith(color: foreground, fontSize: 14)),
              ),
              Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption.copyWith(
                  fontSize: 12,
                  color: selected ? AppColors.white.withValues(alpha: 0.75) : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Celebration after lending: what went out, to whom, until when.
class LendSuccessView extends StatelessWidget {
  const LendSuccessView({
    super.key,
    required this.loans,
    required this.customerName,
    required this.onNewLoan,
    required this.onDone,
  });

  final List<OperatorLoan> loans;
  final String? customerName;
  final VoidCallback onNewLoan;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final due = loans.isEmpty ? null : loans.first.dueDate;
    final count = loans.length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
        child: Column(
          children: [
            const Spacer(flex: 2),
            SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.4, end: 1),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => Container(
                      width: 200 * v,
                      height: 200 * v,
                      decoration: BoxDecoration(
                        color: AppColors.lime.withValues(alpha: 0.12 * (1.4 - v)),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 700),
                    curve: AppMotion.bouncy,
                    builder: (context, v, child) => Transform.scale(scale: v, child: child),
                    child: Container(
                      width: 116,
                      height: 116,
                      decoration: BoxDecoration(
                        color: AppColors.lime,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: AppColors.lime.withValues(alpha: 0.35), blurRadius: 40)],
                      ),
                      child: const Icon(Icons.check_rounded, color: AppColors.navy, size: 64),
                    ),
                  ),
                  const Positioned(left: 16, top: 30, child: Sparkle(size: 18, color: AppColors.pinkSoft)),
                  const Positioned(right: 20, top: 16, child: Sparkle(size: 12, color: AppColors.yellow)),
                  const Positioned(right: 8, bottom: 40, child: Sparkle(size: 16, color: AppColors.lime)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text('¡Prestado!', style: AppText.hero.copyWith(color: AppColors.white, fontSize: 44)),
            const SizedBox(height: 6),
            Text(
              customerName == null
                  ? '$count ${count == 1 ? 'envase' : 'envases'} sin cliente'
                  : '$count ${count == 1 ? 'envase' : 'envases'} para $customerName',
              style: AppText.body.copyWith(color: AppColors.white.withValues(alpha: 0.8), fontSize: 17),
              textAlign: TextAlign.center,
            ),
            if (due != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.event_rounded, size: 17, color: AppColors.lime),
                    const SizedBox(width: 8),
                    Text(
                      'Devolver antes del ${formatLongDate(due)}',
                      style: AppText.caption.copyWith(color: AppColors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (final loan in loans)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.white.withValues(alpha: 0.18)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      loan.containerCode,
                      style: AppText.caption.copyWith(
                        color: AppColors.white.withValues(alpha: 0.75),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
            const Spacer(flex: 3),
            PrimaryButton(label: 'Nuevo préstamo', onPressed: onNewLoan),
            const SizedBox(height: 6),
            Pressable(
              onTap: onDone,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Volver al inicio',
                  style: AppText.label.copyWith(color: AppColors.white.withValues(alpha: 0.8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
