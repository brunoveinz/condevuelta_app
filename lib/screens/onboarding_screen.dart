import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/brand.dart';
import '../widgets/countdown_ring.dart';
import '../widgets/pressable.dart';
import '../widgets/primary_button.dart';
import '../widgets/qr_code.dart';

class _Step {
  const _Step(this.title, this.body, this.background);

  final String title;
  final String body;
  final Color background;
}

const _steps = [
  _Step(
    'Pide tu comida en retornable',
    'En los locales con Condevuelta, pide tu comida en un envase que se vuelve a usar. Chao desechables.',
    AppColors.pinkSoft,
  ),
  _Step(
    'Muestra tu carnet QR',
    'Tu carnet vive en la app y sirve en todos los locales. En caja lo escanean y el envase queda a tu nombre.',
    AppColors.sky,
  ),
  _Step(
    'Disfruta',
    'Llévatelo y cómetelo donde quieras. Tú feliz, el planeta también.',
    AppColors.yellow,
  ),
  _Step(
    'Devuélvelo a tiempo',
    'Devuélvelo en el mismo local antes de la fecha. La app te muestra cuántos días te quedan.',
    AppColors.green,
  ),
];

/// One-time animated tutorial shown right after installing the app.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _isLast => _page == _steps.length - 1;

  void _next() {
    if (_isLast) {
      AppScope.read(context).finishOnboarding();
      return;
    }
    _pageController.nextPage(duration: const Duration(milliseconds: 600), curve: AppMotion.emphasized);
  }

  Color _backgroundFor(double page) {
    final index = page.floor().clamp(0, _steps.length - 1);
    final nextIndex = (index + 1).clamp(0, _steps.length - 1);
    return Color.lerp(_steps[index].background, _steps[nextIndex].background, page - index)!;
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_page];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: AnimatedBuilder(
        animation: _pageController,
        builder: (context, child) {
          final page = _pageController.hasClients ? (_pageController.page ?? 0) : 0.0;
          return Material(color: _backgroundFor(page), child: child);
        },
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 16, 0),
                child: Row(
                  children: [
                    const BrandMark(width: 52),
                    const Spacer(),
                    AnimatedOpacity(
                      opacity: _isLast ? 0 : 1,
                      duration: AppMotion.fast,
                      child: Pressable(
                        onTap: _isLast ? null : () => AppScope.read(context).finishOnboarding(),
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.white.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const Text('Saltar', style: AppText.label),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (value) {
                  HapticFeedback.selectionClick();
                  setState(() => _page = value);
                },
                children: const [
                  _BowlIllustration(),
                  _CarnetIllustration(),
                  _MascotIllustration(),
                  _TimerIllustration(),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(28, 30, 24, 24 + MediaQuery.paddingOf(context).bottom),
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [BoxShadow(color: Color(0x141E264A), blurRadius: 40, offset: Offset(0, -12))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 150,
                    child: AnimatedSwitcher(
                      duration: AppMotion.medium,
                      switchInCurve: AppMotion.emphasized,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(begin: const Offset(0, 0.12), end: Offset.zero).animate(animation),
                          child: child,
                        ),
                      ),
                      layoutBuilder: (current, previous) => Stack(
                        alignment: Alignment.topLeft,
                        children: [...previous, ?current],
                      ),
                      child: Column(
                        key: ValueKey(_page),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(step.title, style: AppText.hero.copyWith(fontSize: 34)),
                          const SizedBox(height: 10),
                          Text(step.body, style: AppText.body),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      for (var i = 0; i < _steps.length; i++)
                        AnimatedContainer(
                          duration: AppMotion.medium,
                          curve: AppMotion.emphasized,
                          margin: const EdgeInsets.only(right: 6),
                          width: i == _page ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _page ? AppColors.navy : AppColors.navy.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      const Spacer(),
                      PrimaryButton(
                        label: _isLast ? 'Empezar' : 'Siguiente',
                        onPressed: _next,
                        expanded: false,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Base for illustrations: a looping clock plus a one-shot pop-in.
abstract class _LoopingIllustration extends StatefulWidget {
  const _LoopingIllustration();

  Duration get period => const Duration(milliseconds: 3600);

  Widget buildFrame(BuildContext context, double t);

  @override
  State<_LoopingIllustration> createState() => _LoopingIllustrationState();
}

class _LoopingIllustrationState extends State<_LoopingIllustration> with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(vsync: this, duration: widget.period)..repeat();

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: AppMotion.bouncy,
      builder: (context, pop, child) => Opacity(
        opacity: pop.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.8 + 0.2 * pop, child: Transform.rotate(angle: (1 - pop) * -0.09, child: child)),
      ),
      child: AnimatedBuilder(
        animation: _loop,
        builder: (context, _) => Center(child: widget.buildFrame(context, _loop.value)),
      ),
    );
  }
}

double _float(double t, [double amplitude = 10]) => sin(t * 2 * pi) * amplitude;

class _Blob extends StatelessWidget {
  const _Blob({required this.t, required this.color, this.size = 280});

  final double t;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final a = sin(t * 2 * pi);
    Radius r(double base) => Radius.elliptical(size * (base + 0.07 * a), size * (base - 0.06 * a));
    return Transform.rotate(
      angle: a * 0.22,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(topLeft: r(0.58), topRight: r(0.42), bottomLeft: r(0.5), bottomRight: r(0.5)),
        ),
      ),
    );
  }
}

class _WobblySparkle extends StatelessWidget {
  const _WobblySparkle({required this.t, required this.size, required this.color, this.phase = 0});

  final double t;
  final double size;
  final Color color;
  final double phase;

  @override
  Widget build(BuildContext context) {
    final a = sin((t + phase) * 2 * pi);
    return Transform.rotate(
      angle: a * 0.2,
      child: Transform.scale(scale: 1 + 0.15 * a, child: Sparkle(size: size, color: color)),
    );
  }
}

class _BowlIllustration extends _LoopingIllustration {
  const _BowlIllustration();

  @override
  Widget buildFrame(BuildContext context, double t) {
    Widget steam(double phase) {
      final p = (t * 1.6 + phase) % 1.0;
      final opacity = p < 0.4 ? p / 0.4 : 1 - (p - 0.4) / 0.6;
      return Transform.translate(
        offset: Offset(0, 10 - 36 * p),
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0) * 0.95,
          child: Container(
            width: 8,
            height: 30,
            decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(4)),
          ),
        ),
      );
    }

    return SizedBox(
      width: 340,
      height: 340,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _Blob(t: t, color: AppColors.pinkMist),
          Positioned(left: 40, top: 60, child: _WobblySparkle(t: t, size: 26, color: AppColors.white)),
          Positioned(right: 50, top: 100, child: _WobblySparkle(t: t, size: 18, color: AppColors.yellow, phase: 0.3)),
          Positioned(right: 80, bottom: 56, child: _WobblySparkle(t: t, size: 14, color: AppColors.pink, phase: 0.6)),
          Transform.translate(
            offset: Offset(0, _float(t)),
            child: SizedBox(
              width: 220,
              height: 212,
              child: Stack(
                children: [
                  Positioned(
                    left: 84,
                    top: 0,
                    child: Row(children: [steam(0), const SizedBox(width: 14), steam(0.33), const SizedBox(width: 14), steam(0.66)]),
                  ),
                  const Positioned(left: 0, top: 22, child: CustomPaint(size: Size(220, 190), painter: _BowlPainter())),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable container drawn in the same outlined style as the mascot.
class _BowlPainter extends CustomPainter {
  const _BowlPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 220);
    final stroke = Paint()
      ..color = AppColors.navy
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeJoin = StrokeJoin.round;
    final pink = Paint()..color = AppColors.pink;
    final white = Paint()..color = AppColors.white;
    final navy = Paint()..color = AppColors.navy;

    canvas.drawOval(Rect.fromCenter(center: const Offset(110, 182), width: 140, height: 14),
        Paint()..color = AppColors.navy.withValues(alpha: 0.14));

    final knob = RRect.fromRectAndRadius(const Rect.fromLTWH(90, 44, 40, 20), const Radius.circular(10));
    canvas.drawRRect(knob, pink);
    canvas.drawRRect(knob, stroke);

    final lid = RRect.fromRectAndRadius(const Rect.fromLTWH(30, 60, 160, 26), const Radius.circular(13));
    canvas.drawRRect(lid, pink);
    canvas.drawRRect(lid, stroke);

    final body = Path()
      ..moveTo(40, 92)
      ..lineTo(180, 92)
      ..lineTo(168, 156)
      ..quadraticBezierTo(165, 170, 151, 170)
      ..lineTo(69, 170)
      ..quadraticBezierTo(55, 170, 52, 156)
      ..close();
    canvas.drawPath(body, white);
    canvas.drawPath(body, stroke);

    canvas.drawLine(
      const Offset(58, 110),
      const Offset(162, 110),
      Paint()
        ..color = AppColors.green
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(93, 122, 34, 34), const Radius.circular(7)), navy);
    for (final r in const [
      Rect.fromLTWH(99, 128, 9, 9),
      Rect.fromLTWH(112, 128, 9, 9),
      Rect.fromLTWH(99, 141, 9, 9),
      Rect.fromLTWH(113, 142, 6, 6),
    ]) {
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(1.5)), white);
    }
  }

  @override
  bool shouldRepaint(_BowlPainter oldDelegate) => false;
}

