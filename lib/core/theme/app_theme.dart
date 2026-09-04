import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_tokens.dart';

class AppTheme {
  static ThemeData get light => _build(OrbitColors.light, Brightness.light);

  static ThemeData get dark => _build(OrbitColors.dark, Brightness.dark);

  static TextTheme buildTextTheme(OrbitColors colors) {
    final display = GoogleFonts.spaceGroteskTextTheme();
    final body = GoogleFonts.ibmPlexSansTextTheme();

    return TextTheme(
      displaySmall: display.displaySmall?.copyWith(
        fontSize: 34,
        height: 1.1,
        letterSpacing: -0.8,
        fontWeight: FontWeight.w600,
        color: colors.ink,
      ),
      headlineMedium: display.headlineMedium?.copyWith(
        fontSize: 27,
        height: 1.15,
        letterSpacing: -0.5,
        fontWeight: FontWeight.w600,
        color: colors.ink,
      ),
      headlineSmall: display.headlineSmall?.copyWith(
        fontSize: 22,
        height: 1.2,
        letterSpacing: -0.3,
        fontWeight: FontWeight.w600,
        color: colors.ink,
      ),
      titleLarge: display.titleLarge?.copyWith(
        fontSize: 19,
        height: 1.25,
        letterSpacing: -0.2,
        fontWeight: FontWeight.w600,
        color: colors.ink,
      ),
      titleMedium: display.titleMedium?.copyWith(
        fontSize: 16,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: colors.ink,
      ),
      bodyLarge: body.bodyLarge?.copyWith(
        fontSize: 16,
        height: 1.5,
        color: colors.ink,
      ),
      bodyMedium: body.bodyMedium?.copyWith(
        fontSize: 14.5,
        height: 1.5,
        color: colors.inkMuted,
      ),
      bodySmall: body.bodySmall?.copyWith(
        fontSize: 13,
        height: 1.45,
        color: colors.inkMuted,
      ),
      labelLarge: body.labelLarge?.copyWith(
        fontSize: 14.5,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: colors.ink,
      ),
      labelMedium: body.labelMedium?.copyWith(
        fontSize: 13,
        height: 1.2,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        color: colors.inkMuted,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      labelSmall: body.labelSmall?.copyWith(
        fontSize: 12,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: colors.inkMuted,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  static ThemeData _build(OrbitColors colors, Brightness brightness) {
    final textTheme = buildTextTheme(colors);

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: colors.accent,
      onPrimary: colors.accentContrast,
      primaryContainer: colors.accentWash,
      onPrimaryContainer: colors.accentInk,
      secondary: colors.success,
      onSecondary: colors.surface,
      secondaryContainer: colors.successWash,
      onSecondaryContainer: colors.success,
      error: colors.urgent,
      onError: colors.surface,
      errorContainer: colors.urgentWash,
      onErrorContainer: colors.urgent,
      surface: colors.surface,
      onSurface: colors.ink,
      onSurfaceVariant: colors.inkMuted,
      outline: colors.border,
      outlineVariant: colors.border,
      surfaceContainerHighest: colors.surfaceSunken,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.surface,
      canvasColor: colors.surface,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: colors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OrbitRadius.card),
          side: BorderSide(color: colors.border),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.border,
        space: 1,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceRaised,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: OrbitSpacing.lg,
          vertical: OrbitSpacing.lg,
        ),
        labelStyle: textTheme.bodyMedium,
        floatingLabelStyle: textTheme.labelMedium?.copyWith(
          color: colors.accentInk,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: colors.inkFaint),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OrbitRadius.control),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OrbitRadius.control),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OrbitRadius.control),
          borderSide: BorderSide(color: colors.accentEdge, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OrbitRadius.control),
          borderSide: BorderSide(color: colors.urgent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OrbitRadius.control),
          borderSide: BorderSide(color: colors.urgent, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: colors.surfaceSunken,
          disabledForegroundColor: colors.inkFaint,
          minimumSize: const Size.fromHeight(52),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(OrbitRadius.control),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.inkMuted,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(OrbitRadius.control),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.ink,
          minimumSize: const Size.fromHeight(52),
          textStyle: textTheme.labelLarge,
          side: BorderSide(color: colors.borderStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(OrbitRadius.control),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: colors.surface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OrbitRadius.control),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.accent,
        linearTrackColor: colors.surfaceSunken,
        circularTrackColor: colors.surfaceSunken,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.accent
              : colors.inkFaint,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.accentWash
              : colors.surfaceSunken,
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: colors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OrbitRadius.sheet),
        ),
      ),
    );
  }
}
