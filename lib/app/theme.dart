import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════
/// AppColors — Kinetic Corporate design tokens
/// Primary: Azure Blue #0078D4   Secondary: Kinetic Yellow #FFB900
/// Text: Onyx Black #201F1E      Background: Pure White #FFFFFF
/// ═══════════════════════════════════════════════════════════
abstract class AppColors {
  // Brand
  static const blue      = Color(0xFF0078D4); // Azure Blue — primary action
  static const blueDark  = Color(0xFF005A9E); // deeper azure for hover/active
  static const blueLight = Color(0xFF2899E0); // lighter azure for gradients
  static const orange    = Color(0xFFFFB900); // Kinetic Yellow — secondary/accent
  static const orangeLight = Color(0xFFFFF4CC); // yellow tint for backgrounds

  // Semantic
  static const success      = Color(0xFF107C10); // Microsoft-style green
  static const successLight = Color(0xFFDFF6DD);
  static const warning      = Color(0xFFCA8A04);
  static const warningLight = Color(0xFFFEF9C3);
  static const danger       = Color(0xFFD13438); // Microsoft-style red
  static const dangerLight  = Color(0xFFFDE7E9);
  static const info         = Color(0xFF0078D4);
  static const infoLight    = Color(0xFFDEECF9);

  // Neutrals
  static const text       = Color(0xFF201F1E); // Onyx Black
  static const muted      = Color(0xFF605E5C); // warm grey
  static const border     = Color(0xFFE1DFDD); // office-style border
  static const surface    = Color(0xFFF3F2F1); // Office Gray — contrast neutral
  static const white      = Color(0xFFFFFFFF); // Pure White
  static const background = Color(0xFFF3F2F1); // Office Gray — app background

  // Sidebar
  static const sidebarBg           = blue;
  static const sidebarIconActive    = orange;
  static const sidebarIconInactive  = Color(0x99FFFFFF);

  // Severity dots
  static const sevCritical = danger;
  static const sevHigh     = orange;
  static const sevMedium   = warning;
  static const sevLow      = success;
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

  static final body      = _base.copyWith(fontSize: 14, fontWeight: FontWeight.w400);
  static final bodySmall = _base.copyWith(fontSize: 12, fontWeight: FontWeight.w400);
  static final caption   = _base.copyWith(fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.muted);

  static final label = _base.copyWith(fontSize: 11, fontWeight: FontWeight.w700,
      letterSpacing: 0.4, color: AppColors.muted);

  static final metric      = _base.copyWith(fontSize: 28, fontWeight: FontWeight.w800);
  static final metricSmall = _base.copyWith(fontSize: 18, fontWeight: FontWeight.w800);

  static final button = _base.copyWith(fontSize: 13, fontWeight: FontWeight.w700);
  static final tag    = _base.copyWith(fontSize: 11, fontWeight: FontWeight.w600);
}

/// ═══════════════════════════════════════════════════════════
/// AppSpacing — consistent spacing scale
/// ═══════════════════════════════════════════════════════════
abstract class AppSpacing {
  static const double xs   = 4;
  static const double sm   = 8;
  static const double md   = 12;
  static const double lg   = 16;
  static const double xl   = 20;
  static const double xxl  = 24;
  static const double xxxl = 32;

  static const EdgeInsets pagePadding     = EdgeInsets.all(xl);
  static const EdgeInsets cardPadding     = EdgeInsets.all(lg);
  static const EdgeInsets listTilePadding = EdgeInsets.symmetric(horizontal: lg, vertical: md);
}

/// ═══════════════════════════════════════════════════════════
/// AppRadius — border radius constants
/// ═══════════════════════════════════════════════════════════
abstract class AppRadius {
  static const double sm   = 4;  // sharper corners for corporate feel
  static const double md   = 8;
  static const double lg   = 12;
  static const double xl   = 16;
  static const double pill = 100;

  static const BorderRadius card   = BorderRadius.all(Radius.circular(md));
  static const BorderRadius button = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius pill_  = BorderRadius.all(Radius.circular(pill));
}

/// ═══════════════════════════════════════════════════════════
/// AppShadows — elevation tokens (no Material elevation, pure BoxShadow)
/// ═══════════════════════════════════════════════════════════
abstract class AppShadows {
  static const List<BoxShadow> none = [];

  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x05000000), blurRadius: 2, offset: Offset(0, 0)),
  ];

  static const List<BoxShadow> lg = [
    BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 0)),
  ];

  static const List<BoxShadow> xl = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 24, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 0)),
  ];
}

/// ═══════════════════════════════════════════════════════════
/// AppSurfaces — layered background colors for depth hierarchy
/// ═══════════════════════════════════════════════════════════
abstract class AppSurfaces {
  static const Color page          = Color(0xFFF0F2F5); // App scaffold background
  static const Color card          = Color(0xFFFFFFFF); // Card / panel surface
  static const Color subtle        = Color(0xFFF8F9FA); // Subtle section background
  static const Color primaryTint   = Color(0xFFE8F4FD); // Blue tint (info/primary)
  static const Color secondaryTint = Color(0xFFFFF8E7); // Yellow tint (secondary)
  static const Color successTint   = Color(0xFFEBF7EB); // Green tint
  static const Color dangerTint    = Color(0xFFFDEBEC); // Red tint
  static const Color warningTint   = Color(0xFFFEF3E2); // Amber tint
}

/// ═══════════════════════════════════════════════════════════
/// AppGradients — brand gradients for headers and accents
/// ═══════════════════════════════════════════════════════════
abstract class AppGradients {
  static const LinearGradient primaryHeader = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0078D4), Color(0xFF005A9E)],
  );

  static const LinearGradient secondaryHeader = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFB900), Color(0xFFD97C0A)],
  );

  static const LinearGradient primarySubtle = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE8F4FD), Color(0xFFD0E9FA)],
  );

  static const LinearGradient successSubtle = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEBF7EB), Color(0xFFD5F0D5)],
  );

  static const LinearGradient dangerSubtle = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFDEBEC), Color(0xFFFAD4D6)],
  );
}

/// ═══════════════════════════════════════════════════════════
/// AppDurations — animation timing constants
/// ═══════════════════════════════════════════════════════════
abstract class AppDurations {
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast    = Duration(milliseconds: 150);
  static const Duration normal  = Duration(milliseconds: 250);
  static const Duration slow    = Duration(milliseconds: 400);
  static const Duration stagger = Duration(milliseconds: 60);
  static const Duration page    = Duration(milliseconds: 300);
}

/// ═══════════════════════════════════════════════════════════
/// AppTheme — MaterialTheme built from design tokens
/// ═══════════════════════════════════════════════════════════
abstract class AppTheme {
  static final ThemeData light = ThemeData(
    useMaterial3: true,
    fontFamily: 'Heebo',
    scaffoldBackgroundColor: AppSurfaces.page,

    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.blue,
      onPrimary: AppColors.white,
      secondary: AppColors.orange,
      onSecondary: AppColors.text,
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
        color: AppColors.text,
      ),
    ),

    // Cards
    cardTheme: CardThemeData(
      color: AppSurfaces.card,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
    ),

    // Elevated Buttons — primary action (azure blue)
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.orange,
        foregroundColor: AppColors.text,
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
        side: const BorderSide(color: AppColors.blue, width: 1.5),
      ),
    ),

    // Text Buttons
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.blue,
        textStyle: AppTextStyles.button,
      ),
    ),

    // Input fields
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.border, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.blue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.danger, width: 2),
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
