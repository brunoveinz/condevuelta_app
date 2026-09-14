import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/brand.dart';

/// Short celebration after signing in: a pink wipe, a check that draws itself
/// and a greeting, then the home. Welcomes new customers to Condevuelta and
/// greets returning ones ("hola de nuevo").
class ReadyScreen extends StatefulWidget {
  const ReadyScreen({super.key});

  @override
  State<ReadyScreen> createState() => _ReadyScreenState();
}

class _ReadyScreenState extends State<ReadyScreen> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  bool _didHaptic = false;

  late final _wipe = _interval(0, 0.3);
  late final _badge = _interval(0.2, 0.45, AppMotion.bouncy);
  late final _check = _interval(0.32, 0.52);
  late final _text = _interval(0.42, 0.7);
  late final _sparkles = _interval(0.45, 0.9, Curves.easeOut);
  late final _dots = _interval(0.6, 0.75);

  Animation<double> _interval(double begin, double end, [Curve curve = AppMotion.emphasized]) =>
      CurvedAnimation(parent: _controller, curve: Interval(begin, end, curve: curve));

  @override
  void initState() {
    super.initState();
    _controller
      ..addListener(_onTick)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) AppScope.read(context).enterHome();
      })
      ..forward();
  }

  void _onTick() {
    if (!_didHaptic && _controller.value >= 0.34) {
      _didHaptic = true;
      HapticFeedback.mediumImpact();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final firstName = state.customer?.firstName ?? '';
    final title = state.isReturning
        ? (firstName.isEmpty ? '¡Hola de nuevo!' : '¡Hola de nuevo, $firstName!')
        : (firstName.isEmpty ? '¡Hola!' : '¡Hola, $firstName!');
    final subtitle = state.isReturning
        ? 'Qué bueno verte otra vez\npor Condevuelta.'
        : 'Te damos la bienvenida a Condevuelta.\nTe enviamos un correo con todo.';
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final text = _text.value;
            return Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: _WipePainter(_wipe.value))),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 280,
                          height: 220,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              for (var i = 0; i < 8; i++) _sparkle(i),
                              Transform.scale(
                                scale: _badge.value,
                                child: Container(
                                  width: 112,
                                  height: 112,
                                  decoration: BoxDecoration(
                                    color: AppColors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.pinkDark.withValues(alpha: 0.45),
                                        blurRadius: 32,
                                        offset: const Offset(0, 14),
                                      ),
                                    ],
                                  ),
                                  child: CustomPaint(painter: _CheckPainter(_check.value)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Opacity(
                          opacity: text,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - text)),
                            child: Column(
                              children: [
                                Text(
                                  title,
                                  style: AppText.hero.copyWith(color: AppColors.white),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  subtitle,
                                  style: AppText.body.copyWith(color: AppColors.white.withValues(alpha: 0.88)),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        Opacity(opacity: _dots.value, child: _LoadingDots(phase: _controller.value)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Sparkles burst outwards from the badge and fade.
  Widget _sparkle(int i) {
    final t = _sparkles.value;
    if (t == 0) return const SizedBox.shrink();
    final angle = i * pi / 4 + pi / 8;
    final radius = 72 + 58 * t;
    final opacity = t < 0.3 ? t / 0.3 : 1 - (t - 0.3) / 0.7;
    return Transform.translate(
      offset: Offset(cos(angle) * radius, sin(angle) * radius * 0.8),
      child: Opacity(
        opacity: opacity.clamp(0, 1),
        child: Transform.scale(
          scale: 0.4 + sin(t * pi) * 0.8,
          child: Sparkle(size: i.isEven ? 22 : 14, color: i % 3 == 0 ? AppColors.yellow : AppColors.white),
        ),
      ),
    );
  }
}

/// Pink circle growing from the center until it covers the screen.
class _WipePainter extends CustomPainter {
  _WipePainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = size.center(Offset.zero);
    final fullRadius = sqrt(size.width * size.width + size.height * size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: fullRadius);
    final paint = Paint()
      ..shader = const RadialGradient(colors: [AppColors.pink, AppColors.pinkDark]).createShader(rect);
    canvas.drawCircle(center, fullRadius * progress, paint);
  }

  @override
  bool shouldRepaint(_WipePainter old) => old.progress != progress;
}

/// Check mark that draws itself as [progress] goes 0 -> 1.
class _CheckPainter extends CustomPainter {
  _CheckPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.29, h * 0.52)
      ..lineTo(w * 0.45, h * 0.67)
      ..lineTo(w * 0.73, h * 0.38);
    final paint = Paint()
      ..color = AppColors.pink
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.085
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.progress != progress;
}

/// Three pulsing dots: "finishing setting you up".
class _LoadingDots extends StatelessWidget {
  const _LoadingDots({required this.phase});

  final double phase;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Opacity(
            opacity: 0.35 + 0.65 * (0.5 + 0.5 * sin(phase * 7 * pi - i * 0.9)),
            child: Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(color: AppColors.white, shape: BoxShape.circle),
            ),
          ),
        ],
      ],
    );
  }
}
