import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/operator_models.dart';
import '../../state/operator_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pressable.dart';
import 'operator_loan_detail_screen.dart';
import 'operator_widgets.dart';

/// "Préstamos": every loan of the local, with filters, search and paging.
class OperatorLoansScreen extends StatefulWidget {
  const OperatorLoansScreen({super.key});

  @override
  State<OperatorLoansScreen> createState() => _OperatorLoansScreenState();
}

class _OperatorLoansScreenState extends State<OperatorLoansScreen> {
  final _scroll = ScrollController();
  late final _search = TextEditingController(text: OperatorScope.read(context).query);
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 400) OperatorScope.read(context).loadMoreLoans();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) OperatorScope.read(context).setQuery(value);
    });
    setState(() {});
  }

  void _clearSearch() {
    _search.clear();
    _debounce?.cancel();
    OperatorScope.read(context).setQuery('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = OperatorScope.of(context);
    final loans = controller.loans;
    final firstLoad = controller.isLoadingLoans && loans.isEmpty;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.pink,
        backgroundColor: AppColors.white,
        onRefresh: controller.reloadLoans,
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
                        Text('Préstamos', style: AppText.title),
                        const Spacer(),
                        if (!firstLoad)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '${controller.loansCount} ${controller.loansCount == 1 ? 'resultado' : 'resultados'}',
                              style: AppText.caption,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _SearchField(controller: _search, onChanged: _onSearchChanged, onClear: _clearSearch),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 40,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: LoanFilter.values.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final filter = LoanFilter.values[i];
                    return _FilterChip(
                      label: filter.label,
                      selected: filter == controller.filter,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        controller.setFilter(filter);
                      },
                    );
                  },
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
              sliver: firstLoad
                  ? SliverList.separated(
                      itemCount: 5,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, _) => const SkeletonBox(height: 76, radius: 22),
                    )
                  : controller.loansError != null && loans.isEmpty
                  ? SliverToBoxAdapter(
                      child: _Message(
                        icon: Icons.wifi_off_rounded,
                        title: 'No pudimos cargar los préstamos',
                        body: controller.loansError!,
                        actionLabel: 'Reintentar',
                        onAction: controller.reloadLoans,
                      ),
                    )
                  : loans.isEmpty
                  ? SliverToBoxAdapter(
                      child: _EmptyResults(filter: controller.filter, query: controller.query),
                    )
                  : SliverList.separated(
                      itemCount: loans.length + (controller.hasMoreLoans ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        if (i == loans.length) {
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
                        final loan = loans[i];
                        return StaggeredIn(
                          key: ValueKey(loan.id),
                          index: i,
                          child: OperatorLoanTile(
                            loan: loan,
                            onTap: () => pushOperatorPage(context, OperatorLoanDetailScreen(loan: loan)),
                          ),
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

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged, required this.onClear});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: AppText.body.copyWith(color: AppColors.navy),
      decoration: InputDecoration(
        hintText: 'Cliente, email o código',
        hintStyle: AppText.body,
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.muted),
        suffixIcon: controller.text.isEmpty
            ? null
            : Pressable(
                onTap: onClear,
                child: const Icon(Icons.close_rounded, color: AppColors.muted),
              ),
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: AppColors.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: AppColors.pink, width: 1.5),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.medium,
        curve: AppMotion.emphasized,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.navy : AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.navy : AppColors.hairline),
        ),
        child: Text(
          label,
          style: AppText.label.copyWith(fontSize: 14, color: selected ? AppColors.white : AppColors.navy),
        ),
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.filter, required this.query});

  final LoanFilter filter;
  final String query;

  @override
  Widget build(BuildContext context) {
    if (query.isNotEmpty) {
      return _Message(
        icon: Icons.search_off_rounded,
        title: 'Sin resultados',
        body: 'No encontramos préstamos para "$query".',
      );
    }
    final (title, body) = switch (filter) {
      LoanFilter.open => ('Nada en circulación', 'Cuando prestes un envase aparecerá aquí.'),
      LoanFilter.overdue => ('Todo al día', 'No hay envases atrasados en tu local.'),
      LoanFilter.returned => ('Aún no hay devoluciones', 'Los envases recibidos aparecerán aquí.'),
      LoanFilter.closed => ('Sin préstamos cerrados', 'Aquí verás los perdidos y las garantías cobradas.'),
      LoanFilter.all => ('Aún no hay préstamos', 'Escanea un envase para hacer el primero.'),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          Image.asset('assets/images/mascota.png', width: 150),
          const SizedBox(height: 12),
          Text(title, style: AppText.headline),
          const SizedBox(height: 6),
          Text(body, style: AppText.body, textAlign: TextAlign.center),
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
