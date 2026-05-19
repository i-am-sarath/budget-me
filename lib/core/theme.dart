import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────
// Premium Black & White Minimalist Palette
// ─────────────────────────────────────────────

class AppColors {
  // ── Dark Mode (true black base) ──────────────────────────
  static const Color surface          = Color(0xFF0A0A0A); // near-black
  static const Color surfaceContainer = Color(0xFF111111);
  static const Color surfaceContainerLow    = Color(0xFF161616);
  static const Color surfaceContainerHigh   = Color(0xFF1E1E1E);
  static const Color surfaceContainerHighest = Color(0xFF2A2A2A);
  static const Color surfaceBright    = Color(0xFF323232);
  static const Color surfaceContainerLowest = Color(0xFF080808);

  static const Color onSurface        = Color(0xFFF5F5F5); // near-white
  static const Color onSurfaceVariant = Color(0xFF9A9A9A); // medium gray

  static const Color outline          = Color(0xFF404040);
  static const Color outlineVariant   = Color(0xFF282828);

  // Accent — muted green (finance-green, readable on dark)
  static const Color primary          = Color(0xFF5CB85C); // muted green
  static const Color primaryContainer = Color(0xFF1B3A1B); // deep green container
  static const Color onPrimary        = Color(0xFF0A0A0A);
  static const Color onPrimaryContainer = Color(0xFFA5D6A7);

  static const Color secondary        = Color(0xFFB0B0B0);
  static const Color secondaryContainer = Color(0xFF1E1E1E);
  static const Color onSecondary      = Color(0xFF0A0A0A);

  static const Color tertiary         = Color(0xFF808080);
  static const Color tertiaryContainer = Color(0xFF1A1A1A);
  static const Color onTertiary       = Color(0xFF0A0A0A);

  static const Color error            = Color(0xFFFF6B6B);
  static const Color errorContainer   = Color(0xFF2D1515);
  static const Color onError          = Color(0xFF0A0A0A);

  // Transaction type colors — sharp & minimal
  static const Color expense  = Color(0xFFFF5C5C); // sharp red
  static const Color income   = Color(0xFF4ADE80); // sharp green
  static const Color investment = Color(0xFF60A5FA); // blue
  static const Color lend     = Color(0xFFFBBF24); // amber
  static const Color borrow   = Color(0xFFE879F9); // violet

  // Inverse
  static const Color inverseSurface    = Color(0xFFF5F5F5);
  static const Color inverseOnSurface  = Color(0xFF111111);
  static const Color inversePrimary    = Color(0xFF1A1A1A);
}

class AppColorsLight {
  // ── Light Mode (Wispr Flow-inspired: warm gray scaffold, white cards, forest green) ──
  static const Color surface                = Color(0xFFEDEEF0); // warm light gray scaffold
  static const Color surfaceBright          = Color(0xFFFFFFFF);
  static const Color surfaceContainer       = Color(0xFFFFFFFF); // white cards
  static const Color surfaceContainerLow    = Color(0xFFFFFFFF);
  static const Color surfaceContainerHigh   = Color(0xFFF0F1F3); // inputs
  static const Color surfaceContainerHighest = Color(0xFFE8E9EC);

  static const Color onSurface        = Color(0xFF1A1A1A);
  static const Color onSurfaceVariant = Color(0xFF6B7280);

  static const Color outline          = Color(0xFFD1D5DB);
  static const Color outlineVariant   = Color(0xFFE5E7EB);

  static const Color primary          = Color(0xFF2D6A2D); // forest green
  static const Color primaryContainer = Color(0xFFE8F5E9); // light green tint
  static const Color onPrimary        = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFF1B5E20);

  static const Color error            = Color(0xFFDC2626);
  static const Color errorContainer   = Color(0xFFFEE2E2);

  static const Color expense  = Color(0xFFDC2626);
  static const Color income   = Color(0xFF16A34A);
  static const Color investment = Color(0xFF2563EB);
  static const Color lend     = Color(0xFFD97706);
  static const Color borrow   = Color(0xFF9333EA);
}

// ─────────────────────────────────────────────
// Theme resolver helper
// ─────────────────────────────────────────────

