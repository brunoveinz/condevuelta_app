import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../data/api_client.dart';
import '../../data/operator_models.dart';
import '../../data/repository.dart';
import '../../state/operator_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/money.dart';
import '../../widgets/pressable.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/scanner_overlay.dart';
import 'lend_review_sheet.dart';
import 'operator_widgets.dart';

enum CounterMode { lend, receive }

/// Opens the counter (raised tab bar button and home shortcuts).
Future<void> openCounter(BuildContext context, {CounterMode mode = CounterMode.lend}) async {
  final controller = OperatorScope.read(context);
  if (!controller.profile.canOperate) {
    showOperatorToast(
      context,
      controller.profile.local.blocked ? 'Tu local está en pausa.' : 'Los préstamos están apagados en tu local.',
      isError: true,
    );
    return;
  }
  HapticFeedback.mediumImpact();
  await pushOperatorPage<void>(context, CounterScreen(initialMode: mode));
}

/// The counter: a live scanner that lends (customer carnet + containers) or
/// takes containers back, one scan after the other without leaving the camera.
class CounterScreen extends StatefulWidget {
  const CounterScreen({super.key, this.initialMode = CounterMode.lend});

  final CounterMode initialMode;

  @override
  State<CounterScreen> createState() => _CounterScreenState();
}

class _Banner {
  const _Banner(this.message, {this.isError = false, this.actionLabel, this.onAction});

  final String message;
  final bool isError;
  final String? actionLabel;
  final VoidCallback? onAction;
}

class _CounterScreenState extends State<CounterScreen> with SingleTickerProviderStateMixin {
  /// The same QR read again within this window is ignored (the camera keeps firing).
  static const _repeatWindow = Duration(milliseconds: 2500);

