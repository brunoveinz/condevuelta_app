import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';
import '../widgets/brand.dart';
import '../widgets/loan_tile.dart';
import '../widgets/place_badge.dart';
import '../widgets/pressable.dart';
import 'qr_hub_screen.dart';

/// "Inicio": the customer's impact, QR shortcuts, open loans, locals nearby
/// and (until the first loan) how it works.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onOpenLoans,
    required this.onOpenPlaces,
    required this.onOpenProfile,
  });

  final VoidCallback onOpenLoans;
  final VoidCallback onOpenPlaces;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final customer = state.customer;
    if (customer == null) return const SizedBox.shrink();
    final open = state.openLoans;
    final isFirstLoad = state.isLoadingHome && state.loans.isEmpty && state.places.isEmpty;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 140),
        children: [
          _Header(customer: customer, onOpenProfile: onOpenProfile),
          const SizedBox(height: 18),
          AnimatedSize(
            duration: AppMotion.medium,
            curve: AppMotion.emphasized,
            child: state.justSignedUp
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _WelcomeBanner(onClose: state.acknowledgeWelcome),
                  )
                : const SizedBox(width: double.infinity),
          ),
          _StaggeredIn(
            index: 0,
            child: isFirstLoad ? const _Skeleton(height: 150) : _ImpactCard(loans: state.loans),
          ),
          const SizedBox(height: 12),
          _StaggeredIn(
            index: 1,
            child: Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.qr_code_2_rounded,
                    title: 'Mi QR',
                    subtitle: 'Muéstralo en caja',
                    highlighted: true,
                    onTap: () => openQrHub(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.qr_code_scanner_rounded,
                    title: 'Escanear',
                    subtitle: 'Un local o envase',
                    onTap: () => openQrHub(context, mode: QrHubMode.scan),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _SectionHeader(
            title: 'Tus envases',
            count: open.isEmpty ? null : open.length,
            actionLabel: open.isEmpty ? null : 'Ver todo',
            onAction: onOpenLoans,
          ),
          const SizedBox(height: 12),
          if (isFirstLoad)
            for (var i = 0; i < 2; i++) ...[const _Skeleton(height: 80), const SizedBox(height: 10)]
          else if (open.isEmpty)
            const _EmptyLoans()
          else
            for (var i = 0; i < open.length; i++) ...[
              _StaggeredIn(
                index: i + 2,
                child: CompactLoanTile(loan: open[i], onTap: onOpenLoans),
              ),
              const SizedBox(height: 10),
            ],
          if (state.places.isNotEmpty) ...[
            const SizedBox(height: 28),
            _SectionHeader(title: 'Locales para ti', actionLabel: 'Ver todos', onAction: onOpenPlaces),
            const SizedBox(height: 12),
            _PlacesCarousel(places: state.places, onTap: onOpenPlaces),
          ],
          if (!isFirstLoad && state.loans.isEmpty) ...[
            const SizedBox(height: 28),
            const _SectionHeader(title: 'Así funciona'),
            const SizedBox(height: 12),
            const _HowItWorks(),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.customer, required this.onOpenProfile});

  final Customer customer;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${greetingFor(DateTime.now())},', style: AppText.body),
              Text(customer.firstName, style: AppText.title),
            ],
          ),
        ),
        Pressable(
          onTap: onOpenProfile,
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.pinkSoft, shape: BoxShape.circle),
            child: Text(customer.initial, style: AppText.headline.copyWith(color: AppColors.pinkDark)),
          ),
        ),
      ],
    );
  }
}

/// Green card with the mascot: how many disposables the customer avoided.
/// Every loan is one disposable container that wasn't used.
class _ImpactCard extends StatelessWidget {
  const _ImpactCard({required this.loans});

  final List<Loan> loans;

  @override
  Widget build(BuildContext context) {
    final avoided = loans.where((l) => l.status != LoanStatus.lost).length;
    final returned = loans.where((l) => l.status == LoanStatus.returned).length;
    final withYou = loans.where((l) => l.isOpen).length;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.lime, Color(0xFFC4E6A4), AppColors.green],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -40,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(color: AppColors.white.withValues(alpha: 0.28), shape: BoxShape.circle),
              ),
            ),
            const Positioned(right: 120, top: 18, child: Sparkle(size: 14, color: AppColors.white)),
            const Positioned(right: 20, bottom: 26, child: Sparkle(size: 10, color: AppColors.navy)),
            Positioned(
              right: 6,
              bottom: 0,
              child: Image.asset('assets/images/mascota.png', width: 118),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 130, 18),
              child: avoided == 0 ? const _ImpactEmpty() : _ImpactNumbers(avoided: avoided, returned: returned, withYou: withYou),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImpactEmpty extends StatelessWidget {
  const _ImpactEmpty();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tu impacto', style: AppText.caption.copyWith(color: AppColors.navy, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Text('Tu primer retornable te espera', style: AppText.headline.copyWith(fontSize: 24)),
        const SizedBox(height: 6),
        Text(
          'Cada envase que usas es un desechable menos en la basura.',
          style: AppText.caption.copyWith(color: AppColors.navy.withValues(alpha: 0.8)),
        ),
      ],
    );
  }
}

class _ImpactNumbers extends StatelessWidget {
  const _ImpactNumbers({required this.avoided, required this.returned, required this.withYou});

