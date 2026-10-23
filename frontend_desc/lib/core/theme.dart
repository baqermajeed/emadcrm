import 'package:flutter/material.dart';

import 'app_fonts.dart';

class AppTheme {
  static const Color primary = Color(0xFF1B4D3E);
  static const Color accent = Color(0xFFC4A35A);
  static const Color surface = Color(0xFFF7F4EF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color danger = Color(0xFFB42318);
  static const Color success = Color(0xFF027A48);

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: AppFonts.family,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: accent,
        surface: surface,
      ),
      scaffoldBackgroundColor: surface,
    );

    return base.copyWith(
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _OptimisticPageTransitionsBuilder(),
          TargetPlatform.iOS: _OptimisticPageTransitionsBuilder(),
          TargetPlatform.macOS: _OptimisticPageTransitionsBuilder(),
          TargetPlatform.windows: _OptimisticPageTransitionsBuilder(),
          TargetPlatform.linux: _OptimisticPageTransitionsBuilder(),
          TargetPlatform.fuchsia: _OptimisticPageTransitionsBuilder(),
        },
      ),
      textTheme: AppFonts.textTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppFonts.style(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: AppFonts.style(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _OptimisticPageTransitionsBuilder extends PageTransitionsBuilder {
  const _OptimisticPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final fade = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    final slide = Tween<Offset>(
      begin: const Offset(0.02, 0),
      end: Offset.zero,
    ).animate(fade);
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }
}
