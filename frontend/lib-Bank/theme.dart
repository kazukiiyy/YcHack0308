import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color background = Color(0xFF0F1923);
  static const Color surface = Color(0xFF1A2635);
  static const Color surfaceVariant = Color(0xFF223044);
  static const Color border = Color(0xFF2D3F52);
  static const Color textPrimary = Color(0xFFE8EDF2);
  static const Color textSecondary = Color(0xFF8899AA);
  static const Color accent = Color(0xFF3B82F6);
  static const Color emerald = Color(0xFF10B981);
  static const Color emeraldDim = Color(0xFF065F46);
  static const Color amber = Color(0xFFF59E0B);
  static const Color red = Color(0xFFEF4444);
  static const Color sidebarBg = Color(0xFF0D1520);
}

ThemeData buildAppTheme() {
  final baseText = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      surface: AppColors.surface,
      primary: AppColors.accent,
      secondary: AppColors.emerald,
      error: AppColors.red,
    ),
    textTheme: baseText.copyWith(
      headlineLarge: baseText.headlineLarge?.copyWith(color: AppColors.textPrimary),
      headlineMedium: baseText.headlineMedium?.copyWith(color: AppColors.textPrimary),
      bodyLarge: baseText.bodyLarge?.copyWith(color: AppColors.textPrimary),
      bodyMedium: baseText.bodyMedium?.copyWith(color: AppColors.textSecondary),
      labelSmall: baseText.labelSmall?.copyWith(color: AppColors.textSecondary),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
    ),
    dividerColor: AppColors.border,
  );
}

TextStyle monoStyle({double size = 14, Color color = AppColors.textPrimary, FontWeight weight = FontWeight.w500}) {
  return GoogleFonts.robotoMono(fontSize: size, color: color, fontWeight: weight);
}
