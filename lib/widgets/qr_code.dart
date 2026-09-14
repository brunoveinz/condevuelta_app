import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../theme/app_theme.dart';

/// Real, scannable QR of [data]. Square modules on purpose: rounded dots look
/// nicer but some in-store scanners read them worse.
class QrCode extends StatelessWidget {
  const QrCode({super.key, required this.data, this.size = 200, this.color = AppColors.navy});

  final String data;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return QrImageView(
      data: data,
      size: size,
      padding: EdgeInsets.zero,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: color),
      dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: color),
    );
  }
}
