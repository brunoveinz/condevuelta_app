import 'package:flutter/material.dart';

import '../../data/operator_models.dart';
import '../../state/operator_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/money.dart';
import '../../widgets/pressable.dart';
import 'operator_widgets.dart';

/// "Envases": what the local owns, by model, and where each one is.
class OperatorStockScreen extends StatefulWidget {
  const OperatorStockScreen({super.key});

  @override
  State<OperatorStockScreen> createState() => _OperatorStockScreenState();
}

class _OperatorStockScreenState extends State<OperatorStockScreen> {
  @override
  void initState() {
    super.initState();
    final controller = OperatorScope.read(context);
    if (!controller.hasLoadedStock) {
      WidgetsBinding.instance.addPostFrameCallback((_) => controller.reloadStock());
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = OperatorScope.of(context);
    final stock = controller.stock;
    final firstLoad = controller.isLoadingStock && !controller.hasLoadedStock;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.pink,
        backgroundColor: AppColors.white,
        onRefresh: controller.reloadStock,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Envases', style: AppText.title),
                const Spacer(),
                if (!firstLoad)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('${stock.total} en total', style: AppText.caption),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (controller.stockError != null && !controller.hasLoadedStock)
              _StockError(message: controller.stockError!, onRetry: controller.reloadStock)
            else if (firstLoad)
              for (var i = 0; i < 4; i++) ...[
                SkeletonBox(height: i == 0 ? 120 : 84, radius: i == 0 ? 26 : 22),
                const SizedBox(height: 12),
              ]
            else if (stock.types.isEmpty)
              const _NoStock()
            else ...[
              StaggeredIn(index: 0, child: _TotalsCard(stock: stock)),
              const SizedBox(height: 22),
              SectionTitle(title: 'Por modelo', count: stock.types.length),
              const SizedBox(height: 12),
              for (var i = 0; i < stock.types.length; i++) ...[
                StaggeredIn(index: i + 1, child: _StockTypeCard(type: stock.types[i])),
                const SizedBox(height: 10),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Navy card with the local's totals: available, lent and out of circulation.
class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.stock});

  final LocalStock stock;

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.white.withValues(alpha: 0.68);
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2A3466), AppColors.navy, Color(0xFF151B36)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -50,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(color: AppColors.lime.withValues(alpha: 0.12), shape: BoxShape.circle),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Disponibles ahora', style: AppText.caption.copyWith(color: muted, fontWeight: FontWeight.w500)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${stock.available}',
                        style: AppText.hero.copyWith(fontSize: 58, height: 1.02, color: AppColors.white),
                      ),
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 11),
                        child: Text(
                          stock.available == 1 ? 'envase\nen tu local' : 'envases\nen tu local',
                          style: AppText.label.copyWith(color: AppColors.white, height: 1.15),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _Totals(value: stock.loaned, label: 'prestados', icon: Icons.outbox_rounded)),
                      Container(width: 1, height: 34, color: AppColors.white.withValues(alpha: 0.12)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _Totals(
                          value: stock.unusable,
                          label: 'fuera de circulación',
                          icon: Icons.block_rounded,
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

class _Totals extends StatelessWidget {
  const _Totals({required this.value, required this.label, required this.icon});

  final int value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: AppColors.lime),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$value', style: AppText.headline.copyWith(color: AppColors.white, height: 1)),
              Text(
                label,
                maxLines: 2,
                style: AppText.caption.copyWith(color: AppColors.white.withValues(alpha: 0.68), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One container model: its code, guarantee and where its containers are.
class _StockTypeCard extends StatelessWidget {
  const _StockTypeCard({required this.type});

  final StockType type;

  @override
  Widget build(BuildContext context) {
    final lent = type.total == 0 ? 0.0 : (type.loaned / type.total).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.pinkMist, borderRadius: BorderRadius.circular(14)),
                child: Text(type.code, style: AppText.label.copyWith(color: AppColors.pinkDark)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.label),
                    const SizedBox(height: 2),
                    Text(
                      type.guaranteeValue > 0 ? 'Garantía ${formatClp(type.guaranteeValue)}' : 'Sin garantía',
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
              if (!type.isActive) const _Count('Inactivo', AppColors.hairline),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: lent,
              minHeight: 8,
              color: AppColors.pink,
              backgroundColor: AppColors.green.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Count('${type.available} disponibles', AppColors.green.withValues(alpha: 0.45)),
              _Count('${type.loaned} prestados', AppColors.pinkMist),
              if (type.unusable > 0) _Count('${type.unusable} fuera', AppColors.yellow.withValues(alpha: 0.6)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.label, this.background);

  final String label;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: AppText.caption.copyWith(fontSize: 12, color: AppColors.navy)),
    );
  }
}

class _NoStock extends StatelessWidget {
  const _NoStock();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          Image.asset('assets/images/mascota.png', width: 150),
          const SizedBox(height: 12),
          Text('Aún no hay envases', style: AppText.headline),
          const SizedBox(height: 6),
          Text(
            'Crea tus modelos de envase en el panel web de tu local y aparecerán aquí.',
            style: AppText.body,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StockError extends StatelessWidget {
  const _StockError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        children: [
          const Icon(Icons.inventory_2_outlined, size: 36, color: AppColors.pink),
          const SizedBox(height: 10),
          Text(message, style: AppText.body, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Pressable(
            onTap: onRetry,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text('Reintentar', style: AppText.label.copyWith(color: AppColors.pink)),
            ),
          ),
        ],
      ),
    );
  }
}
