import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/brand.dart';
import '../widgets/pressable.dart';
import '../widgets/primary_button.dart';

/// Shared layout for the sign-in steps: back button, content, bottom action.
class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.action,
    this.onBack,
    this.footer,
  });

  final String title;
  final Widget subtitle;
  final Widget child;
  final Widget action;
  final VoidCallback? onBack;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final error = AppScope.of(context).errorMessage;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            Positioned(
              right: -70,
              top: -60,
              child: Container(
                width: 240,
                height: 240,
                decoration: const BoxDecoration(color: AppColors.pinkMist, shape: BoxShape.circle),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 52,
                      child: Row(
                        children: [
                          if (onBack != null)
                            Pressable(
                              onTap: onBack,
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.hairline),
                                ),
                                child: const Icon(Icons.arrow_back_rounded, color: AppColors.navy, size: 22),
                              ),
                            ),
                          const Spacer(),
                          const BrandMark(width: 46),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(top: 36),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Entrance(child: Text(title, style: AppText.hero)),
                            const SizedBox(height: 12),
                            _Entrance(delay: 0.08, child: subtitle),
                            const SizedBox(height: 28),
                            _Entrance(delay: 0.16, child: child),
                            AnimatedSize(
                              duration: AppMotion.fast,
                              child: error == null
                                  ? const SizedBox(width: double.infinity)
                                  : Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.info_outline_rounded, color: AppColors.pink, size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(error, style: AppText.caption.copyWith(color: AppColors.pink)),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    action,
                    if (footer != null) ...[const SizedBox(height: 14), Center(child: footer!)],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fade + rise on first build, staggered by [delay] (0..1 of the duration).
class _Entrance extends StatelessWidget {
  const _Entrance({required this.child, this.delay = 0});

  final Widget child;
  final double delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Interval(delay, 1, curve: AppMotion.emphasized),
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 18 * (1 - v)), child: child),
      ),
      child: child,
    );
  }
}

InputDecoration _fieldDecoration(String hint) {
  OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: AppText.body.copyWith(fontSize: 17, color: AppColors.navy.withValues(alpha: 0.35)),
    filled: true,
    fillColor: AppColors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 19),
    enabledBorder: border(AppColors.hairline),
    focusedBorder: border(AppColors.pink.withValues(alpha: 0.55), 1.6),
  );
}

const _fieldText = TextStyle(fontFamily: AppText.bodyFamily, fontSize: 17, color: AppColors.navy);

class EmailScreen extends StatefulWidget {
  const EmailScreen({super.key});

  @override
  State<EmailScreen> createState() => _EmailScreenState();
}

class _EmailScreenState extends State<EmailScreen> {
  late final _controller = TextEditingController(text: AppScope.read(context).email);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => AppScope.read(context).requestCode(_controller.text);

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return _AuthScaffold(
      onBack: () => state.backTo(AppStage.onboarding),
      title: '¿Cuál es tu email?',
      subtitle: const Text('Te enviamos un código para entrar. Sin contraseñas.', style: AppText.body),
      action: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => PrimaryButton(
          label: 'Enviarme el código',
          isLoading: state.isBusy,
          onPressed: _controller.text.trim().isEmpty ? null : _submit,
        ),
      ),
      footer: Text.rich(
        TextSpan(
          style: AppText.caption,
          children: [
            const TextSpan(text: 'Al continuar aceptas los '),
            TextSpan(text: 'Términos', style: AppText.caption.copyWith(color: AppColors.pink, fontWeight: FontWeight.w500)),
            const TextSpan(text: ' y la '),
            TextSpan(text: 'Política de privacidad', style: AppText.caption.copyWith(color: AppColors.pink, fontWeight: FontWeight.w500)),
          ],
        ),
        textAlign: TextAlign.center,
      ),
      child: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        textInputAction: TextInputAction.send,
        autocorrect: false,
        onSubmitted: (_) => _submit(),
        style: _fieldText,
        decoration: _fieldDecoration('tu@email.com'),
      ),
    );
  }
}

class CodeScreen extends StatefulWidget {
  const CodeScreen({super.key});

