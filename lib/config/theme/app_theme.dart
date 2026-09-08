import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Application-wide Material 3 theme engine.
///
/// The compact visual density and tabular Inter figures are intentional: the
/// UI is designed to show financial tables, balances, and audit metadata at a
/// high information density without sacrificing legibility.
abstract final class AppTheme {
  static ThemeData get light => _buildTheme(Brightness.light);

  static ThemeData get dark => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final Color background =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final Color surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final Color surfaceMuted =
        isDark ? AppColors.darkSurfaceMuted : AppColors.lightSurfaceMuted;
    final Color border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final Color text = isDark ? AppColors.darkText : AppColors.lightText;
    final Color mutedText =
        isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      surface: surface,
      onSurface: text,
      outline: border,
    );

    final ThemeData baseTheme = ThemeData(
      colorScheme: colorScheme,
      brightness: brightness,
      useMaterial3: true,
      visualDensity: VisualDensity.compact,
      scaffoldBackgroundColor: background,
      fontFamily: GoogleFonts.inter().fontFamily,
    );
    final TextTheme textTheme = _buildTextTheme(baseTheme.textTheme, text);
    final OutlineInputBorder inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: border),
    );

    return baseTheme.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          color: text,
          fontWeight: FontWeight.w700,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        labelStyle: TextStyle(color: mutedText),
        hintStyle: TextStyle(color: mutedText),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowHeight: 40,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 44,
        headingTextStyle: textTheme.labelMedium?.copyWith(
          color: mutedText,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
        dataTextStyle: textTheme.bodySmall?.copyWith(color: text),
        dividerThickness: 0.5,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: AppColors.accent.withAlpha(28),
        selectedIconTheme: const IconThemeData(color: AppColors.accent),
        unselectedIconTheme: IconThemeData(color: mutedText),
        selectedLabelTextStyle: TextStyle(
          color: AppColors.accent,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: TextStyle(color: mutedText),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: mutedText,
          hoverColor: AppColors.accent.withAlpha(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      chipTheme: baseTheme.chipTheme.copyWith(
        backgroundColor: surfaceMuted,
        side: BorderSide(color: border),
        labelStyle: textTheme.labelSmall?.copyWith(color: text),
        padding: const EdgeInsets.symmetric(horizontal: 6),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? AppColors.lightSurface : AppColors.primary,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: TextStyle(
          color: isDark ? AppColors.lightText : Colors.white,
          fontSize: 12,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.accent,
        selectionColor: AppColors.accent.withAlpha(70),
        selectionHandleColor: AppColors.accent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.lightSurface : AppColors.primary,
        contentTextStyle: TextStyle(
          color: isDark ? AppColors.lightText : Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: mutedText,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  static TextTheme _buildTextTheme(TextTheme seed, Color textColor) {
    final TextTheme interTheme = GoogleFonts.interTextTheme(seed).apply(
      bodyColor: textColor,
      displayColor: textColor,
    );
    final List<ui.FontFeature> tabularFigures = <ui.FontFeature>[
      ui.FontFeature.tabularFigures(),
    ];
    final TextStyle interTabular = GoogleFonts.inter(
      fontFeatures: tabularFigures,
    );

    TextStyle numeric(TextStyle? style) => interTabular.merge(style);

    return interTheme.copyWith(
      displayLarge: numeric(interTheme.displayLarge),
      displayMedium: numeric(interTheme.displayMedium),
      displaySmall: numeric(interTheme.displaySmall),
      headlineLarge: numeric(interTheme.headlineLarge),
      headlineMedium: numeric(interTheme.headlineMedium),
      headlineSmall: numeric(interTheme.headlineSmall),
      titleLarge: numeric(interTheme.titleLarge),
      titleMedium: numeric(interTheme.titleMedium),
      titleSmall: numeric(interTheme.titleSmall),
      bodyLarge: numeric(interTheme.bodyLarge),
      bodyMedium: numeric(interTheme.bodyMedium),
      bodySmall: numeric(interTheme.bodySmall),
      labelLarge: numeric(interTheme.labelLarge),
      labelMedium: numeric(interTheme.labelMedium),
      labelSmall: numeric(interTheme.labelSmall),
    );
  }
}
