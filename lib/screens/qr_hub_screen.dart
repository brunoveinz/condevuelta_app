import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../data/api_client.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';
import '../widgets/loan_tile.dart';
import '../widgets/place_badge.dart';
import '../widgets/pressable.dart';
import '../widgets/primary_button.dart';
import '../widgets/qr_code.dart';

enum QrHubMode { myQr, scan }

/// Opens the QR screen (from the raised tab bar button or the home cards).
Future<void> openQrHub(BuildContext context, {QrHubMode mode = QrHubMode.myQr}) {
  HapticFeedback.mediumImpact();
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 480),
      reverseTransitionDuration: const Duration(milliseconds: 340),
      pageBuilder: (_, _, _) => QrHubScreen(initialMode: mode),
      transitionsBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(parent: animation, curve: AppMotion.emphasized, reverseCurve: Curves.easeIn);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

/// Full screen with two modes: show my QR (for the cashier) or scan a QR
/// (a local's sign or a container).
class QrHubScreen extends StatefulWidget {
  const QrHubScreen({super.key, this.initialMode = QrHubMode.myQr});

  final QrHubMode initialMode;

  @override
  State<QrHubScreen> createState() => _QrHubScreenState();
}

class _QrHubScreenState extends State<QrHubScreen> {
  late QrHubMode _mode = widget.initialMode;