  final int avoided;
  final int returned;
  final int withYou;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tu impacto', style: AppText.caption.copyWith(color: AppColors.navy, fontWeight: FontWeight.w500)),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: avoided.toDouble()),
          duration: const Duration(milliseconds: 1100),
          curve: AppMotion.emphasized,
          builder: (context, v, _) => Text(
            '${v.round()}',
            style: AppText.hero.copyWith(fontSize: 56, height: 1.05),
          ),
        ),
        Text(
          avoided == 1 ? 'desechable evitado' : 'desechables evitados',
          style: AppText.label.copyWith(fontSize: 16),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _Pill('$returned ${returned == 1 ? 'devuelto' : 'devueltos'}'),
            if (withYou > 0) _Pill('$withYou contigo'),
          ],
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: AppColors.white.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: AppText.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.navy)),
    );
  }
}

/// Square-ish shortcut tile ("Mi QR" in pink, "Escanear" in white).
class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final foreground = highlighted ? AppColors.white : AppColors.navy;
    return Pressable(
      onTap: onTap,
      scale: 0.97,
      child: Container(
        height: 116,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: highlighted ? AppColors.pink : AppColors.white,
          borderRadius: BorderRadius.circular(24),
          border: highlighted ? null : Border.all(color: AppColors.hairline),
          boxShadow: highlighted
              ? [BoxShadow(color: AppColors.pink.withValues(alpha: 0.25), blurRadius: 18, offset: const Offset(0, 8))]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: highlighted ? AppColors.white.withValues(alpha: 0.2) : AppColors.pinkMist,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, size: 23, color: highlighted ? AppColors.white : AppColors.pink),
            ),
            const Spacer(),
            Text(title, style: AppText.label.copyWith(fontSize: 16, color: foreground)),
            Text(
              subtitle,
              style: AppText.caption.copyWith(color: highlighted ? AppColors.white.withValues(alpha: 0.85) : AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.count, this.actionLabel, this.onAction});

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
            child: Text('$count', style: AppText.caption.copyWith(color: AppColors.white, fontWeight: FontWeight.w500)),
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

/// Horizontal strip of locals, same badges as the Locales tab.
class _PlacesCarousel extends StatelessWidget {
  const _PlacesCarousel({required this.places, required this.onTap});

  final List<Place> places;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shown = places.take(8).toList();
    return SizedBox(
      height: 146,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // Let cards scroll to the screen edge instead of stopping at the padding.
        clipBehavior: Clip.none,
        itemCount: shown.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) => _StaggeredIn(
          index: i,
          child: _PlaceTile(place: shown[i], onTap: onTap),
        ),
      ),
    );
  }
}

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({required this.place, required this.onTap});

  final Place place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.97,
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PlaceBadge(place: place, size: 44),
            const SizedBox(height: 10),
            Text(
              place.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.label.copyWith(height: 1.2),
            ),
            const Spacer(),
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: place.isOpen ? AppColors.green : AppColors.muted,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(place.isOpen ? 'Abierto' : 'Cerrado', style: AppText.caption.copyWith(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The four steps of the tutorial, as a 2x2 grid.
class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  static const _steps = [
    (Icons.takeout_dining_rounded, AppColors.pinkMist, 'Pide en retornable', 'En un local Condevuelta.'),
    (Icons.qr_code_2_rounded, AppColors.skyMist, 'Muestra tu QR', 'El envase queda a tu nombre.'),
    (Icons.restaurant_rounded, AppColors.yellow, 'Disfruta', 'Sin desechables.'),
    (Icons.recycling_rounded, AppColors.lime, 'Devuélvelo', 'A tiempo, en el local.'),
  ];

  @override
  Widget build(BuildContext context) {
    Widget step(int i) {
      final (icon, color, title, text) = _steps[i];
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, size: 21, color: AppColors.navy),
                  ),
                  const Spacer(),
                  Text('${i + 1}', style: AppText.headline.copyWith(color: AppColors.navy.withValues(alpha: 0.15))),
                ],
              ),
              const SizedBox(height: 10),
              Text(title, style: AppText.label),
              const SizedBox(height: 2),
              Text(text, style: AppText.caption),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [step(0), const SizedBox(width: 10), step(1)])),
        const SizedBox(height: 10),
        IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [step(2), const SizedBox(width: 10), step(3)])),
      ],
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 8, 14),
      decoration: BoxDecoration(color: AppColors.pinkMist, borderRadius: BorderRadius.circular(22)),
      child: Row(
        children: [
          const Sparkle(size: 22, color: AppColors.pink),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('¡Ya eres parte de Condevuelta!', style: AppText.label.copyWith(fontSize: 16)),
                Text('Muestra tu QR en cualquier local con Condevuelta.', style: AppText.caption.copyWith(color: AppColors.navy)),
              ],
            ),
          ),
          Pressable(
            onTap: onClose,
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(Icons.close_rounded, size: 20, color: AppColors.navy),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLoans extends StatelessWidget {
  const _EmptyLoans();

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
            decoration: BoxDecoration(color: AppColors.pinkMist, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.takeout_dining_outlined, color: AppColors.pink),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'No tienes envases contigo. Cuando pidas en retornable, aparecerán aquí con su fecha de devolución.',
              style: AppText.caption,
            ),
          ),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1),
      duration: const Duration(milliseconds: 800),
      builder: (context, v, child) => Opacity(opacity: v, child: child),
      child: Container(
        height: height,
        decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}

/// Fade + rise, staggered by list position.
class _StaggeredIn extends StatelessWidget {
  const _StaggeredIn({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + 90 * index),
      curve: AppMotion.emphasized,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 20 * (1 - v)), child: child),
      ),
      child: child,
    );
  }
}
