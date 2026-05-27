import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF534AB7);
  static const Color primaryDark = Color(0xFF1a1a2e);
  static const Color success = Color(0xFF3B6D11);
  static const Color warning = Color(0xFF854F0B);
  static const Color danger = Color(0xFFA32D2D);
  static const Color successBg = Color(0xFFEAF3DE);
  static const Color warningBg = Color(0xFFFAEEDA);
  static const Color dangerBg = Color(0xFFFCEBEB);
  static const Color primaryBg = Color(0xFFEEEDFE);

  static ThemeData get theme => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: primary),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryDark,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: primary,
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primary,
          foregroundColor: Colors.white,
        ),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          color: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      );
}
