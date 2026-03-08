import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EndUserColors {
  static const Color background = Color(0xFFF7F8FA);
  static const Color surface = Colors.white;
  static const Color surfaceVariant = Color(0xFFF0F2F5);
  static const Color border = Color(0xFFE2E5EA);
  static const Color textPrimary = Color(0xFF1A1D26);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color navy = Color(0xFF1E293B);
  static const Color accent = Color(0xFF3B82F6);
  static const Color emerald = Color(0xFF10B981);
  static const Color amber = Color(0xFFF59E0B);
  static const Color red = Color(0xFFEF4444);
}

ThemeData buildEndUserTheme() {
  final baseText = GoogleFonts.interTextTheme(ThemeData.light().textTheme);
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: EndUserColors.background,
    colorScheme: const ColorScheme.light(
      surface: EndUserColors.surface,
      primary: EndUserColors.accent,
      secondary: EndUserColors.emerald,
      error: EndUserColors.red,
    ),
    textTheme: baseText.copyWith(
      headlineLarge: baseText.headlineLarge?.copyWith(
        color: EndUserColors.textPrimary,
      ),
      headlineMedium: baseText.headlineMedium?.copyWith(
        color: EndUserColors.textPrimary,
      ),
      bodyLarge: baseText.bodyLarge?.copyWith(color: EndUserColors.textPrimary),
      bodyMedium: baseText.bodyMedium?.copyWith(
        color: EndUserColors.textSecondary,
      ),
    ),
    cardTheme: CardThemeData(
      color: EndUserColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: EndUserColors.border, width: 1),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: EndUserColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 1,
    ),
    dividerColor: EndUserColors.border,
  );
}

TextStyle endUserMono({
  double size = 14,
  Color color = EndUserColors.textPrimary,
  FontWeight weight = FontWeight.w500,
}) {
  return GoogleFonts.robotoMono(
    fontSize: size,
    color: color,
    fontWeight: weight,
  );
}
