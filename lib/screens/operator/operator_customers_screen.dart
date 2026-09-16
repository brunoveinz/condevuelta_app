import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/operator_models.dart';
import '../../state/operator_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pressable.dart';
import 'operator_widgets.dart';

/// "Clientes": everyone registered in the local, with their loan counts.
class OperatorCustomersScreen extends StatefulWidget {
  const OperatorCustomersScreen({super.key});

  @override
  State<OperatorCustomersScreen> createState() => _OperatorCustomersScreenState();
}

class _OperatorCustomersScreenState extends State<OperatorCustomersScreen> {
  final _scroll = ScrollController();
  late final _search = TextEditingController(text: OperatorScope.read(context).customerQuery);
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    final controller = OperatorScope.read(context);
    if (!controller.hasLoadedCustomers) {
      WidgetsBinding.instance.addPostFrameCallback((_) => controller.reloadCustomers());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 400) OperatorScope.read(context).loadMoreCustomers();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) OperatorScope.read(context).setCustomerQuery(value);
    });
    setState(() {});
  }

  void _clearSearch() {
    _search.clear();
    _debounce?.cancel();
    OperatorScope.read(context).setCustomerQuery('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = OperatorScope.of(context);
    final customers = controller.customers;
    final firstLoad = controller.isLoadingCustomers && customers.isEmpty;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.pink,
        backgroundColor: AppColors.white,
        onRefresh: controller.reloadCustomers,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Clientes', style: AppText.title),
                        const Spacer(),
                        if (!firstLoad)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '${controller.customersCount} '
                              '${controller.customersCount == 1 ? 'cliente' : 'clientes'}',
                              style: AppText.caption,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    OperatorSearchField(
                      controller: _search,
                      hintText: 'Nombre, email o teléfono',
                      onChanged: _onSearchChanged,
                      onClear: _clearSearch,
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
              sliver: firstLoad
                  ? SliverList.separated(
                      itemCount: 6,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, _) => const SkeletonBox(height: 72, radius: 22),
                    )
                  : controller.customersError != null && customers.isEmpty
                  ? SliverToBoxAdapter(
                      child: _Message(
                        icon: Icons.wifi_off_rounded,
                        title: 'No pudimos cargar tus clientes',
                        body: controller.customersError!,
                        actionLabel: 'Reintentar',
                        onAction: controller.reloadCustomers,
                      ),
                    )
                  : customers.isEmpty
                  ? SliverToBoxAdapter(child: _EmptyCustomers(query: controller.customerQuery))
                  : SliverList.separated(
                      itemCount: customers.length + (controller.hasMoreCustomers ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        if (i == customers.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: SizedBox(
                                width: 26,
                                height: 26,
                                child: CircularProgressIndicator(strokeWidth: 2.6, color: AppColors.pink),
                              ),
                            ),
                          );
                        }
                        final customer = customers[i];
                        return StaggeredIn(
                          key: ValueKey(customer.id),
                          index: i,
                          child: _CustomerTile(customer: customer),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({required this.customer});

  final LocalCustomerRow customer;

  @override
  Widget build(BuildContext context) {
    final contact = customer.contact;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.hairline),
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
                  style: AppText.label,
                ),
                const SizedBox(height: 2),
                Text(
                  contact.isEmpty ? 'Sin contacto' : contact,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (customer.openLoans > 0)
                _Pill(
                  '${customer.openLoans} ${customer.openLoans == 1 ? 'abierto' : 'abiertos'}',
                  AppColors.pinkMist,
                  AppColors.pinkDark,
                )
              else
                const _Pill('Al día', AppColors.hairline, AppColors.navy),
              const SizedBox(height: 4),
              Text(
                '${customer.totalLoans} ${customer.totalLoans == 1 ? 'préstamo' : 'préstamos'}',
                style: AppText.caption.copyWith(fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, this.background, this.foreground);

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
      child: Text(
        label,
        style: AppText.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: foreground),
      ),
    );
  }
}

class _EmptyCustomers extends StatelessWidget {
  const _EmptyCustomers({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    if (query.isNotEmpty) {
      return _Message(
        icon: Icons.search_off_rounded,
        title: 'Sin resultados',
        body: 'No encontramos clientes para "$query".',
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          Image.asset('assets/images/mascota.png', width: 150),
          const SizedBox(height: 12),
          Text('Aún no tienes clientes', style: AppText.headline),
          const SizedBox(height: 6),
          Text(
            'Cuando escanees el carnet de alguien al prestarle un envase, queda registrado aquí.',
            style: AppText.body,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.body, this.actionLabel, this.onAction});

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.pink),
          const SizedBox(height: 10),
          Text(title, style: AppText.headline, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(body, style: AppText.body, textAlign: TextAlign.center),
          if (actionLabel != null)
            Pressable(
              onTap: onAction,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(actionLabel!, style: AppText.label.copyWith(color: AppColors.pink)),
              ),
            ),
        ],
      ),
    );
  }
}