class _CarnetIllustration extends _LoopingIllustration {
  const _CarnetIllustration();

  @override
  Duration get period => const Duration(milliseconds: 2400);

  @override
  Widget buildFrame(BuildContext context, double t) {
    Widget pulse(double phase) {
      final p = (t + phase) % 1.0;
      return Transform.scale(
        scale: 0.85 + 0.6 * p,
        child: Opacity(
          opacity: (0.7 * (1 - p)).clamp(0.0, 1.0),
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.white, width: 2),
            ),
          ),
        ),
      );
    }

    final scan = (sin(t * 2 * pi - pi / 2) + 1) / 2; // 0..1..0
    return SizedBox(
      width: 340,
      height: 360,
      child: Stack(
        alignment: Alignment.center,
        children: [
          pulse(0),
          pulse(0.5),
          Transform.translate(
            offset: Offset(0, _float(t * 0.66, 8)),
            child: SizedBox(
              width: 200,
              height: 316,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Transform.rotate(
                    angle: -0.1,
                    child: Container(
                      width: 172,
                      height: 300,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.navy,
                        borderRadius: BorderRadius.circular(36),
                        boxShadow: const [BoxShadow(color: Color(0x401E264A), blurRadius: 60, offset: Offset(0, 30))],
                      ),
                      child: Container(
                        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(27)),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 118,
                              height: 118,
                              padding: const EdgeInsets.all(11),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.hairline),
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  const QrCode(data: 'onboarding', size: 96),
                                  Positioned(
                                    left: -5,
                                    right: -5,
                                    top: 4 + 86 * scan,
                                    child: Container(
                                      height: 3,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(2),
                                        gradient: LinearGradient(colors: [
                                          AppColors.pink.withValues(alpha: 0),
                                          AppColors.pink,
                                          AppColors.pink.withValues(alpha: 0),
                                        ]),
                                        boxShadow: [BoxShadow(color: AppColors.pink.withValues(alpha: 0.7), blurRadius: 14)],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text('Tu carnet', style: AppText.headline.copyWith(fontSize: 17)),
                            const SizedBox(height: 8),
                            Container(
                              width: 64,
                              height: 8,
                              decoration: BoxDecoration(color: AppColors.pinkSoft, borderRadius: BorderRadius.circular(4)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -6,
                    top: 20,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 700),
                      curve: const Interval(0.35, 1, curve: AppMotion.bouncy),
                      builder: (context, v, child) => Transform.scale(scale: v, child: child),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.navy, width: 4),
                        ),
                        child: const Icon(Icons.check_rounded, color: AppColors.navy, size: 28),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MascotIllustration extends _LoopingIllustration {
  const _MascotIllustration();

  @override
  Widget buildFrame(BuildContext context, double t) {
    return SizedBox(
      width: 340,
      height: 340,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _Blob(t: t, color: AppColors.white.withValues(alpha: 0.55), size: 290),
          Positioned(left: 36, top: 56, child: _WobblySparkle(t: t, size: 24, color: AppColors.pink)),
          Positioned(right: 36, top: 90, child: _WobblySparkle(t: t, size: 18, color: AppColors.white, phase: 0.4)),
          Transform.translate(
            offset: Offset(0, _float(t)),
            child: Image.asset('assets/images/mascota.png', width: 300),
          ),
        ],
      ),
    );
  }
}

class _TimerIllustration extends _LoopingIllustration {
  const _TimerIllustration();

  @override
  Duration get period => const Duration(seconds: 9);

  @override
  Widget buildFrame(BuildContext context, double t) {
    final angle = t * 2 * pi;
    return SizedBox(
      width: 300,
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CountdownRing(
            progress: 0.72,
            size: 236,
            strokeWidth: 18,
            color: AppColors.white,
            trackColor: AppColors.white.withValues(alpha: 0.4),
            duration: const Duration(milliseconds: 1500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('7', style: AppText.hero.copyWith(fontSize: 92, height: 0.9)),
                Text('días', style: AppText.headline),
              ],
            ),
          ),
          Transform.rotate(
            angle: angle,
            child: SizedBox(
              width: 262,
              height: 262,
              child: Align(
                alignment: Alignment.topCenter,
                child: Transform.rotate(
                  angle: -angle,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.pink,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.navy, width: 4),
                    ),
                    child: const Icon(Icons.replay_rounded, color: AppColors.white, size: 26),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
