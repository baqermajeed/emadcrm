import 'package:flutter/material.dart';

/// Design tokens from Figma Desktop-31 (reception home).
class ReceptionTokens {
  static const Color bg = Color(0xFFF6FCFF);
  static const Color navy = Color(0xFF002E45);
  static const Color teal = Color(0xFF069BAF);
  static const Color confirmBlue = Color(0xFF0178BE);
  static const Color linkBlue = Color(0xFF1E7AA8);
  static const Color rowAlt = Color(0xFFE7F5F7);
  static const Color plusBg = Color(0xFFE2F5FA);
  static const Color statusGreenBg = Color(0xFF9FD0C0);
  static const Color statusGreenText = Color(0xFF00661B);
  static const Color statusYellowBg = Color(0x66FFE330);
  static const Color statusYellowText = Color(0xFFFFAE4C);
  static const Color muted = Color(0x80002E45);
  static const Color fieldBorder = Color(0x66002E45);

  static const double sidebarWidth = 266;
  static const double radius = 16;
  static const double radiusSm = 8;
  static const double radiusMd = 10;

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: teal.withValues(alpha: 0.23),
          blurRadius: 5,
          offset: Offset.zero,
        ),
      ];

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: teal.withValues(alpha: 0.23),
          blurRadius: 10,
          offset: Offset.zero,
        ),
      ];
}