  @override
  State<CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends State<CodeScreen> with SingleTickerProviderStateMixin {
  static const _length = 6;
  static const _resendSeconds = 30;

  final _controller = TextEditingController();
  final _focus = FocusNode();
  late final _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  Timer? _timer;
  int _secondsLeft = _resendSeconds;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _focus.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) timer.cancel();
      setState(() => _secondsLeft--);
    });
  }

  Future<void> _onChanged() async {
    setState(() {});
    if (_controller.text.length != _length) return;
    HapticFeedback.lightImpact();
    final ok = await AppScope.read(context).verifyCode(_controller.text);
    if (!ok && mounted) {
      HapticFeedback.heavyImpact();
      _shake.forward(from: 0);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final code = _controller.text;
    return _AuthScaffold(
      onBack: () => state.backTo(AppStage.email),
      title: 'Revisa tu correo',
      subtitle: Text.rich(
        TextSpan(
          style: AppText.body,
          children: [
            const TextSpan(text: 'Te enviamos un código de 6 dígitos a '),
            TextSpan(text: state.email, style: AppText.body.copyWith(color: AppColors.navy, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
      action: Center(
        child: Pressable(
          onTap: _secondsLeft > 0
              ? null
              : () {
                  state.resendCode();
                  _startTimer();
                },
          child: SizedBox(
            height: 48,
            child: Center(
              child: Text(
                _secondsLeft > 0 ? 'Reenviar código en 0:${_secondsLeft.toString().padLeft(2, '0')}' : 'Reenviar código',
                style: AppText.label.copyWith(color: _secondsLeft > 0 ? AppColors.muted : AppColors.pink),
              ),
            ),
          ),
        ),
      ),
      child: GestureDetector(
        onTap: () => _focus.requestFocus(),
        child: AnimatedBuilder(
          animation: _shake,
          builder: (context, child) {
            final t = _shake.value;
            return Transform.translate(offset: Offset(sin(t * pi * 5) * 12 * (1 - t), 0), child: child);
          },
          child: Stack(
            children: [
              Opacity(
                opacity: 0,
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(_length)],
                  enabled: !state.isBusy,
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < _length; i++) ...[
                    if (i > 0) SizedBox(width: i == 3 ? 16 : 8),
                    Expanded(child: _CodeBox(digit: i < code.length ? code[i] : null, isActive: i == code.length && !state.isBusy)),
                  ],
                ],
              ),
              if (state.isBusy)
                const Positioned.fill(
                  child: Center(
                    child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.6, color: AppColors.pink)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({required this.digit, required this.isActive});

  final String? digit;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final filled = digit != null;
    return AnimatedContainer(
      duration: AppMotion.fast,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? AppColors.pinkMist : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? AppColors.pink : (filled ? AppColors.pinkSoft : AppColors.hairline),
          width: isActive ? 2 : 1,
        ),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: AppMotion.bouncy),
          child: child,
        ),
        child: filled
            ? Text(digit!, key: ValueKey(digit), style: AppText.title.copyWith(fontSize: 30))
            : (isActive ? const _Caret() : const SizedBox.shrink()),
      ),
    );
  }
}

class _Caret extends StatefulWidget {
  const _Caret();

  @override
  State<_Caret> createState() => _CaretState();
}

class _CaretState extends State<_Caret> with SingleTickerProviderStateMixin {
  late final _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _blink,
      child: Container(width: 2, height: 26, color: AppColors.pink),
    );
  }
}

class NameScreen extends StatefulWidget {
  const NameScreen({super.key});

  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => AppScope.read(context).saveName(_controller.text);

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return _AuthScaffold(
      title: '¿Cómo te llamamos?',
      subtitle: const Text('Así te saludan en caja cuando muestres tu carnet.', style: AppText.body),
      action: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => PrimaryButton(
          label: 'Crear mi carnet',
          isLoading: state.isBusy,
          onPressed: _controller.text.trim().isEmpty ? null : _submit,
        ),
      ),
      child: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        autofillHints: const [AutofillHints.name],
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        style: _fieldText,
        decoration: _fieldDecoration('Tu nombre'),
      ),
    );
  }
}
