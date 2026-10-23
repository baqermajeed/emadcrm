import 'package:flutter/material.dart';

/// Bundled Arabic font — no network fetch (unlike Google Fonts).
abstract final class AppFonts {
  static const String family = 'LamaSans';

  static TextStyle style({
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    Color? color,
    double? height,
    double? letterSpacing,
    TextDecoration? decoration,
    Color? decorationColor,
    TextOverflow? overflow,
    List<Shadow>? shadows,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      decoration: decoration,
      decorationColor: decorationColor,
      overflow: overflow,
      shadows: shadows,
    );
  }

  static TextTheme textTheme([TextTheme? base]) {
    final source = base ?? ThemeData.light().textTheme;
    return source.apply(fontFamily: family);
  }
}
