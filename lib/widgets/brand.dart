import 'package:flutter/material.dart';

/// Condevuelta mark (pink circle + swirl), rendered from web/.../logonew.svg.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.width = 48});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Image.asset('assets/images/logo_mark.png', width: width, filterQuality: FilterQuality.medium);
  }
}

/// Four-point sparkle used as decoration in illustrations.
class Sparkle extends StatelessWidget {
  const Sparkle({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _SparklePainter(color)),
    );
  }
}

class _SparklePainter extends CustomPainter {
  _SparklePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w / 2, 0)
      ..cubicTo(w / 2, h * 0.3, w * 0.7, h / 2, w, h / 2)
      ..cubicTo(w * 0.7, h / 2, w / 2, h * 0.7, w / 2, h)
      ..cubicTo(w / 2, h * 0.7, w * 0.3, h / 2, 0, h / 2)
      ..cubicTo(w * 0.3, h / 2, w / 2, h * 0.3, w / 2, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.color != color;
}