  late CounterMode _mode = widget.initialMode;
  final _scanner = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);
  final _recent = <String, DateTime>{};

  CarnetCustomer? _customer;
  final _items = <StockContainer>[];

  /// Kept across retries of the same checkout; reset when the checkout changes.
  String? _requestId;
  final _received = <ReturnResult>[];
  List<OperatorLoan>? _lent;

  bool _busy = false;
  bool _torchOn = false;
  bool _changedLoans = false;
  _Banner? _banner;
  Timer? _bannerTimer;
  Color? _flash;
  Timer? _flashTimer;

  late OperatorController _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = OperatorScope.read(context);
  }

  @override
  void dispose() {
    // Home counters and the list catch up once, when the counter closes.
    if (_changedLoans) _controller.loansChanged();
    _bannerTimer?.cancel();
    _flashTimer?.cancel();
    _pulse.dispose();
    _scanner.dispose();
    super.dispose();
  }

  void _setMode(CounterMode mode) {
    if (mode == _mode) return;
    HapticFeedback.selectionClick();
    setState(() {
      _mode = mode;
      _banner = null;
    });
  }

  void _showBanner(_Banner banner) {
    _bannerTimer?.cancel();
    setState(() => _banner = banner);
    _bannerTimer = Timer(Duration(milliseconds: banner.onAction == null ? 2600 : 5000), () {
      if (mounted) setState(() => _banner = null);
    });
  }

  void _flashCorners(Color color) {
    _flashTimer?.cancel();
    setState(() => _flash = color);
    _flashTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _flash = null);
    });
  }

  void _success(String? message) {
    HapticFeedback.mediumImpact();
    _flashCorners(AppColors.lime);
    if (message != null) _showBanner(_Banner(message));
  }

  void _error(String message, {String? actionLabel, VoidCallback? onAction}) {
    HapticFeedback.heavyImpact();
    _flashCorners(AppColors.pink);
    _showBanner(_Banner(message, isError: true, actionLabel: actionLabel, onAction: onAction));
  }

  void _onDetect(BarcodeCapture capture) {
    if (_lent != null) return;
    final raw = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    if (raw == null) return;
    final now = DateTime.now();
    final last = _recent[raw];
    if (last != null && now.difference(last) < _repeatWindow) return;
    _recent[raw] = now;
    _handle(raw);
  }

  Future<void> _handle(String raw) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (_mode == CounterMode.lend) {
        await _handleLendScan(raw);
      } else {
        await _handleReceiveScan(raw);
      }
    } on ApiException catch (e) {
      if (mounted) _error(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleLendScan(String raw) async {
    final result = await _controller.scan(raw);
    if (!mounted) return;
    switch (result) {
      case ScannedCarnet(:final customer):
        if (_customer?.carnetToken == customer.carnetToken) {
          _showBanner(_Banner('${customer.displayName} ya está en este préstamo.'));
          return;
        }
        final replaced = _customer != null;
        setState(() {
          _customer = customer;
          _requestId = null;
        });
        if (customer.remainingLoans == 0) {
          _error(
            '${customer.displayName} ya tiene ${customer.activeLoans} de ${customer.maxActiveLoans} préstamos activos.',
          );
        } else {
          _success(replaced ? 'Cambiaste el cliente a ${customer.displayName}.' : null);
        }
      case ScannedStock(:final container):
        if (!container.belongsToLocal) {
          _error('Ese envase es de otro local.');
        } else if (_items.any((c) => c.code == container.code)) {
          _showBanner(_Banner('${container.code} ya está en la lista.'));
        } else if (container.openLoan != null) {
          _error(
            '${container.code} está prestado a ${container.openLoan!.customerName}.',
            actionLabel: 'Recibirlo',
            onAction: () {
              _setMode(CounterMode.receive);
              _handle(container.code);
            },
          );
        } else if (!container.isAvailable) {
          _error('${container.code} está fuera de circulación y no se puede prestar.');
        } else {
          setState(() {
            _items.add(container);
            _requestId = null;
          });
          _success(null);
        }
      case ScannedNothing():
        _error('No reconocemos este QR. Escanea un carnet o un envase.');
    }
  }

  Future<void> _handleReceiveScan(String raw) async {
    if (raw.trim().toUpperCase().startsWith('CDV-')) {
      _error('Eso es un carnet. Para recibir, escanea el envase.');
      return;
    }
    final result = await _controller.returnContainer(raw);
    if (!mounted) return;
    _changedLoans = true;
    // A repeated scan keeps the first result ("A tiempo", "2 días tarde").
    final seen = _received.any((r) => r.loan.id == result.loan.id);
    if (!seen) setState(() => _received.insert(0, result));
    if (result.alreadyReturned) {
      _showBanner(_Banner('${result.loan.containerCode} ya estaba recibido.'));
    } else {
      _success(null);
    }
  }

  void _removeItem(StockContainer item) {
    HapticFeedback.selectionClick();
    setState(() {
      _items.remove(item);
      _requestId = null;
    });
  }

  void _removeCustomer() {
    HapticFeedback.selectionClick();
    setState(() {
      _customer = null;
      _requestId = null;
    });
  }

  Future<void> _manualEntry() async {
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ManualCodeSheet(receiving: _mode == CounterMode.receive),
    );
    if (code != null && code.trim().isNotEmpty && mounted) await _handle(code.trim());
  }

  Future<void> _toggleTorch() async {
    HapticFeedback.selectionClick();
    await _scanner.toggleTorch();
    if (mounted) setState(() => _torchOn = !_torchOn);
  }

  Future<void> _review() async {
    final controller = _controller;
    final requestId = _requestId ??= newRequestId();
    unawaited(_scanner.stop());
    final loans = await showModalBottomSheet<List<OperatorLoan>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OperatorScope(
        controller: controller,
        child: LendReviewSheet(
          requestId: requestId,
          customer: _customer,
          containers: List.of(_items),
          rules: controller.profile.rules,
        ),
      ),
    );
    if (!mounted) return;
    if (loans == null) {
      unawaited(_scanner.start());
      return;
    }
    HapticFeedback.heavyImpact();
    _changedLoans = true;
    setState(() => _lent = loans);
  }

  void _startOver() {
    setState(() {
      _lent = null;
      _customer = null;
      _items.clear();
      _requestId = null;
      _banner = null;
      _recent.clear();
    });
    unawaited(_scanner.start());
  }

  @override
  Widget build(BuildContext context) {
    final lent = _lent;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.navy,
        resizeToAvoidBottomInset: false,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 420),
          switchInCurve: AppMotion.emphasized,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(animation), child: child),
          ),
          child: lent != null
              ? LendSuccessView(
                  key: const ValueKey('success'),
                  loans: lent,
                  customerName: _customer?.displayName,
                  onNewLoan: _startOver,
                  onDone: () => Navigator.of(context).pop(),
                )
              : SafeArea(key: const ValueKey('counter'), child: _buildCounter()),
        ),
      ),
    );
  }

  Widget _buildCounter() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SizedBox(
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _ModeSwitch(mode: _mode, onChanged: _setMode),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _RoundIconButton(icon: Icons.close_rounded, onTap: () => Navigator.of(context).pop()),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 11,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _scanner,
                    onDetect: _onDetect,
                    errorBuilder: (context, error) => _CameraError(error: error, onManualEntry: _manualEntry),
                  ),
                  IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _pulse,
                      builder: (context, _) => LayoutBuilder(
                        builder: (context, constraints) => CustomPaint(
                          painter: ScannerOverlayPainter(
                            cutout: (constraints.biggest.shortestSide * 0.62).clamp(150.0, 240.0),
                            pulse: Curves.easeInOut.transform(_pulse.value),
                            color: _flash ?? (_mode == CounterMode.lend ? AppColors.pink : AppColors.lime),
                            offsetY: 0,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    top: 14,
                    child: AnimatedSwitcher(
                      duration: AppMotion.fast,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(begin: const Offset(0, -0.3), end: Offset.zero).animate(animation),
                          child: child,
                        ),
                      ),
                      child: _banner == null
                          ? _ScanHint(key: const ValueKey('hint'), mode: _mode, hasCustomer: _customer != null)
                          : _BannerView(key: ValueKey(_banner), banner: _banner!),
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
                    left: 14,
                    bottom: 14,
                    child: _RoundIconButton(
                      icon: Icons.keyboard_rounded,
                      label: 'Código',
                      onTap: _manualEntry,
                      filled: true,
                    ),
                  ),
                  Positioned(
                    right: 14,
                    bottom: 14,
                    child: _RoundIconButton(
                      icon: _torchOn ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
                      onTap: _toggleTorch,
                      filled: true,
                      highlighted: _torchOn,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          flex: 10,
          child: Container(
            margin: const EdgeInsets.only(top: 14),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 360),
              switchInCurve: AppMotion.emphasized,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(
                    begin: Offset(child.key == const ValueKey(CounterMode.lend) ? -0.08 : 0.08, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: _mode == CounterMode.lend
                  ? _LendPanel(
                      key: const ValueKey(CounterMode.lend),
                      customer: _customer,
                      items: _items,
                      onRemoveCustomer: _removeCustomer,
                      onRemoveItem: _removeItem,
                      onReview: _items.isEmpty ? null : _review,
                    )
                  : _ReceivePanel(
                      key: const ValueKey(CounterMode.receive),
                      received: _received,
                      onDone: () => Navigator.of(context).pop(),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Segmented control "Prestar | Recibir" with a sliding pill.
class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.mode, required this.onChanged});

  static const _segmentWidth = 108.0;
  static const _height = 40.0;

  final CounterMode mode;
  final ValueChanged<CounterMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final lend = mode == CounterMode.lend;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(24)),
      child: SizedBox(
        width: _segmentWidth * 2,
        height: _height,
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: AppMotion.medium,
              curve: AppMotion.emphasized,
              left: lend ? 0 : _segmentWidth,
              top: 0,
              width: _segmentWidth,
              height: _height,
              child: AnimatedContainer(
                duration: AppMotion.medium,
                decoration: BoxDecoration(
                  color: lend ? AppColors.pink : AppColors.lime,
                  borderRadius: BorderRadius.circular(_height / 2),
                ),
              ),
            ),
            Row(
              children: [
                _segment('Prestar', Icons.outbox_rounded, CounterMode.lend, AppColors.white),
                _segment('Recibir', Icons.move_to_inbox_rounded, CounterMode.receive, AppColors.navy),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _segment(String label, IconData icon, CounterMode value, Color selectedColor) {
    final selected = value == mode;
    final color = selected ? selectedColor : AppColors.white.withValues(alpha: 0.65);
    return SizedBox(
      width: _segmentWidth,
      height: _height,
      child: Pressable(
        onTap: () => onChanged(value),
        child: ColoredBox(
          color: Colors.transparent,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18, color: color),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      maxLines: 1,
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

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.label,
    this.filled = false,
    this.highlighted = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? label;
  final bool filled;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final background = highlighted
        ? AppColors.yellow
        : filled
        ? AppColors.navy.withValues(alpha: 0.72)
        : AppColors.white.withValues(alpha: 0.12);
    final foreground = highlighted ? AppColors.navy : AppColors.white;
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 44,
        constraints: const BoxConstraints(minWidth: 44),
        padding: EdgeInsets.symmetric(horizontal: label == null ? 0 : 14),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(22)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: foreground, size: 21),
            if (label != null) ...[
              const SizedBox(width: 6),
              Text(
                label!,
                style: AppText.caption.copyWith(color: foreground, fontWeight: FontWeight.w500),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScanHint extends StatelessWidget {
  const _ScanHint({super.key, required this.mode, required this.hasCustomer});

  final CounterMode mode;
  final bool hasCustomer;

  @override
  Widget build(BuildContext context) {
    final text = switch (mode) {
      CounterMode.lend when hasCustomer => 'Ahora escanea los envases',
      CounterMode.lend => 'Escanea el carnet del cliente y los envases',
      CounterMode.receive => 'Escanea cada envase que te devuelven',
    };
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.navy.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          text,
          style: AppText.caption.copyWith(color: AppColors.white),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _BannerView extends StatelessWidget {
  const _BannerView({super.key, required this.banner});

  final _Banner banner;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(14, 10, banner.onAction == null ? 14 : 6, 10),
      decoration: BoxDecoration(
        color: banner.isError ? AppColors.pink : AppColors.navy.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Row(
        children: [
          Icon(
            banner.isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            color: AppColors.white,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              banner.message,
              style: AppText.caption.copyWith(color: AppColors.white, fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ),
          if (banner.onAction != null)
            Pressable(
              onTap: banner.onAction,
              child: Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(14)),
                child: Text(
                  banner.actionLabel!,
                  style: AppText.caption.copyWith(color: AppColors.pinkDark, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Lend: the customer (optional) and the containers going out.
class _LendPanel extends StatelessWidget {
  const _LendPanel({
    super.key,
    required this.customer,
    required this.items,
    required this.onRemoveCustomer,
    required this.onRemoveItem,
    required this.onReview,
  });

  final CarnetCustomer? customer;
  final List<StockContainer> items;
  final VoidCallback onRemoveCustomer;
  final ValueChanged<StockContainer> onRemoveItem;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final guarantee = items.fold<int>(0, (sum, c) => sum + c.guaranteeValue);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSwitcher(
          duration: AppMotion.medium,
          switchInCurve: AppMotion.bouncy,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(animation), child: child),
          ),
          child: customer == null
              ? const _CustomerPlaceholder(key: ValueKey('no-customer'))
              : _CustomerCard(key: ValueKey(customer!.carnetToken), customer: customer!, onRemove: onRemoveCustomer),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text('Envases', style: AppText.label.copyWith(fontSize: 16)),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: AppMotion.fast,
              transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
              child: Container(
                key: ValueKey(items.length),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                decoration: BoxDecoration(
                  color: items.isEmpty ? AppColors.hairline : AppColors.navy,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${items.length}',
                  style: AppText.caption.copyWith(
                    color: items.isEmpty ? AppColors.muted : AppColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const Spacer(),
            if (guarantee > 0) Text('Garantía ${formatClp(guarantee)}', style: AppText.caption),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: items.isEmpty
              ? Align(
                  alignment: Alignment.topLeft,
                  child: Text('Escanea los envases que vas a prestar. Puedes agregar varios.', style: AppText.caption),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final item = items[items.length - 1 - i];
                    return _ContainerChip(key: ValueKey(item.code), item: item, onRemove: () => onRemoveItem(item));
                  },
                ),
        ),
        const SizedBox(height: 10),
        PrimaryButton(
          label: items.isEmpty ? 'Revisar préstamo' : 'Revisar préstamo (${items.length})',
          onPressed: onReview,
        ),
      ],
    );
  }
}

class _CustomerPlaceholder extends StatelessWidget {
  const _CustomerPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.skyMist, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.badge_outlined, color: AppColors.navy),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Carnet del cliente', style: AppText.label),
                Text('Opcional: sin carnet queda como préstamo sin cliente.', style: AppText.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({super.key, required this.customer, required this.onRemove});

  final CarnetCustomer customer;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final atLimit = customer.remainingLoans == 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: atLimit ? AppColors.pinkSoft : AppColors.green, width: 1.5),
      ),
      child: Row(
        children: [
          InitialAvatar(initial: customer.initial, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.label.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _MiniChip(
                      '${customer.activeLoans}/${customer.maxActiveLoans} activos',
                      atLimit ? AppColors.pinkMist : AppColors.background,
                    ),
                    if (customer.isNewInLocal) const _MiniChip('Nuevo en tu local', AppColors.skyMist),
                    if (customer.hasCard) _MiniChip('Tarjeta guardada', AppColors.green.withValues(alpha: 0.3)),
                  ],
                ),
              ],
            ),
          ),
          Pressable(
            onTap: onRemove,
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(Icons.close_rounded, size: 20, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
      child: Text(
        label,
        style: AppText.caption.copyWith(fontSize: 11.5, fontWeight: FontWeight.w500, color: AppColors.navy),
      ),
    );
  }
}

class _ContainerChip extends StatelessWidget {
  const _ContainerChip({super.key, required this.item, required this.onRemove});

  final StockContainer item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: AppMotion.bouncy,
      builder: (context, v, child) => Transform.scale(
        scale: v,
        child: Opacity(opacity: v.clamp(0, 1), child: child),
      ),
      child: Container(
        width: 132,
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
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
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: AppColors.pinkMist, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.takeout_dining_rounded, size: 18, color: AppColors.pink),
                ),
                const Spacer(),
                Pressable(
                  onTap: onRemove,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded, size: 18, color: AppColors.muted),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              item.containerType,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.label.copyWith(fontSize: 14),
            ),
            Text(
              item.code,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(fontSize: 12, letterSpacing: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Receive: what came back during this visit to the counter.
class _ReceivePanel extends StatelessWidget {
  const _ReceivePanel({super.key, required this.received, required this.onDone});

  final List<ReturnResult> received;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Recibidos ahora', style: AppText.label.copyWith(fontSize: 16)),
            const SizedBox(width: 8),
            if (received.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(10)),
                child: Text(
                  '${received.length}',
                  style: AppText.caption.copyWith(color: AppColors.white, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: received.isEmpty
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: AppColors.lime, borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.move_to_inbox_rounded, color: AppColors.navy),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Escanea el envase y queda recibido al instante: vuelve a estar disponible para prestar.',
                        style: AppText.caption,
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: received.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _ReceivedTile(key: ValueKey(received[i].loan.id), result: received[i]),
                ),
        ),
        const SizedBox(height: 10),
        PrimaryButton(label: 'Listo', showArrow: false, color: AppColors.navy, onPressed: onDone),
      ],
    );
  }
}

class _ReceivedTile extends StatelessWidget {
  const _ReceivedTile({super.key, required this.result});

  final ReturnResult result;

  @override
  Widget build(BuildContext context) {
    final loan = result.loan;
    final late = loan.returnedAt != null ? loan.returnedAt!.difference(loan.dueDate).inDays : 0;
    final (label, color) = result.alreadyReturned
        ? ('Ya estaba recibido', AppColors.hairline)
        : late > 0
        ? ('$late ${late == 1 ? 'día' : 'días'} tarde', AppColors.pinkMist)
        : ('A tiempo', AppColors.green.withValues(alpha: 0.3));
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: AppMotion.emphasized,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, -12 * (1 - v)), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Row(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.3, end: 1),
              duration: const Duration(milliseconds: 650),
              curve: AppMotion.bouncy,
              builder: (context, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(color: AppColors.lime, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: AppColors.navy, size: 22),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${loan.containerType} · ${loan.containerCode}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.label.copyWith(fontSize: 14),
                  ),
                  Text(
                    loan.customerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
              child: Text(
                label,
                style: AppText.caption.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.navy),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Type a code when a QR is worn out or the camera can't read it.
class _ManualCodeSheet extends StatefulWidget {
  const _ManualCodeSheet({required this.receiving});

  final bool receiving;

  @override
  State<_ManualCodeSheet> createState() => _ManualCodeSheetState();
}

class _ManualCodeSheetState extends State<_ManualCodeSheet> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    if (_text.text.trim().isEmpty) return;
    Navigator.of(context).pop(_text.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 12, 24, 20 + bottom),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const SizedBox(height: 20),
          Text('Escribe el código', style: AppText.headline),
          const SizedBox(height: 4),
          Text(
            widget.receiving ? 'El código impreso en el envase que te devuelven.' : 'El código impreso en el envase.',
            style: AppText.body,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _text,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            style: AppText.headline.copyWith(letterSpacing: 2),
            decoration: InputDecoration(
              hintText: 'BW-0012',
              hintStyle: AppText.headline.copyWith(color: AppColors.navy.withValues(alpha: 0.2), letterSpacing: 2),
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder(
            valueListenable: _text,
            builder: (context, value, _) => PrimaryButton(
              label: widget.receiving ? 'Recibir' : 'Agregar',
              color: widget.receiving ? AppColors.navy : AppColors.pink,
              onPressed: value.text.trim().isEmpty ? null : _submit,
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.error, required this.onManualEntry});

  final MobileScannerException error;
  final VoidCallback onManualEntry;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: const Color(0xFF151B36),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.no_photography_rounded, size: 44, color: AppColors.white.withValues(alpha: 0.8)),
            const SizedBox(height: 12),
            Text(
              'No podemos usar la cámara',
              style: AppText.headline.copyWith(color: AppColors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              denied
                  ? 'Dale permiso en Ajustes › Condevuelta › Cámara.'
                  : 'Revisa que tu teléfono tenga una cámara disponible.',
              style: AppText.caption.copyWith(color: AppColors.white.withValues(alpha: 0.75)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Pressable(
              onTap: onManualEntry,
              child: Text('Escribir el código', style: AppText.label.copyWith(color: AppColors.pinkSoft)),
            ),
          ],
        ),
      ),
    );
  }
}
