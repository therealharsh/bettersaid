import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors - Apple 2025 Inspired
  static const Color deepBlue = Color(0xFF1E3A8A);
  static const Color lavender = Color(0xFF8B5CF6);
  static const Color mutedTeal = Color(0xFF14B8A6);
  static const Color offWhite = Color(0xFFF9FAFB);
  static const Color charcoalGray = Color(0xFF111827);
  
  // Light Theme Colors
  static const Color titleLight = Color(0xFF0F172A);
  static const Color bodyLight = Color(0xFF374151);
  static const Color mutedLight = Color(0xFF6B7280);
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color surfaceLight = Color(0xFFFAFAFA);
  static const Color backgroundLight = Color(0xFFFFFFFF);
  
  // Dark Theme Colors
  static const Color backgroundDark = Color(0xFF0B1220);
  static const Color surfaceDark = Color(0xFF1F2937);
  static const Color textDark = Color(0xFFF3F4F6);
  static const Color mutedDark = Color(0xFF9CA3AF);
  static const Color borderDark = Color(0xFF374151);
  
  // Status Colors
  static const Color danger = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [deepBlue, Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient lavenderGradient = LinearGradient(
    colors: [lavender, Color(0xFFA78BFA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient tealGradient = LinearGradient(
    colors: [mutedTeal, Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Animation Curves
  static const Curve gentleEase = Curves.easeOutCubic;
  static const Duration quickTransition = Duration(milliseconds: 200);
  static const Duration smoothTransition = Duration(milliseconds: 300);
  static const Duration calmTransition = Duration(milliseconds: 400);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: deepBlue,
        secondary: lavender,
        tertiary: mutedTeal,
        surface: surfaceLight,
        background: backgroundLight,
        error: danger,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onTertiary: Colors.white,
        onSurface: titleLight,
        onBackground: titleLight,
        outline: borderLight,
        surfaceVariant: offWhite,
        onSurfaceVariant: bodyLight,
      ),
      textTheme: _buildTextTheme(titleLight, bodyLight, mutedLight),
      elevatedButtonTheme: _buildElevatedButtonTheme(true),
      outlinedButtonTheme: _buildOutlinedButtonTheme(true),
      textButtonTheme: _buildTextButtonTheme(true),
      inputDecorationTheme: _buildInputDecorationTheme(true),
      cardTheme: _buildCardTheme(true),
      appBarTheme: _buildAppBarTheme(true),
      dialogTheme: _buildDialogTheme(true),
      snackBarTheme: _buildSnackBarTheme(true),
    );
  }
  
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: deepBlue,
        secondary: lavender,
        tertiary: mutedTeal,
        surface: surfaceDark,
        background: backgroundDark,
        error: danger,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onTertiary: Colors.white,
        onSurface: textDark,
        onBackground: textDark,
        outline: borderDark,
        surfaceVariant: charcoalGray,
        onSurfaceVariant: mutedDark,
      ),
      textTheme: _buildTextTheme(textDark, textDark, mutedDark),
      elevatedButtonTheme: _buildElevatedButtonTheme(false),
      outlinedButtonTheme: _buildOutlinedButtonTheme(false),
      textButtonTheme: _buildTextButtonTheme(false),
      inputDecorationTheme: _buildInputDecorationTheme(false),
      cardTheme: _buildCardTheme(false),
      appBarTheme: _buildAppBarTheme(false),
      dialogTheme: _buildDialogTheme(false),
      snackBarTheme: _buildSnackBarTheme(false),
    );
  }

  static TextTheme _buildTextTheme(Color title, Color body, Color muted) {
    return GoogleFonts.interTextTheme().copyWith(
      // Display styles - Large, airy headers
      displayLarge: GoogleFonts.inter(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        color: title,
        height: 1.1,
        letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: title,
        height: 1.15,
        letterSpacing: -0.25,
      ),
      displaySmall: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: title,
        height: 1.2,
      ),
      
      // Headline styles - Section headers
      headlineLarge: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: title,
        height: 1.25,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: title,
        height: 1.3,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: title,
        height: 1.3,
      ),
      
      // Title styles - Component titles
      titleLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: title,
        height: 1.35,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: title,
        height: 1.4,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: title,
        height: 1.4,
      ),
      
      // Body styles - Calm, readable text
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: body,
        height: 1.6,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: body,
        height: 1.6,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: muted,
        height: 1.5,
      ),
      
      // Label styles - Subtle, muted
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: title,
        height: 1.4,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: muted,
        height: 1.4,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: muted,
        height: 1.4,
        letterSpacing: 0.5,
      ),
    );
  }

  static ElevatedButtonThemeData _buildElevatedButtonTheme(bool isLight) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: deepBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
        shadowColor: Colors.transparent,
        textStyle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ).copyWith(
        backgroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.pressed)) {
            return deepBlue.withOpacity(0.8);
          }
          if (states.contains(MaterialState.hovered)) {
            return deepBlue.withOpacity(0.9);
          }
          return deepBlue;
        }),
        overlayColor: MaterialStateProperty.all(Colors.white.withOpacity(0.1)),
      ),
    );
  }

  static OutlinedButtonThemeData _buildOutlinedButtonTheme(bool isLight) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: deepBlue,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        side: BorderSide(
          color: isLight ? borderLight : borderDark,
          width: 1.5,
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ).copyWith(
        side: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.pressed)) {
            return BorderSide(color: deepBlue, width: 2);
          }
          if (states.contains(MaterialState.hovered)) {
            return BorderSide(color: deepBlue, width: 1.5);
          }
          return BorderSide(
            color: isLight ? borderLight : borderDark,
            width: 1.5,
          );
        }),
        backgroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.pressed)) {
            return deepBlue.withOpacity(0.05);
          }
          if (states.contains(MaterialState.hovered)) {
            return deepBlue.withOpacity(0.02);
          }
          return Colors.transparent;
        }),
      ),
    );
  }

  static TextButtonThemeData _buildTextButtonTheme(bool isLight) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: deepBlue,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ),
      ).copyWith(
        overlayColor: MaterialStateProperty.all(deepBlue.withOpacity(0.08)),
      ),
    );
  }

  static InputDecorationTheme _buildInputDecorationTheme(bool isLight) {
    return InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isLight ? borderLight : borderDark,
          width: 1.5,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isLight ? borderLight : borderDark,
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: deepBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: danger, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: danger, width: 2),
      ),
      filled: true,
      fillColor: isLight ? surfaceLight : surfaceDark,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: GoogleFonts.inter(
        color: isLight ? mutedLight : mutedDark,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      labelStyle: GoogleFonts.inter(
        color: isLight ? bodyLight : textDark,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      floatingLabelStyle: GoogleFonts.inter(
        color: deepBlue,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  static CardThemeData _buildCardTheme(bool isLight) {
    return CardThemeData(
      color: isLight ? surfaceLight : surfaceDark,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isLight ? borderLight : borderDark,
          width: 1,
        ),
      ),
      margin: EdgeInsets.zero,
    );
  }

  static AppBarTheme _buildAppBarTheme(bool isLight) {
    return AppBarTheme(
      backgroundColor: isLight ? backgroundLight : backgroundDark,
      foregroundColor: isLight ? titleLight : textDark,
      elevation: 0,
      shadowColor: Colors.transparent,
      centerTitle: false,
      titleSpacing: 0,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: isLight ? titleLight : textDark,
        height: 1.2,
      ),
      iconTheme: IconThemeData(
        color: isLight ? titleLight : textDark,
        size: 24,
      ),
      actionsIconTheme: IconThemeData(
        color: isLight ? titleLight : textDark,
        size: 24,
      ),
    );
  }

  static DialogThemeData _buildDialogTheme(bool isLight) {
    return DialogThemeData(
      backgroundColor: isLight ? backgroundLight : backgroundDark,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isLight ? borderLight : borderDark,
          width: 1,
        ),
      ),
      titleTextStyle: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: isLight ? titleLight : textDark,
      ),
      contentTextStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: isLight ? bodyLight : textDark,
        height: 1.5,
      ),
    );
  }

  static SnackBarThemeData _buildSnackBarTheme(bool isLight) {
    return SnackBarThemeData(
      backgroundColor: isLight ? charcoalGray : surfaceDark,
      contentTextStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
    );
  }

  // Helper methods for glassmorphism effects
  static BoxDecoration glassContainer({
    required bool isLight,
    double opacity = 0.1,
    double blur = 10,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: isLight 
          ? Colors.white.withOpacity(opacity)
          : Colors.white.withOpacity(opacity * 0.1),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: borderColor ?? (isLight ? borderLight : borderDark),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: isLight 
              ? Colors.black.withOpacity(0.05)
              : Colors.black.withOpacity(0.2),
          blurRadius: blur,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static BoxDecoration elevatedGlassContainer({
    required bool isLight,
    double opacity = 0.15,
    double blur = 20,
  }) {
    return BoxDecoration(
      color: isLight 
          ? Colors.white.withOpacity(opacity)
          : Colors.white.withOpacity(opacity * 0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: isLight ? borderLight : borderDark,
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: isLight 
              ? Colors.black.withOpacity(0.08)
              : Colors.black.withOpacity(0.3),
          blurRadius: blur,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: isLight 
              ? Colors.black.withOpacity(0.04)
              : Colors.black.withOpacity(0.1),
          blurRadius: blur * 0.5,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}
