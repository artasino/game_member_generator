import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double fabBottomOffset = 80;
}

class AppRadius {
  static const double xs = 2;
  static const double sm = 8;
  static const double md = 10;
  static const double lg = 12;
  static const double sheetTop = 20;
}

class AppTheme {
  static ThemeData light(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(seedColor: Colors.blue).copyWith(
      primary: Colors.blue.shade700,
      secondary: Colors.pink.shade600,
      tertiary: Colors.orange.shade700,
    );
    const offlineFont = kIsWeb && bool.fromEnvironment('OFFLINE_WEB_FONT');
    final baseTextTheme = Theme.of(context).textTheme;
    final textTheme = offlineFont
        ? baseTextTheme.apply(fontFamily: 'OfflineNotoSansJP').copyWith(
              displayMedium: baseTextTheme.displayMedium?.copyWith(
                fontFamily: 'OfflineNotoSansJP',
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
                color: const Color(0xFF2C3E50),
              ),
              labelLarge: baseTextTheme.labelLarge?.copyWith(
                fontFamily: 'OfflineNotoSansJP',
                fontWeight: FontWeight.bold,
              ),
            )
        : GoogleFonts.notoSansJpTextTheme(baseTextTheme).copyWith(
            displayMedium: GoogleFonts.notoSansJp(
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
              color: const Color(0xFF2C3E50),
            ),
            labelLarge: GoogleFonts.kanit(fontWeight: FontWeight.bold),
          );

    return ThemeData(
      colorScheme: colorScheme,
      fontFamily: offlineFont ? 'OfflineNotoSansJP' : null,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.secondaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final style = textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ) ??
              const TextStyle(fontWeight: FontWeight.w500);
          if (states.contains(WidgetState.selected)) {
            return style.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w700,
            );
          }
          return style.copyWith(color: colorScheme.onSurfaceVariant);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.primary, size: 22);
          }
          return IconThemeData(color: colorScheme.onSurfaceVariant, size: 22);
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        selectedColor: colorScheme.secondaryContainer,
        side: BorderSide(color: colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      ),
      textTheme: textTheme,
    );
  }
}
