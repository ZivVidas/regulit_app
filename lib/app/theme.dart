import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════
/// AppColors — Regulit design tokens
/// Primary: Navy blue #1A3C6B  Accent: Orange #E87722
/// ═══════════════════════════════════════════════════════════
abstract class AppColors {
  // Brand
  static const blue = Color(0xFF1A3C6B);
  static const blueDark = Color(0xFF0F2545);
  static const blueLight = Color(0xFF2A5298);
  static const orange = Color(0xFFE87722);
  static const orangeLight = Color(0xFFFEF3E2);

  // Semantic
  static const success = Color(0xFF16A34A);
  static const successLight = Color(0xFFDCFCE7);
  static const warning = Color(0xFFCA8A04);
  static const warningLight = Color(0xFFFEF9C3);
  static const danger = Color(0xFFDC2626);
  static const dangerLight = Color(0xFFFEE2E2);
  static const info = Color(0xFF1A3C6B);
  static const infoLight = Color(0xFFEBF1FB);

  // Neutrals
  static const text = Color(0xFF1A1A2E);
  static const muted = Color(0xFF6B7280);
  static const border = Color(0xFFDDE3EC);
  static const surface = Color(0xFFF5F7FA);
  static const white = Color(0xFFFFFFFF);
  static const background = Color(0xFFF0F2F7);

  // Sidebar
  static const sidebarBg = blue;
  static const sidebarIconActive = orange;
  static const sidebarIconInactive = Color(0x99FFFFFF);

  // Severity dots
  static const sevCritical = danger;
  static const sevHigh = orange;
  static const sevMedium = warning;
  static const sevLow = success;
}

/// ═══════════════════════════════════════════════════════════
/// AppTextStyles — Heebo font, Hebrew-optimised sizing
/// ═══════════════════════════════════════════════════════════
abstract class AppTextStyles {
  static const _base = TextStyle(
    fontFamily: 'Heebo',
    color: AppColors.text,
    height: 1.45,
  );

  static final h1 = _base.copyWith(fontSize: 28, fontWeight: FontWeight.w800);
  static final h2 = _base.copyWith(fontSize: 20, fontWeight: FontWeight.w700);
  static final h3 = _base.copyWith(fontSize: 16, fontWeight: FontWeight.w700);
  static final h4 = _base.copyWith(fontSize: 14, fontWeight: FontWeight.w700);

  static final body = _base.copyWith(fontSize: 14, fontWeight: FontWeight.w400);
  static final bodySmall = _base.copyWith(fontSize: 12, fontWeight: FontWeight.w400);
  static final caption = _base.copyWith(fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.muted);

  static final label = _base.copyWith(fontSize: 11, fontWeight: FontWeight.w700,
      letterSpacing: 0.4, color: AppColors.muted);

  static final metric = _base.copyWith(fontSize: 28, fontWeight: FontWeight.w800);
  static final metricSmall = _base.copyWith(fontSize: 18, fontWeight: FontWeight.w800);

  static final button = _base.copyWith(fontSize: 13, fontWeight: FontWeight.w700);
  static final tag = _base.copyWith(fontSize: 11, fontWeight: FontWeight.w600);
}

/// ═══════════════════════════════════════════════════════════
/// AppSpacing — consistent spacing scale
/// ═══════════════════════════════════════════════════════════
abstract class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  static const EdgeInsets pagePadding = EdgeInsets.all(xl);
  static const EdgeInsets cardPadding = EdgeInsets.all(lg);
  static const EdgeInsets listTilePadding = EdgeInsets.symmetric(horizontal: lg, vertical: md);
}

/// ═══════════════════════════════════════════════════════════
/// AppRadius — border radius constants
/// ═══════════════════════════════════════════════════════════
abstract class AppRadius {
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 14;
  static const double xl = 20;
  static const double pill = 100;

  static const BorderRadius card = BorderRadius.all(Radius.circular(md));
  static const BorderRadius button = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius pill_ = BorderRadius.all(Radius.circular(pill));
}

/// ═══════════════════════════════════════════════════════════
/// AppTheme — MaterialTheme built from design tokens
/// ═══════════════════════════════════════════════════════════
abstract class AppTheme {
  static final ThemeData light = ThemeData(
    useMaterial3: true,
    fontFamily: 'Heebo',
    scaffoldBackgroundColor: AppColors.background,

    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.blue,
      onPrimary: AppColors.white,
      secondary: AppColors.orange,
      onSecondary: AppColors.white,
      error: AppColors.danger,
      onError: AppColors.white,
      surface: AppColors.white,
      onSurface: AppColors.text,
    ),

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.blue,
      elevation: 0,
      shadowColor: AppColors.border,
      titleTextStyle: TextStyle(
        fontFamily: 'Heebo',
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.blue,
      ),
    ),

    // Cards
    cardTheme: CardThemeData(
      color: AppColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.card,
        side: const BorderSide(color: AppColors.border, width: 1.5),
      ),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
    ),

    // Elevated Buttons  — primary action (orange)
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.orange,
        foregroundColor: AppColors.white,
        textStyle: AppTextStyles.button,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
        elevation: 0,
      ),
    ),

    // Outlined Buttons — secondary action
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.blue,
        textStyle: AppTextStyles.button,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
        side: const BorderSide(color: AppColors.border, width: 1.5),
      ),
    ),

    // Text Buttons
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.orange,
        textStyle: AppTextStyles.button,
      ),
    ),

    // Input fields
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      border: OutlineInputBorder(
        borderRadius: AppRadius.button,
        borderSide: const BorderSide(color: AppColors.border, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.button,
        borderSide: const BorderSide(color: AppColors.border, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.button,
        borderSide: const BorderSide(color: AppColors.blue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.button,
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
      labelStyle: AppTextStyles.label,
      hintStyle: AppTextStyles.body.copyWith(color: AppColors.muted),
    ),

    // Chips / Tags
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.infoLight,
      labelStyle: AppTextStyles.tag.copyWith(color: AppColors.blue),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.pill_),
    ),

    // Dividers
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 0,
    ),

    // Navigation Rail (web sidebar)
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: AppColors.blue,
      selectedIconTheme: IconThemeData(color: AppColors.white),
      unselectedIconTheme: IconThemeData(color: AppColors.sidebarIconInactive),
      indicatorColor: AppColors.orange,
      labelType: NavigationRailLabelType.none,
    ),

    // Bottom Nav (mobile)
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.white,
      selectedItemColor: AppColors.blue,
      unselectedItemColor: AppColors.muted,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
  );
}
