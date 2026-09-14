import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/app_theme.dart';

/// Colored square with the local's initial. Same color for the same local
/// everywhere in the app.
class PlaceBadge extends StatelessWidget {
  const PlaceBadge({super.key, required this.place, this.size = 52});

  static const _colors = [AppColors.pinkSoft, AppColors.yellow, AppColors.green, AppColors.sky, AppColors.lime];

  final Place place;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _colors[place.id % _colors.length],
        borderRadius: BorderRadius.circular(size * 0.31),
      ),
      child: Text(place.initial, style: AppText.title.copyWith(fontSize: size * 0.5)),
    );
  }
}
