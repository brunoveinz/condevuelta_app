import 'package:flutter/material.dart';

import '../../data/operator_models.dart';
import '../../state/operator_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_format.dart';
import '../../widgets/brand.dart';
import '../../widgets/pressable.dart';
import 'counter_screen.dart';
import 'operator_loan_detail_screen.dart';
import 'operator_profile_screen.dart';
import 'operator_widgets.dart';

/// "Inicio" of the operator: today at the local, the two counter actions and
/// the loans that are late.
class OperatorHomeScreen extends StatelessWidget {
  const OperatorHomeScreen({super.key, required this.onOpenLoans});

  final VoidCallback onOpenLoans;

  @override
  Widget build(BuildContext context) {
    final controller = OperatorScope.of(context);
    final profile = controller.profile;
    final summary = controller.summary;
    final isFirstLoad = !controller.hasLoadedSummary && controller.isLoadingSummary;
    final overdue = controller.overdueLoans;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.pink,
        backgroundColor: AppColors.white,
        onRefresh: controller.refreshHome,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 140),
          children: [
            _Header(profile: profile),
            const SizedBox(height: 18),
            if (controller.summaryError != null && !controller.hasLoadedSummary)
              _ErrorCard(message: controller.summaryError!, onRetry: controller.refreshHome)
            else ...[
              if (!profile.canOperate) ...[
                StaggeredIn(index: 0, child: _UnavailableCard(local: profile.local)),
                const SizedBox(height: 12),
              ],
              StaggeredIn(
                index: 0,
                child: isFirstLoad
                    ? const SkeletonBox(height: 196, radius: 28)
                    : _TodayCard(localName: profile.local.name, summary: summary),
              ),
              const SizedBox(height: 12),
              StaggeredIn(
                index: 1,
                child: Row(
                  children: [
                    Expanded(
                      child: _CounterAction(
                        icon: Icons.outbox_rounded,
                        title: 'Prestar',
                        subtitle: 'Carnet y envases',
                        background: AppColors.pink,
                        foreground: AppColors.white,
                        enabled: profile.canOperate,
                        onTap: () => openCounter(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _CounterAction(
                        icon: Icons.move_to_inbox_rounded,
                        title: 'Recibir',
                        subtitle: 'Envase devuelto',
                        background: AppColors.lime,
                        foreground: AppColors.navy,
                        enabled: profile.canOperate,
                        onTap: () => openCounter(context, mode: CounterMode.receive),
                      ),
                    ),
                  ],
                ),
              ),
              if (summary.usage.applies && (summary.usage.near || summary.usage.over)) ...[
                const SizedBox(height: 12),
                StaggeredIn(index: 2, child: _UsageCard(usage: summary.usage)),
              ],
              const SizedBox(height: 28),
              SectionTitle(
                title: 'Vencidos',
                count: summary.overdue == 0 ? null : summary.overdue,
                actionLabel: summary.overdue > overdue.length || overdue.length > 4 ? 'Ver todos' : null,
                onAction: () {
                  controller.setFilter(LoanFilter.overdue);
                  onOpenLoans();
                },
              ),
              const SizedBox(height: 12),
              if (isFirstLoad)
                for (var i = 0; i < 2; i++) ...[const SkeletonBox(height: 76, radius: 22), const SizedBox(height: 10)]
              else if (overdue.isEmpty)
                const StaggeredIn(index: 3, child: _AllGoodCard())
              else
                for (var i = 0; i < overdue.length && i < 4; i++) ...[
                  StaggeredIn(
                    index: i + 3,
                    child: OperatorLoanTile(
                      loan: overdue[i],
                      onTap: () => pushOperatorPage(context, OperatorLoanDetailScreen(loan: overdue[i])),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile});

  final OperatorProfile profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
                decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.storefront_rounded, size: 14, color: AppColors.lime),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        profile.local.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text('${greetingFor(DateTime.now())},', style: AppText.body),
              Text(profile.firstName.isEmpty ? 'equipo' : profile.firstName, style: AppText.title),
            ],
          ),
        ),
        Pressable(
          onTap: () => pushOperatorPage(context, const OperatorProfileScreen()),
          child: InitialAvatar(initial: profile.initial, background: AppColors.navy, foreground: AppColors.white),
        ),
      ],
    );
  }
}

