import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Dims everything but a rounded square, with pink corner brackets that breathe.
class ScannerOverlayPainter extends CustomPainter {
  ScannerOverlayPainter({required this.cutout, required this.pulse, this.color = AppColors.pink, this.offsetY = -30});

  final double cutout;
  final double pulse;

  /// Corner brackets (flash green/pink to confirm a read).
  final Color color;

  /// Vertical shift of the cut-out from the center.
  final double offsetY;

  @override
  void paint(Canvas canvas, Size size) {
    final side = cutout + 8 * pulse;
    final rect = Rect.fromCenter(center: size.center(Offset(0, offsetY)), width: side, height: side);
    final hole = RRect.fromRectAndRadius(rect, const Radius.circular(28));
    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), Path()..addRRect(hole)),
      Paint()..color = AppColors.navy.withValues(alpha: 0.55),
    );

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    const arm = 34.0;
    const r = 28.0;
    final l = rect.left, t = rect.top, rt = rect.right, b = rect.bottom;
    canvas
      ..drawPath(
        Path()
          ..moveTo(l, t + arm)
          ..lineTo(l, t + r)
          ..arcToPoint(Offset(l + r, t), radius: const Radius.circular(r))
          ..lineTo(l + arm, t),
        paint,
      )
      ..drawPath(
        Path()
          ..moveTo(rt - arm, t)
          ..lineTo(rt - r, t)
          ..arcToPoint(Offset(rt, t + r), radius: const Radius.circular(r))
          ..lineTo(rt, t + arm),
        paint,
      )
      ..drawPath(
        Path()
          ..moveTo(rt, b - arm)
          ..lineTo(rt, b - r)
          ..arcToPoint(Offset(rt - r, b), radius: const Radius.circular(r))
          ..lineTo(rt - arm, b),
        paint,
      )
      ..drawPath(
        Path()
          ..moveTo(l + arm, b)
          ..lineTo(l + r, b)
          ..arcToPoint(Offset(l, b - r), radius: const Radius.circular(r))
          ..lineTo(l, b - arm),
        paint,
      );
  }

  @override
  bool shouldRepaint(ScannerOverlayPainter old) =>
      old.pulse != pulse || old.cutout != cutout || old.color != color || old.offsetY != offsetY;
}