  void _setMode(QrHubMode mode) {
    if (mode == _mode) return;
    HapticFeedback.selectionClick();
    setState(() => _mode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.navy,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                // Stack, not Row: the switch stays centered on the screen no
                // matter the close button's width.
                child: SizedBox(
                  height: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _ModeSwitch(mode: _mode, onChanged: _setMode),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Pressable(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(color: AppColors.white.withValues(alpha: 0.12), shape: BoxShape.circle),
                            child: const Icon(Icons.close_rounded, color: AppColors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 360),
                  switchInCurve: AppMotion.emphasized,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: Tween(begin: 0.97, end: 1.0).animate(animation), child: child),
                  ),
                  child: _mode == QrHubMode.myQr
                      ? const _MyQrView(key: ValueKey('my-qr'))
                      : _ScanView(key: const ValueKey('scan'), onShowMyQr: () => _setMode(QrHubMode.myQr)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Segmented control "Mi QR | Escanear" with a sliding pink pill.
class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.mode, required this.onChanged});

  // Narrow enough to clear the close button on small phones.
  static const _segmentWidth = 108.0;

  final QrHubMode mode;
  final ValueChanged<QrHubMode> onChanged;

  static const _height = 40.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(24)),
      child: SizedBox(
        width: _segmentWidth * 2,
        height: _height,
        child: Stack(
          children: [
            // The pill occupies exactly the selected segment's box.
            AnimatedPositioned(
              key: const ValueKey('mode-pill'),
              duration: AppMotion.medium,
              curve: AppMotion.emphasized,
              left: mode == QrHubMode.myQr ? 0 : _segmentWidth,
              top: 0,
              width: _segmentWidth,
              height: _height,
              child: DecoratedBox(
                decoration: BoxDecoration(color: AppColors.pink, borderRadius: BorderRadius.circular(_height / 2)),
              ),
            ),
            Row(
              children: [
                _segment('Mi QR', Icons.qr_code_2_rounded, QrHubMode.myQr),
                _segment('Escanear', Icons.qr_code_scanner_rounded, QrHubMode.scan),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _segment(String label, IconData icon, QrHubMode value) {
    final selected = value == mode;
    final color = selected ? AppColors.white : AppColors.white.withValues(alpha: 0.65);
    return SizedBox(
      key: ValueKey('mode-segment-${value.name}'),
      width: _segmentWidth,
      height: _height,
      child: Pressable(
        onTap: () => onChanged(value),
        child: ColoredBox(
          color: Colors.transparent,
          child: Center(
            // Shrinks instead of overflowing with large accessibility text.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  key: ValueKey('mode-label-${value.name}'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18, color: color),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      // Tight line box: no extra leading pushing the text off-center.
                      textHeightBehavior: const TextHeightBehavior(
                        applyHeightToFirstAscent: false,
                        applyHeightToLastDescent: false,
                      ),
                      style: AppText.label.copyWith(fontSize: 14, height: 1.0, color: color),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Mi QR": the customer's QR, big, for the cashier to scan.
class _MyQrView extends StatefulWidget {
  const _MyQrView({super.key});

  @override
  State<_MyQrView> createState() => _MyQrViewState();
}

class _MyQrViewState extends State<_MyQrView> with SingleTickerProviderStateMixin {
  late final _loop = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customer = AppScope.of(context).customer;
    if (customer == null) return const SizedBox.shrink();
    final width = MediaQuery.sizeOf(context).width;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Spacer(),
          Text('Muéstralo en caja', style: AppText.title.copyWith(color: AppColors.white)),
          const SizedBox(height: 6),
          Text(
            'El local lo escanea y el envase queda a tu nombre.',
            style: AppText.body.copyWith(color: AppColors.white.withValues(alpha: 0.75)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          _QrPlate(data: customer.carnetToken, size: (width * 0.62).clamp(180.0, 300.0), scan: _loop),
          const SizedBox(height: 24),
          Text(customer.name, style: AppText.headline.copyWith(color: AppColors.white)),
          const SizedBox(height: 4),
          Text(
            customer.carnetToken,
            style: AppText.caption.copyWith(color: AppColors.white.withValues(alpha: 0.6), letterSpacing: 1.5),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(color: AppColors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.light_mode_rounded, size: 16, color: AppColors.yellow.withValues(alpha: 0.9)),
                const SizedBox(width: 8),
                Text(
                  'Si cuesta leerlo, sube el brillo',
                  style: AppText.caption.copyWith(color: AppColors.white.withValues(alpha: 0.75)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
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
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(size * 0.12),
        boxShadow: [BoxShadow(color: AppColors.pink.withValues(alpha: 0.25), blurRadius: 40, offset: const Offset(0, 16))],
      ),
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
    );
  }
}

/// "Escanear": camera with a framed cut-out; the backend tells what was read.
class _ScanView extends StatefulWidget {
  const _ScanView({super.key, required this.onShowMyQr});

  final VoidCallback onShowMyQr;

  @override
  State<_ScanView> createState() => _ScanViewState();
}

class _ScanViewState extends State<_ScanView> with SingleTickerProviderStateMixin {
  static const _cutout = 250.0;

  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  late final _corners = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);
  bool _busy = false;
  bool _torchOn = false;
  String? _error;

  @override
  void dispose() {
    _corners.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;
    String? raw;
    for (final barcode in capture.barcodes) {
      if (barcode.rawValue != null) {
        raw = barcode.rawValue;
        break;
      }
    }
    if (raw == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    HapticFeedback.mediumImpact();
    unawaited(_controller.stop());
    try {
      final result = await AppScope.read(context).resolveScan(raw);
      if (!mounted) return;
      final action = await showScanResult(context, result);
      if (!mounted) return;
      if (action == ScanAction.showMyQr) {
        widget.onShowMyQr();
        return;
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    unawaited(_controller.start());
  }

  Future<void> _toggleTorch() async {
    HapticFeedback.selectionClick();
    await _controller.toggleTorch();
    if (mounted) setState(() => _torchOn = !_torchOn);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error) => _CameraError(error: error, onShowMyQr: widget.onShowMyQr),
            ),
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _corners,
                builder: (context, _) => CustomPaint(
                  painter: _ScannerOverlayPainter(
                    cutout: _cutout,
                    pulse: Curves.easeInOut.transform(_corners.value),
                  ),
                ),
              ),
            ),
            if (_busy)
              const Center(
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.white),
                ),
              ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: Column(
                children: [
                  AnimatedSize(
                    duration: AppMotion.fast,
                    child: _error == null
                        ? const SizedBox(width: double.infinity)
                        : Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(color: AppColors.pink, borderRadius: BorderRadius.circular(16)),
                            child: Text(
                              _error!,
                              style: AppText.caption.copyWith(color: AppColors.white, fontWeight: FontWeight.w500),
                              textAlign: TextAlign.center,
                            ),
                          ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.navy.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            'Apunta al QR de un local o de un envase',
                            style: AppText.caption.copyWith(color: AppColors.white),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Pressable(
                        onTap: _toggleTorch,
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: _torchOn ? AppColors.yellow : AppColors.navy.withValues(alpha: 0.75),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _torchOn ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
                            color: _torchOn ? AppColors.navy : AppColors.white,
                            size: 22,
                          ),
                        ),
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

/// Dims everything but a rounded square, with pink corner brackets that breathe.
class _ScannerOverlayPainter extends CustomPainter {
  _ScannerOverlayPainter({required this.cutout, required this.pulse});

  final double cutout;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final side = cutout + 8 * pulse;
    final rect = Rect.fromCenter(center: size.center(const Offset(0, -30)), width: side, height: side);
    final hole = RRect.fromRectAndRadius(rect, const Radius.circular(28));
    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), Path()..addRRect(hole)),
      Paint()..color = AppColors.navy.withValues(alpha: 0.55),
    );

    final paint = Paint()
      ..color = AppColors.pink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    const arm = 34.0;
    const r = 28.0;
    final l = rect.left, t = rect.top, rt = rect.right, b = rect.bottom;
    canvas
      ..drawPath(Path()..moveTo(l, t + arm)..lineTo(l, t + r)..arcToPoint(Offset(l + r, t), radius: const Radius.circular(r))..lineTo(l + arm, t), paint)
      ..drawPath(Path()..moveTo(rt - arm, t)..lineTo(rt - r, t)..arcToPoint(Offset(rt, t + r), radius: const Radius.circular(r))..lineTo(rt, t + arm), paint)
      ..drawPath(Path()..moveTo(rt, b - arm)..lineTo(rt, b - r)..arcToPoint(Offset(rt - r, b), radius: const Radius.circular(r))..lineTo(rt - arm, b), paint)
      ..drawPath(Path()..moveTo(l + arm, b)..lineTo(l + r, b)..arcToPoint(Offset(l, b - r), radius: const Radius.circular(r))..lineTo(l, b - arm), paint);
  }

  @override
  bool shouldRepaint(_ScannerOverlayPainter old) => old.pulse != pulse || old.cutout != cutout;
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.error, required this.onShowMyQr});

  final MobileScannerException error;
  final VoidCallback onShowMyQr;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: AppColors.navy,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.no_photography_rounded, size: 52, color: AppColors.white.withValues(alpha: 0.8)),
            const SizedBox(height: 16),
            Text(
              'No podemos usar la cámara',
              style: AppText.headline.copyWith(color: AppColors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              denied
                  ? 'Dale permiso en Ajustes › Condevuelta › Cámara.'
                  : 'Revisa que tu teléfono tenga una cámara disponible.',
              style: AppText.body.copyWith(color: AppColors.white.withValues(alpha: 0.75)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Pressable(
              onTap: onShowMyQr,
              child: Text('Mostrar mi QR', style: AppText.label.copyWith(color: AppColors.pinkSoft)),
            ),
          ],
        ),
      ),
    );
  }
}

enum ScanAction { showMyQr, scanAgain }

/// Bottom sheet explaining what was scanned.
Future<ScanAction?> showScanResult(BuildContext context, ScanResult result) {
  return showModalBottomSheet<ScanAction>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ScanResultSheet(result: result),
  );
}

class _ScanResultSheet extends StatelessWidget {
  const _ScanResultSheet({required this.result});

  final ScanResult result;

  @override
  Widget build(BuildContext context) {
    void close(ScanAction action) => Navigator.of(context).pop(action);
    final now = DateTime.now();

    final content = switch (result) {
      ScannedPlace(:final place) => _SheetContent(
          icon: PlaceBadge(place: place, size: 56),
          eyebrow: 'Local Condevuelta',
          title: place.name,
          subtitle: place.address,
          chips: [
            _Chip(place.isOpen ? 'Abierto' : 'Cerrado', place.isOpen ? AppColors.green.withValues(alpha: 0.3) : AppColors.hairline),
            if (place.requiresGuarantee) const _Chip('Pide garantía por envase', AppColors.pinkMist),
          ],
          body: 'Aquí puedes pedir tu comida en retornable. Muestra tu QR al pagar y el envase queda a tu nombre.',
          primaryLabel: 'Mostrar mi QR',
          onPrimary: () => close(ScanAction.showMyQr),
          secondaryLabel: 'Seguir escaneando',
          onSecondary: () => close(ScanAction.scanAgain),
        ),
      ScannedContainer(:final myLoan?) => _SheetContent(
          icon: const _IconBadge(Icons.takeout_dining_rounded, AppColors.lime),
          eyebrow: 'Envase · ${myLoan.containerCode}',
          title: myLoan.containerType,
          subtitle: 'Lo tienes tú',
          chips: [_Chip(formatDaysLeft(myLoan.daysLeft(now)), isUrgent(myLoan, now) ? AppColors.pinkMist : AppColors.green.withValues(alpha: 0.3))],
          body: 'Devuélvelo en ${returnPlacesLabel(myLoan)} antes del ${formatLongDate(myLoan.dueDate)}.',
          primaryLabel: 'Entendido',
          onPrimary: () => close(ScanAction.scanAgain),
        ),
      ScannedContainer container => _SheetContent(
          icon: const _IconBadge(Icons.takeout_dining_rounded, AppColors.pinkMist),
          eyebrow: 'Envase · ${container.code}',
          title: container.containerType,
          subtitle: 'De ${container.place.name}',
          chips: [
            if (container.isAvailable)
              _Chip('Disponible', AppColors.green.withValues(alpha: 0.3))
            else if (container.status == 'loaned')
              const _Chip('En uso', AppColors.yellow)
            else
              const _Chip('Fuera de circulación', AppColors.hairline),
          ],
          body: container.isAvailable
              ? 'Pídelo en ${container.place.name} en tu próxima compra y muestra tu QR en caja.'
              : 'Este envase no está disponible. Si lo encontraste, llévalo a ${container.place.name}.',
          primaryLabel: container.isAvailable ? 'Mostrar mi QR' : 'Entendido',
          onPrimary: () => close(container.isAvailable ? ScanAction.showMyQr : ScanAction.scanAgain),
          secondaryLabel: container.isAvailable ? 'Seguir escaneando' : null,
          onSecondary: () => close(ScanAction.scanAgain),
        ),
      ScannedCustomer() => _SheetContent(
          icon: const _IconBadge(Icons.person_rounded, AppColors.skyMist),
          eyebrow: 'QR de cliente',
          title: 'Este QR es de otra persona',
          body: 'Solo el local puede escanearlo para asociarle un envase.',
          primaryLabel: 'Seguir escaneando',
          onPrimary: () => close(ScanAction.scanAgain),
        ),
      ScannedUnknown() => _SheetContent(
          icon: const _IconBadge(Icons.help_outline_rounded, AppColors.yellow),
          eyebrow: 'QR desconocido',
          title: 'No reconocemos este QR',
          body: 'Escanea el QR de un local o de un envase Condevuelta.',
          primaryLabel: 'Seguir escaneando',
          onPrimary: () => close(ScanAction.scanAgain),
        ),
    };

    return Container(
      padding: EdgeInsets.fromLTRB(24, 12, 24, 20 + MediaQuery.paddingOf(context).bottom),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: content,
    );
  }
}

class _SheetContent extends StatelessWidget {
  const _SheetContent({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    this.subtitle,
    this.chips = const [],
    this.secondaryLabel,
    this.onSecondary,
  });

  final Widget icon;
  final String eyebrow;
  final String title;
  final String? subtitle;
  final List<Widget> chips;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(color: AppColors.hairline, borderRadius: BorderRadius.circular(3)),
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.6, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: AppMotion.bouncy,
              builder: (context, v, child) => Transform.scale(scale: v, child: child),
              child: icon,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(eyebrow, style: AppText.caption),
                  Text(title, style: AppText.headline),
                  if (subtitle != null) Text(subtitle!, style: AppText.caption.copyWith(color: AppColors.navy)),
                ],
              ),
            ),
          ],
        ),
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
        ],
        const SizedBox(height: 14),
        Text(body, style: AppText.body),
        const SizedBox(height: 22),
        PrimaryButton(label: primaryLabel, onPressed: onPrimary),
        if (secondaryLabel != null) ...[
          const SizedBox(height: 6),
          Center(
            child: Pressable(
              onTap: onSecondary,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(secondaryLabel!, style: AppText.label.copyWith(color: AppColors.pink)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: AppText.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.navy)),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge(this.icon, this.color);

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
      child: Icon(icon, color: AppColors.navy, size: 28),
    );
  }
}