/// Navy card: open loans at the local and today's movement.
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.localName, required this.summary});

  final String localName;
  final OperatorSummary summary;

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.white.withValues(alpha: 0.68);
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2A3466), AppColors.navy, Color(0xFF151B36)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -46,
              top: -56,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(color: AppColors.pink.withValues(alpha: 0.22), shape: BoxShape.circle),
              ),
            ),
            Positioned(
              right: 40,
              bottom: -70,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(color: AppColors.lime.withValues(alpha: 0.08), shape: BoxShape.circle),
              ),
            ),
            const Positioned(right: 26, top: 22, child: Sparkle(size: 14, color: AppColors.lime)),
            const Positioned(right: 70, top: 58, child: Sparkle(size: 8, color: AppColors.pinkSoft)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'En circulación',
                    style: AppText.caption.copyWith(color: muted, fontWeight: FontWeight.w500),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _AnimatedCount(
                        value: summary.open,
                        style: AppText.hero.copyWith(fontSize: 62, height: 1.02, color: AppColors.white),
                      ),
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          summary.open == 1 ? 'envase\nprestado' : 'envases\nprestados',
                          style: AppText.label.copyWith(color: AppColors.white, height: 1.15),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _TodayStat(
                          value: summary.lentToday,
                          label: 'prestados hoy',
                          icon: Icons.north_east_rounded,
                        ),
                      ),
                      Container(width: 1, height: 34, color: AppColors.white.withValues(alpha: 0.12)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _TodayStat(
                          value: summary.returnedToday,
                          label: 'recibidos hoy',
                          icon: Icons.south_west_rounded,
                        ),
                      ),
                    ],
                  ),
                  if (summary.overdue > 0 || summary.dueToday > 0) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (summary.overdue > 0)
                          _DarkPill(
                            '${summary.overdue} ${summary.overdue == 1 ? 'vencido' : 'vencidos'}',
                            AppColors.pink,
                            AppColors.white,
                          ),
                        if (summary.dueToday > 0)
                          _DarkPill(
                            '${summary.dueToday} ${summary.dueToday == 1 ? 'vence' : 'vencen'} hoy',
                            AppColors.yellow,
                            AppColors.navy,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedCount extends StatelessWidget {
  const _AnimatedCount({required this.value, required this.style});

  final int value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: AppMotion.emphasized,
      builder: (context, v, _) => Text('${v.round()}', style: style),
    );
  }
}

class _TodayStat extends StatelessWidget {
  const _TodayStat({required this.value, required this.label, required this.icon});

  final int value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: AppColors.lime),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AnimatedCount(
              value: value,
              style: AppText.headline.copyWith(color: AppColors.white, height: 1),
            ),
            Text(label, style: AppText.caption.copyWith(color: AppColors.white.withValues(alpha: 0.68), fontSize: 12)),
          ],
        ),
      ],
    );
  }
}

class _DarkPill extends StatelessWidget {
  const _DarkPill(this.label, this.background, this.foreground);

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
      child: Text(
        label,
        style: AppText.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: foreground),
      ),
    );
  }
}

/// Big square shortcut to the counter ("Prestar" / "Recibir").
class _CounterAction extends StatelessWidget {
  const _CounterAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.background,
    required this.foreground,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color background;
  final Color foreground;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Pressable(
        onTap: enabled ? onTap : null,
        scale: 0.96,
        child: Container(
          height: 132,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(color: background.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: foreground.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, size: 25, color: foreground),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_rounded, color: foreground.withValues(alpha: 0.7), size: 20),
                ],
              ),
              const Spacer(),
              Text(title, style: AppText.headline.copyWith(color: foreground, fontSize: 24, height: 1)),
              const SizedBox(height: 2),
              Text(subtitle, style: AppText.caption.copyWith(color: foreground.withValues(alpha: 0.8))),
            ],
          ),
        ),
      ),
    );
  }
}

/// Free monthly movements of the plan, shown when close to (or past) the limit.
class _UsageCard extends StatelessWidget {
  const _UsageCard({required this.usage});

  final PlanUsage usage;

  @override
  Widget build(BuildContext context) {
    final progress = usage.quota == 0 ? 1.0 : (usage.used / usage.quota).clamp(0.0, 1.0);
    final blocked = usage.needsCard;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: blocked ? AppColors.pinkMist : AppColors.yellow.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                blocked ? Icons.credit_card_off_rounded : Icons.speed_rounded,
                color: blocked ? AppColors.pink : AppColors.navy,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  blocked ? 'Alcanzaste tu cupo del mes' : 'Te queda poco cupo este mes',
                  style: AppText.label,
                ),
              ),
              Text('${usage.used}/${usage.quota}', style: AppText.label.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 900),
              curve: AppMotion.emphasized,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                color: blocked || usage.over ? AppColors.pink : AppColors.navy,
                backgroundColor: AppColors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            blocked
                ? 'Para seguir prestando, agrega una tarjeta desde el panel web de tu local. Las devoluciones siguen funcionando.'
                : 'Movimientos gratis usados. Con una tarjeta registrada, el exceso se cobra a fin de mes.',
            style: AppText.caption.copyWith(color: AppColors.navy),
          ),
        ],
      ),
    );
  }
}

class _UnavailableCard extends StatelessWidget {
  const _UnavailableCard({required this.local});

  final OperatorLocal local;

  @override
  Widget build(BuildContext context) {
    final title = local.blocked ? 'Tu local está en pausa' : 'Los préstamos están apagados';
    final body = local.blocked
        ? 'Condevuelta pausó el acceso de ${local.name}. Escríbenos para reactivarlo.'
        : 'Actívalos desde la configuración de ${local.name} en el panel web.';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.pinkMist, borderRadius: BorderRadius.circular(22)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(14)),
            child: Icon(local.blocked ? Icons.lock_rounded : Icons.toggle_off_rounded, color: AppColors.pink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.label.copyWith(fontSize: 16)),
                const SizedBox(height: 2),
                Text(body, style: AppText.caption.copyWith(color: AppColors.navy)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AllGoodCard extends StatelessWidget {
  const _AllGoodCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
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
              color: AppColors.green.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.verified_rounded, color: AppColors.navy),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Todo al día', style: AppText.label),
                SizedBox(height: 2),
                Text('Ningún envase de tu local está atrasado.', style: AppText.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 36, color: AppColors.pink),
          const SizedBox(height: 10),
          Text(message, style: AppText.body, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Pressable(
            onTap: onRetry,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text('Reintentar', style: AppText.label.copyWith(color: AppColors.pink)),
            ),
          ),
        ],
      ),
    );
  }
}
