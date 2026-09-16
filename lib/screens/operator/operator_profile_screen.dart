import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../state/app_state.dart';
import '../../state/operator_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand.dart';
import '../../widgets/pressable.dart';
import 'operator_widgets.dart';

/// The operator, their local's loan rules, the switch to their own carnet
/// and sign out.
class OperatorProfileScreen extends StatefulWidget {
  const OperatorProfileScreen({super.key});

  @override
  State<OperatorProfileScreen> createState() => _OperatorProfileScreenState();
}

class _OperatorProfileScreenState extends State<OperatorProfileScreen> {
  bool _switching = false;

  Future<void> _openCarnet() async {
    final app = AppScope.read(context);
    final navigator = Navigator.of(context);
    setState(() => _switching = true);
    await app.switchToCustomer();
    if (!mounted) return;
    setState(() => _switching = false);
    if (app.errorMessage != null) {
      showOperatorToast(context, app.errorMessage!, isError: true, bottom: 24);
      return;
    }
    navigator.popUntil((route) => route.isFirst);
  }

  void _signOut() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    AppScope.read(context).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final profile = OperatorScope.of(context).profile;
    final rules = profile.rules;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Pressable(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: const Icon(Icons.arrow_back_rounded, color: AppColors.navy),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: InitialAvatar(
                  initial: profile.initial,
                  size: 92,
                  background: AppColors.navy,
                  foreground: AppColors.white,
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  profile.fullName.isEmpty ? 'Operador' : profile.fullName,
                  style: AppText.title,
                  textAlign: TextAlign.center,
                ),
              ),
              Center(
                child: Text(
                  [if (profile.roleTitle.isNotEmpty) profile.roleTitle, profile.email].join(' · '),
                  style: AppText.body,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(26)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.storefront_rounded, color: AppColors.lime),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(profile.local.name, style: AppText.headline.copyWith(color: AppColors.white)),
                        ),
                      ],
                    ),
                    if (profile.local.address.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        profile.local.address,
                        style: AppText.caption.copyWith(color: AppColors.white.withValues(alpha: 0.7)),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _Rule(
                          value: '${rules.maxLoanDays}',
                          label: rules.maxLoanDays == 1 ? 'día de\npréstamo' : 'días de\npréstamo',
                        ),
                        _Rule(value: '${rules.maxActiveLoansPerCustomer}', label: 'envases por\ncliente'),
                        _Rule(
                          icon: rules.requireGuarantee ? Icons.shield_rounded : Icons.handshake_rounded,
                          label: rules.requireGuarantee ? 'pide\ngarantía' : 'sin garantía\nobligatoria',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Estas reglas se cambian desde la configuración del local en el panel web.',
                      style: AppText.caption.copyWith(color: AppColors.white.withValues(alpha: 0.55), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Column(
                  children: [
                    if (profile.canSwitchToCustomer) ...[
                      _Row(
                        icon: Icons.qr_code_2_rounded,
                        label: 'Usar mi carnet de cliente',
                        detail: 'Pide retornables en otros locales',
                        loading: _switching,
                        onTap: _switching ? null : _openCarnet,
                      ),
                      const Divider(height: 1, indent: 58, color: AppColors.hairline),
                    ],
                    _Row(
                      icon: Icons.auto_awesome_rounded,
                      label: 'Ver el tutorial',
                      onTap: () {
                        Navigator.of(context).popUntil((route) => route.isFirst);
                        AppScope.read(context).replayTutorial();
                      },
                    ),
                    const Divider(height: 1, indent: 58, color: AppColors.hairline),
                    _Row(icon: Icons.logout_rounded, label: 'Cerrar sesión', onTap: _signOut, color: AppColors.pink),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Center(
                child: Column(
                  children: [
                    const BrandMark(width: 40),
                    const SizedBox(height: 6),
                    Text('Condevuelta para locales · versión 1.0.0', style: AppText.caption),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.label, this.value, this.icon});

  final String label;
  final String? value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 34,
            child: value != null
                ? Text(value!, style: AppText.hero.copyWith(color: AppColors.white, fontSize: 32))
                : Icon(icon, color: AppColors.lime, size: 28),
          ),
          Text(
            label,
            style: AppText.caption.copyWith(color: AppColors.white.withValues(alpha: 0.75), fontSize: 12, height: 1.2),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.onTap,
    this.detail,
    this.loading = false,
    this.color = AppColors.navy,
  });

  final IconData icon;
  final String label;
  final String? detail;
  final VoidCallback? onTap;
  final bool loading;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppText.label.copyWith(color: color)),
                  if (detail != null) Text(detail!, style: AppText.caption),
                ],
              ),
            ),
            loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.pink),
                  )
                : Icon(Icons.chevron_right_rounded, color: AppColors.navy.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }
}
