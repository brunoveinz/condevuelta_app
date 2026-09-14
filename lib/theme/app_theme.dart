import 'package:flutter/material.dart';

/// Brand palette, lifted from ../web/tailwind.config.js and
/// ../landing/tailwind.config.mjs so the app matches the web.
class AppColors {
  AppColors._();

  static const pink = Color(0xFFD90F74); // primary
  static const pinkDark = Color(0xFFB30B5F); // primaryHover
  static const pinkSoft = Color(0xFFF9B3D0); // secondary
  static const pinkMist = Color(0xFFFEE3EA); // new-pink
  static const yellow = Color(0xFFFEEA83); // terciary
  static const green = Color(0xFF9DCA8B); // quartiary
  static const lime = Color(0xFFDFFF89); // fresh-green
  static const navy = Color(0xFF1E264A); // new-blue
  static const sky = Color(0xFFA4D3F1); // condevuelta-blue
  static const skyMist = Color(0xFFD8EAF6); // white-blue
  static const background = Color(0xFFFEF8F8); // condevuelta-white
  static const white = Color(0xFFFFFFFF);

  /// Navy at ~64% opacity, used for secondary text.
  static const muted = Color(0xA31E264A);

  /// Navy at ~8% opacity, used for hairline borders.
  static const hairline = Color(0x141E264A);
}

/// Type ramp. Baloo (display) only ships a regular weight, which is already
/// heavy, so it is never bolded. Outfit carries body text.
class AppText {
  AppText._();

  static const displayFamily = 'Baloo';
  static const bodyFamily = 'Outfit';

  static const hero = TextStyle(
    fontFamily: displayFamily,
    fontSize: 38,
    height: 1.0,
    letterSpacing: -0.6,
    color: AppColors.navy,
  );

  static const title = TextStyle(
    fontFamily: displayFamily,
    fontSize: 30,
    height: 1.05,
    letterSpacing: -0.4,
    color: AppColors.navy,
  );

  static const headline = TextStyle(
    fontFamily: displayFamily,
    fontSize: 22,
    height: 1.1,
    color: AppColors.navy,
  );

  static const body = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 16,
    height: 1.45,
    color: AppColors.muted,
  );

  static const label = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.navy,
  );

  static const caption = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 13,
    height: 1.35,
    color: AppColors.muted,
  );
}

/// Global motion curves so every animation feels like the same app.
class AppMotion {
  AppMotion._();

  static const Curve emphasized = Cubic(0.2, 0.8, 0.2, 1);
  static const Curve bouncy = Cubic(0.2, 1.3, 0.4, 1);
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 450);
  static const Duration slow = Duration(milliseconds: 700);
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: AppText.bodyFamily,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.pink,
      primary: AppColors.pink,
      surface: AppColors.background,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.pink,
      selectionColor: AppColors.pinkSoft,
      selectionHandleColor: AppColors.pink,
    ),
  );
}