class AppThemeColors {
  final Color surface;
  final Color surfaceContainer;
  final Color surfaceContainerLow;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color outline;
  final Color outlineVariant;
  final Color primary;
  final Color primaryContainer;
  final Color onPrimary;
  final Color onPrimaryContainer;
  final Color error;
  final Color errorContainer;
  final Color expense;
  final Color income;
  final Color investment;
  final Color lend;
  final Color borrow;

  const AppThemeColors({
    required this.surface,
    required this.surfaceContainer,
    required this.surfaceContainerLow,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
    required this.outlineVariant,
    required this.primary,
    required this.primaryContainer,
    required this.onPrimary,
    required this.onPrimaryContainer,
    required this.error,
    required this.errorContainer,
    required this.expense,
    required this.income,
    required this.investment,
    required this.lend,
    required this.borrow,
  });

  static AppThemeColors of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? _dark : _light;
  }

  static const _dark = AppThemeColors(
    surface: AppColors.surface,
    surfaceContainer: AppColors.surfaceContainer,
    surfaceContainerLow: AppColors.surfaceContainerLow,
    surfaceContainerHigh: AppColors.surfaceContainerHigh,
    surfaceContainerHighest: AppColors.surfaceContainerHighest,
    onSurface: AppColors.onSurface,
    onSurfaceVariant: AppColors.onSurfaceVariant,
    outline: AppColors.outline,
    outlineVariant: AppColors.outlineVariant,
    primary: AppColors.primary,
    primaryContainer: AppColors.primaryContainer,
    onPrimary: AppColors.onPrimary,
    onPrimaryContainer: AppColors.onPrimaryContainer,
    error: AppColors.error,
    errorContainer: AppColors.errorContainer,
    expense: AppColors.expense,
    income: AppColors.income,
    investment: AppColors.investment,
    lend: AppColors.lend,
    borrow: AppColors.borrow,
  );

  static const _light = AppThemeColors(
    surface: AppColorsLight.surface,
    surfaceContainer: AppColorsLight.surfaceContainer,
    surfaceContainerLow: AppColorsLight.surfaceContainerLow,
    surfaceContainerHigh: AppColorsLight.surfaceContainerHigh,
    surfaceContainerHighest: AppColorsLight.surfaceContainerHighest,
    onSurface: AppColorsLight.onSurface,
    onSurfaceVariant: AppColorsLight.onSurfaceVariant,
    outline: AppColorsLight.outline,
    outlineVariant: AppColorsLight.outlineVariant,
    primary: AppColorsLight.primary,
    primaryContainer: AppColorsLight.primaryContainer,
    onPrimary: AppColorsLight.onPrimary,
    onPrimaryContainer: AppColorsLight.onPrimaryContainer,
    error: AppColorsLight.error,
    errorContainer: AppColorsLight.errorContainer,
    expense: AppColorsLight.expense,
    income: AppColorsLight.income,
    investment: AppColorsLight.investment,
    lend: AppColorsLight.lend,
    borrow: AppColorsLight.borrow,
  );
}

// ─────────────────────────────────────────────
// Theme Data
// ─────────────────────────────────────────────

class AppTheme {
  // Legacy compat shims
  static const Color background = AppColors.surface;
  static const Color surface    = AppColors.surfaceContainer;
  static const Color accent     = AppColors.primary;
  static const Color textPrimary   = AppColors.onSurface;
  static const Color textSecondary = AppColors.onSurfaceVariant;
  static const Color expense    = AppColors.expense;
  static const Color income     = AppColors.income;

