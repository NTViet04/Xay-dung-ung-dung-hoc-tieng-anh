import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Theme Material 3 bám token thiết kế (không dùng viền 1px để tách section — ưu tiên lớp surface).
ThemeData buildAppTheme() {
  final base = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    primaryContainer: AppColors.primaryContainer,
    secondary: AppColors.secondary,
    surface: AppColors.surface,
    onSurface: AppColors.onSurface,
    error: AppColors.error,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: base.copyWith(
      surfaceContainerLow: AppColors.surfaceContainerLow,
      surfaceContainerHighest: AppColors.surfaceContainerHighest,
    ),
    scaffoldBackgroundColor: AppColors.surface,
    textTheme: TextTheme(
      displaySmall: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface,
      ),
      titleLarge: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      ),
      titleMedium: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      ),
      bodyLarge: GoogleFonts.inter(color: AppColors.onSurface),
      bodyMedium: GoogleFonts.inter(color: AppColors.onSurfaceVariant),
      labelMedium: GoogleFonts.robotoMono(
        fontWeight: FontWeight.w500,
        color: AppColors.onSurfaceVariant,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surface.withValues(alpha: 0.8),
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
        fontSize: 18,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surfaceContainerLowest,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    ),
  );
}
