import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';
import '../widgets/brand.dart';
import '../widgets/loan_tile.dart';
import '../widgets/pressable.dart';
import '../widgets/qr_code.dart';

/// Home tab: greeting, the carnet QR as hero, and a summary of open loans.
class CarnetScreen extends StatelessWidget {
  const CarnetScreen({super.key, required this.onOpenLoans, required this.onOpenProfile});

  final VoidCallback onOpenLoans;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final customer = state.customer;
    if (customer == null) return const SizedBox.shrink();
    final open = state.openLoans;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 130),
        children: [
          Row(
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
          ),
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
          _CarnetCard(customer: customer),
          const SizedBox(height: 28),
          Row(
            children: [
              Text('Tus envases', style: AppText.headline),
              const SizedBox(width: 8),
              if (open.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(10)),
                  child: Text('${open.length}', style: AppText.caption.copyWith(color: AppColors.white, fontWeight: FontWeight.w500)),
                ),
              const Spacer(),
              if (open.isNotEmpty)
                Pressable(
                  onTap: onOpenLoans,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('Ver todo', style: AppText.label.copyWith(color: AppColors.pink)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (state.isLoadingHome && state.loans.isEmpty)
            for (var i = 0; i < 2; i++) ...[const _TileSkeleton(), const SizedBox(height: 10)]
          else if (open.isEmpty)
            const _EmptyLoans()
          else
            for (var i = 0; i < open.length; i++) ...[
              _StaggeredIn(
                index: i,
                child: CompactLoanTile(loan: open[i], onTap: onOpenLoans),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _CarnetCard extends StatefulWidget {
  const _CarnetCard({required this.customer});

  final Customer customer;

  @override
  State<_CarnetCard> createState() => _CarnetCardState();
}

class _CarnetCardState extends State<_CarnetCard> with SingleTickerProviderStateMixin {
  late final _loop = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  void _openFullscreen() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 500),
        reverseTransitionDuration: const Duration(milliseconds: 380),
        pageBuilder: (_, _, _) => _CarnetFullscreen(customer: widget.customer),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customer = widget.customer;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: AppMotion.bouncy,
      builder: (context, v, child) => Transform.scale(scale: 0.9 + 0.1 * v, child: Opacity(opacity: v.clamp(0.0, 1.0), child: child)),
      child: Pressable(
        onTap: _openFullscreen,
        scale: 0.98,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Container(
            color: AppColors.navy,
            child: Stack(
              children: [
                Positioned(
                  right: -60,
                  top: -70,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(color: AppColors.pink.withValues(alpha: 0.22), shape: BoxShape.circle),
                  ),
                ),
                Positioned(
                  left: -40,
                  bottom: -80,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(color: AppColors.sky.withValues(alpha: 0.12), shape: BoxShape.circle),
                  ),
                ),
                AnimatedBuilder(
                  animation: _loop,
                  builder: (context, _) {
                    final t = _loop.value;
                    final x = t < 0.6 ? -160 + 700 * (t / 0.6) : 600.0;
                    return Positioned(
                      left: x,
                      top: -60,
                      bottom: -60,
                      child: Transform.rotate(
                        angle: 0.35,
                        child: Container(
                          width: 70,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              AppColors.white.withValues(alpha: 0),
                              AppColors.white.withValues(alpha: 0.09),
                              AppColors.white.withValues(alpha: 0),
                            ]),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const BrandMark(width: 40),
                          const SizedBox(width: 10),
                          Text(
                            'Carnet Condevuelta',
                            style: AppText.label.copyWith(color: AppColors.white.withValues(alpha: 0.85)),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: AppColors.lime, borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(color: AppColors.navy, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 6),
                                Text('Activo', style: AppText.caption.copyWith(color: AppColors.navy, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Hero(
                        tag: 'carnet-qr',
                        child: _QrPlate(data: customer.carnetToken, size: 196, scan: _loop),
                      ),
                      const SizedBox(height: 18),
                      Text(customer.name, style: AppText.headline.copyWith(color: AppColors.white, fontSize: 24)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.touch_app_rounded, size: 16, color: AppColors.white.withValues(alpha: 0.6)),
                          const SizedBox(width: 6),
                          Text(
                            'Toca para agrandar y muéstralo en caja',
                            style: AppText.caption.copyWith(color: AppColors.white.withValues(alpha: 0.7)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// White plate with the QR and an animated scan line.
class _QrPlate extends StatelessWidget {
  const _QrPlate({required this.data, required this.size, required this.scan});

  final String data;
  final double size;
  final Animation<double> scan;

  @override
  Widget build(BuildContext context) {
    final padding = size * 0.09;
    return Material(
      type: MaterialType.transparency,
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(size * 0.12)),
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              QrCode(data: data, size: size),
              AnimatedBuilder(
                animation: scan,
                builder: (context, _) {
                  final p = Curves.easeInOut.transform((scan.value * 2) % 1.0);
                  final down = (scan.value * 2).floor().isEven;
                  final y = (down ? p : 1 - p) * (size - 4);
                  return Positioned(
                    left: -padding * 0.5,
                    right: -padding * 0.5,
                    top: y,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: LinearGradient(colors: [
                          AppColors.pink.withValues(alpha: 0),
                          AppColors.pink,
                          AppColors.pink.withValues(alpha: 0),
                        ]),
                        boxShadow: [BoxShadow(color: AppColors.pink.withValues(alpha: 0.6), blurRadius: 16)],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Modo caja": the QR enlarged on a clean background for the operator.
class _CarnetFullscreen extends StatefulWidget {
  const _CarnetFullscreen({required this.customer});

  final Customer customer;

  @override
  State<_CarnetFullscreen> createState() => _CarnetFullscreenState();
}

class _CarnetFullscreenState extends State<_CarnetFullscreen> with SingleTickerProviderStateMixin {
  late final _loop = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(color: AppColors.background, shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded, color: AppColors.navy),
                  ),
                ),
              ),
              const Spacer(),
              Text('Muéstralo en caja', style: AppText.title),
              const SizedBox(height: 6),
              Text('El local lo escanea y el envase queda a tu nombre.', style: AppText.body, textAlign: TextAlign.center),
              const SizedBox(height: 32),
              Hero(tag: 'carnet-qr', child: _QrPlate(data: widget.customer.carnetToken, size: width * 0.68, scan: _loop)),
              const SizedBox(height: 28),
              Text(widget.customer.name, style: AppText.headline),
              const SizedBox(height: 4),
              Text(widget.customer.carnetToken, style: AppText.caption.copyWith(letterSpacing: 1.5)),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
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
      decoration: BoxDecoration(color: AppColors.lime, borderRadius: BorderRadius.circular(22)),
      child: Row(
        children: [
          const Sparkle(size: 22, color: AppColors.navy),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('¡Tu carnet está listo!', style: AppText.label.copyWith(fontSize: 16)),
                Text('Sirve en todos los locales con Condevuelta.', style: AppText.caption.copyWith(color: AppColors.navy)),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          Image.asset('assets/images/mascota.png', width: 72),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Aún no tienes envases. Pide tu próxima comida en retornable y muestra tu carnet.',
              style: AppText.body,
            ),
          ),
        ],
      ),
    );
  }
}

class _TileSkeleton extends StatelessWidget {
  const _TileSkeleton();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1),
      duration: const Duration(milliseconds: 800),
      builder: (context, v, child) => Opacity(opacity: v, child: child),
      child: Container(
        height: 80,
        decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(22)),
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
