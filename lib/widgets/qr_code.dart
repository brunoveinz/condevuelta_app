import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Visual QR for the carnet.
///
/// PLACEHOLDER: this paints a deterministic QR-looking pattern from [data]
/// (finder patterns + pseudo-random modules). It is NOT a scannable QR.
/// Real encoding needs a QR library (e.g. the `qr` package) — pending the
/// user's approval per the dependency policy in AGENTS.txt.
class QrCode extends StatelessWidget {
  const QrCode({super.key, required this.data, this.size = 200, this.color = AppColors.navy});

  final String data;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _QrPainter(data: data, color: color)),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter({required this.data, required this.color});

  final String data;
  final Color color;
  static const _modules = 25;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / _modules;
    final paint = Paint()..color = color;
    final random = Random(data.hashCode);
    final radius = Radius.circular(cell * 0.28);

    bool inFinder(int x, int y) {
      bool within(int ox, int oy) => x >= ox && x < ox + 8 && y >= oy && y < oy + 8;
      return within(0, 0) || within(_modules - 8, 0) || within(0, _modules - 8);
    }

    for (var y = 0; y < _modules; y++) {
      for (var x = 0; x < _modules; x++) {
        final on = random.nextDouble() < 0.48;
        if (inFinder(x, y) || !on) continue;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x * cell, y * cell, cell, cell).deflate(cell * 0.06),
            radius,
          ),
          paint,
        );
      }
    }

    void finder(double ox, double oy) {
      final outer = Rect.fromLTWH(ox, oy, cell * 7, cell * 7);
      canvas.drawRRect(
        RRect.fromRectAndRadius(outer.deflate(cell / 2), Radius.circular(cell * 1.6)),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(ox + cell * 2, oy + cell * 2, cell * 3, cell * 3),
          Radius.circular(cell * 0.9),
        ),
        paint,
      );
    }

    finder(0, 0);
    finder(cell * (_modules - 7), 0);
    finder(0, cell * (_modules - 7));
  }

  @override
  bool shouldRepaint(_QrPainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.color != color;
}
