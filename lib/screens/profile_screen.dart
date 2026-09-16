import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/brand.dart';
import '../widgets/pressable.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _comingSoon(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: AppText.bodyFamily)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final customer = state.customer;
    if (customer == null) return const SizedBox.shrink();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 130),
        children: [
          Center(
            child: Container(
              width: 92,
              height: 92,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppColors.pinkSoft, shape: BoxShape.circle),
              child: Text(customer.initial, style: AppText.hero.copyWith(color: AppColors.pinkDark, fontSize: 44)),
            ),
          ),
          const SizedBox(height: 14),
          Center(child: Text(customer.name, style: AppText.title)),
          Center(child: Text(customer.email, style: AppText.body)),
          const SizedBox(height: 26),
          // Global switch (AppConfig.cardRegistrationEnabled): off = hidden.
          if (state.config.cardRegistrationEnabled) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(26)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.credit_card_rounded, color: AppColors.white),
                      const SizedBox(width: 10),
                      Text('Tarjeta de garantía', style: AppText.label.copyWith(color: AppColors.white, fontSize: 16)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('Opcional', style: AppText.caption.copyWith(color: AppColors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Algunos locales piden garantía por el envase. Con tu tarjeta guardada es más rápido; si no, puedes dejarla en efectivo.',
                    style: AppText.caption.copyWith(color: AppColors.white.withValues(alpha: 0.75), fontSize: 14),
                  ),
                  const SizedBox(height: 14),
                  Pressable(
                    onTap: () => _comingSoon(context, 'El registro de tarjeta con Flow llega pronto.'),
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(color: AppColors.pink, borderRadius: BorderRadius.circular(23)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, color: AppColors.white, size: 20),
                          SizedBox(width: 6),
                          Text(
                            'Agregar tarjeta',
                            style: TextStyle(fontFamily: AppText.bodyFamily, fontWeight: FontWeight.w500, color: AppColors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              children: [
                if (state.canReturnToOperator) ...[
                  _Row(
                    icon: Icons.storefront_rounded,
                    label: 'Volver al modo local',
                    onTap: () async {
                      await state.switchToOperator();
                      if (context.mounted && state.errorMessage != null) _comingSoon(context, state.errorMessage!);
                    },
                    color: AppColors.pink,
                  ),
                  const Divider(height: 1, indent: 58, color: AppColors.hairline),
                ],
                _Row(icon: Icons.auto_awesome_rounded, label: 'Ver el tutorial de nuevo', onTap: state.replayTutorial),
                const Divider(height: 1, indent: 58, color: AppColors.hairline),
                _Row(icon: Icons.help_outline_rounded, label: 'Ayuda', onTap: () => _comingSoon(context, 'Pronto: centro de ayuda.')),
                const Divider(height: 1, indent: 58, color: AppColors.hairline),
                _Row(icon: Icons.logout_rounded, label: 'Cerrar sesión', onTap: state.signOut, color: AppColors.pink),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: Column(
              children: [
                const BrandMark(width: 40),
                const SizedBox(height: 6),
                Text('Condevuelta · versión 1.0.0', style: AppText.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.onTap, this.color = AppColors.navy});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
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
            Expanded(child: Text(label, style: AppText.label.copyWith(color: color))),
            Icon(Icons.chevron_right_rounded, color: AppColors.navy.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }
}
