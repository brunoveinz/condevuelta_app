import 'dart:math';

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/pressable.dart';

/// Discovery (not registration): where the carnet can be used.
class PlacesScreen extends StatefulWidget {
  const PlacesScreen({super.key});

  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> {
  final _search = TextEditingController();
  int? _selectedId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Place> _filter(List<Place> places) {
    final q = _search.text.trim().toLowerCase();
    final result = q.isEmpty
        ? [...places]
        : places.where((p) => p.name.toLowerCase().contains(q) || p.category.toLowerCase().contains(q)).toList();
    return result..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
  }

  void _select(int id) => setState(() => _selectedId = _selectedId == id ? null : id);

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: _search,
        builder: (context, _) {
          final places = _filter(state.places);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 130),
            children: [
              Text('Locales', style: AppText.title),
              const SizedBox(height: 4),
              const Text('Donde puedes usar tu carnet.', style: AppText.body),
              const SizedBox(height: 16),
              TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontFamily: AppText.bodyFamily, fontSize: 16, color: AppColors.navy),
                decoration: InputDecoration(
                  hintText: 'Busca un local o tipo de comida',
                  hintStyle: AppText.body.copyWith(color: AppColors.navy.withValues(alpha: 0.35)),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.navy),
                  filled: true,
                  fillColor: AppColors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: AppColors.hairline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: AppColors.pink.withValues(alpha: 0.55), width: 1.6),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _MapCard(places: places, selectedId: _selectedId, onSelect: _select),
              const SizedBox(height: 20),
              if (state.isLoadingHome && state.places.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AppColors.pink)))
              else if (places.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('No encontramos locales con "${_search.text.trim()}".', style: AppText.body, textAlign: TextAlign.center),
                )
              else
                for (final place in places) ...[
                  _PlaceCard(place: place, isSelected: place.id == _selectedId, onTap: () => _select(place.id)),
                  const SizedBox(height: 10),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _MapCard extends StatefulWidget {
  const _MapCard({required this.places, required this.selectedId, required this.onSelect});

  final List<Place> places;
  final int? selectedId;
  final ValueChanged<int> onSelect;

  @override
  State<_MapCard> createState() => _MapCardState();
}

class _MapCardState extends State<_MapCard> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        height: 260,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            const h = 260.0;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                const Positioned.fill(child: CustomPaint(painter: _MapPainter())),
                Positioned(
                  left: w * 0.46 - 40,
                  top: h * 0.46 - 40,
                  child: AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, _) => SizedBox(
                      width: 80,
                      height: 80,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Transform.scale(
                            scale: 0.4 + 0.6 * _pulse.value,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.navy.withValues(alpha: 0.22 * (1 - _pulse.value)),
                              ),
                            ),
                          ),
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: AppColors.navy,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.white, width: 3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                for (var i = 0; i < widget.places.length; i++)
                  _Pin(
                    key: ValueKey(widget.places[i].id),
                    place: widget.places[i],
                    index: i,
                    left: w * widget.places[i].mapX,
                    top: h * widget.places[i].mapY,
                    isSelected: widget.places[i].id == widget.selectedId,
                    onTap: () => widget.onSelect(widget.places[i].id),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({
    super.key,
    required this.place,
    required this.index,
    required this.left,
    required this.top,
    required this.isSelected,
    required this.onTap,
  });

  final Place place;
  final int index;
  final double left;
  final double top;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = isSelected ? 46.0 : 36.0;
    return Positioned(
      left: left - 70,
      top: top - 100,
      width: 140,
      height: 100,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 700 + index * 120),
        curve: Interval(index * 0.1, 1, curve: AppMotion.bouncy),
        builder: (context, v, child) => Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, -40 * (1 - v)), child: child),
        ),
        child: GestureDetector(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AnimatedSwitcher(
                duration: AppMotion.fast,
                child: isSelected
                    ? Container(
                        key: const ValueKey('label'),
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.navy,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          place.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption.copyWith(color: AppColors.white, fontWeight: FontWeight.w500),
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('none')),
              ),
              AnimatedContainer(
                duration: AppMotion.medium,
                curve: AppMotion.bouncy,
                width: size,
                height: size,
                child: Transform.rotate(
                  angle: -pi / 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: place.isOpen ? AppColors.pink : AppColors.muted,
                      border: Border.all(color: AppColors.white, width: 3),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(100),
                        topRight: Radius.circular(100),
                        bottomRight: Radius.circular(100),
                      ),
                      boxShadow: const [BoxShadow(color: Color(0x331E264A), blurRadius: 10, offset: Offset(0, 4))],
                    ),
                    child: Center(
                      child: Container(
                        width: size * 0.26,
                        height: size * 0.26,
                        decoration: const BoxDecoration(color: AppColors.white, shape: BoxShape.circle),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stylized city map: streets, a park and the Mapocho-like river.
class _MapPainter extends CustomPainter {
  const _MapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.skyMist);

    canvas.drawOval(Rect.fromLTWH(w * 0.72, h * 0.72, w * 0.34, h * 0.30), Paint()..color = AppColors.lime);
    canvas.drawOval(Rect.fromLTWH(w * 0.26, h * 0.46, w * 0.18, h * 0.16), Paint()..color = AppColors.green.withValues(alpha: 0.5));

    Paint road(double width) => Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(
      Path()
        ..moveTo(-10, h * 0.28)
        ..cubicTo(w * 0.25, h * 0.22, w * 0.5, h * 0.42, w + 10, h * 0.32),
      road(14),
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.18, -10)
        ..cubicTo(w * 0.2, h * 0.35, w * 0.1, h * 0.7, w * 0.26, h + 10),
      road(10),
    );
    canvas.drawPath(
      Path()
        ..moveTo(-10, h * 0.76)
        ..cubicTo(w * 0.35, h * 0.66, w * 0.64, h * 0.84, w + 10, h * 0.7),
      road(10),
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.68, -10)
        ..cubicTo(w * 0.63, h * 0.32, w * 0.76, h * 0.64, w * 0.7, h + 10),
      road(12),
    );
    canvas.drawPath(Path()..moveTo(w * 0.44, -10)..lineTo(w * 0.52, h + 10), road(6));

    canvas.drawPath(
      Path()
        ..moveTo(-10, h * 0.95)
        ..cubicTo(w * 0.25, h * 0.9, w * 0.6, h * 1.0, w + 10, h * 0.93),
      Paint()
        ..color = AppColors.sky
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18,
    );
  }

  @override
  bool shouldRepaint(_MapPainter oldDelegate) => false;
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.place, required this.isSelected, required this.onTap});

  final Place place;
  final bool isSelected;
  final VoidCallback onTap;

  static const _tileColors = [AppColors.pinkSoft, AppColors.yellow, AppColors.green, AppColors.sky, AppColors.lime];

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: AnimatedContainer(
        duration: AppMotion.medium,
        curve: AppMotion.emphasized,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: isSelected ? AppColors.pink : AppColors.hairline, width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _tileColors[place.id % _tileColors.length],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(place.name[0], style: AppText.title.copyWith(fontSize: 26)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place.name, style: AppText.label.copyWith(fontSize: 16)),
                  const SizedBox(height: 2),
                  Text('${place.category} · ${place.distanceLabel}', style: AppText.caption),
                  if (place.requiresGuarantee) ...[
                    const SizedBox(height: 4),
                    Text('Pide garantía por envase', style: AppText.caption.copyWith(color: AppColors.pinkDark)),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: place.isOpen ? AppColors.green.withValues(alpha: 0.25) : AppColors.navy.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                place.isOpen ? 'Abierto' : 'Cerrado',
                style: AppText.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.navy),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