  // ── Dark Theme ──────────────────────────────────────────

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    final text = GoogleFonts.interTextTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.surface,
      textTheme: text.apply(
        bodyColor: AppColors.onSurface,
        displayColor: AppColors.onSurface,
      ),
      colorScheme: const ColorScheme.dark(
        brightness: Brightness.dark,
        primary: AppColors.primary,
        primaryContainer: AppColors.primaryContainer,
        onPrimary: AppColors.onPrimary,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondary: AppColors.onSecondary,
        tertiary: AppColors.tertiary,
        tertiaryContainer: AppColors.tertiaryContainer,
        onTertiary: AppColors.onTertiary,
        surface: AppColors.surfaceContainer,
        onSurface: AppColors.onSurface,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        error: AppColors.error,
        errorContainer: AppColors.errorContainer,
        onError: AppColors.onError,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
        inverseSurface: AppColors.inverseSurface,
        onInverseSurface: AppColors.inverseOnSurface,
        inversePrimary: AppColors.inversePrimary,
        surfaceContainerLowest: AppColors.surfaceContainerLowest,
        surfaceContainerLow: AppColors.surfaceContainerLow,
        surfaceContainer: AppColors.surfaceContainer,
        surfaceContainerHigh: AppColors.surfaceContainerHigh,
        surfaceContainerHighest: AppColors.surfaceContainerHighest,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: AppColors.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: AppColors.onSurface),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceContainerLow,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.outlineVariant, width: 0.5),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceContainerLow,
        selectedItemColor: AppColors.onSurface,
        unselectedItemColor: AppColors.onSurfaceVariant,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.outlineVariant, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.onSurface, width: 1),
        ),
        labelStyle: const TextStyle(color: AppColors.onSurfaceVariant),
        hintStyle: const TextStyle(color: AppColors.onSurfaceVariant),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceContainerHighest,
        contentTextStyle: GoogleFonts.inter(color: AppColors.onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.outlineVariant,
        thickness: 0.5,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceContainerHigh,
        selectedColor: AppColors.primary,
        secondarySelectedColor: AppColors.primary,
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
        secondaryLabelStyle: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide.none,
      ),
    );
  }

  // ── Light Theme ─────────────────────────────────────────

  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    final text = GoogleFonts.interTextTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: AppColorsLight.surface,
      textTheme: text.apply(
        bodyColor: AppColorsLight.onSurface,
        displayColor: AppColorsLight.onSurface,
      ),
      colorScheme: const ColorScheme.light(
        brightness: Brightness.light,
        primary: AppColorsLight.primary,
        primaryContainer: AppColorsLight.primaryContainer,
        onPrimary: AppColorsLight.onPrimary,
        onPrimaryContainer: AppColorsLight.onPrimaryContainer,
        surface: AppColorsLight.surfaceContainer,
        onSurface: AppColorsLight.onSurface,
        onSurfaceVariant: AppColorsLight.onSurfaceVariant,
        error: AppColorsLight.error,
        errorContainer: AppColorsLight.errorContainer,
        outline: AppColorsLight.outline,
        outlineVariant: AppColorsLight.outlineVariant,
        inverseSurface: AppColors.surface,
        onInverseSurface: AppColors.onSurface,
        inversePrimary: AppColorsLight.primary,
        surfaceContainerLowest: Color(0xFFFAFAFA),
        surfaceContainerLow: AppColorsLight.surfaceContainerLow,
        surfaceContainer: AppColorsLight.surfaceContainer,
        surfaceContainerHigh: AppColorsLight.surfaceContainerHigh,
        surfaceContainerHighest: AppColorsLight.surfaceContainerHighest,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: AppColorsLight.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: AppColorsLight.onSurface),
      ),
      cardTheme: CardThemeData(
        color: AppColorsLight.surfaceContainer,
        elevation: 0,
        shadowColor: const Color(0x0F000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColorsLight.outlineVariant, width: 0.5),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColorsLight.surfaceContainer,
        selectedItemColor: AppColorsLight.primary,
        unselectedItemColor: AppColorsLight.onSurfaceVariant,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColorsLight.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColorsLight.outlineVariant, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColorsLight.onSurface, width: 1),
        ),
        labelStyle: const TextStyle(color: AppColorsLight.onSurfaceVariant),
        hintStyle: const TextStyle(color: AppColorsLight.onSurfaceVariant),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColorsLight.primary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColorsLight.primary,
          foregroundColor: AppColorsLight.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColorsLight.surfaceContainerHighest,
        contentTextStyle: GoogleFonts.inter(color: AppColorsLight.onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColorsLight.outlineVariant,
        thickness: 0.5,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColorsLight.surfaceContainerHigh,
        selectedColor: AppColorsLight.primary,
        secondarySelectedColor: AppColorsLight.primary,
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
        secondaryLabelStyle: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide.none,
      ),
    );
  }
}
