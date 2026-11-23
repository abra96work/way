import 'package:flutter/material.dart';

/// Design tokens of the driver screens (names follow the Figma variables).
abstract final class DriverColors {
  static const background = Color(0xFFF1F2F3); // Accent-background
  static const surface = Colors.white; // Accent-white
  static const primary = Color(0xFF1EB74D); // Accent-primary
  static const text = Color(0xFF0C0C0C); // Accent-text-primary
  static const secondaryText = Color(0x7F0C0C0C); // Accent-text-secondary
  static const divider = Color(0xFFE4E5E6); // White-Shades-White-90
}

abstract final class DriverText {
  static const title = TextStyle(
    color: DriverColors.text,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );
  static const label = TextStyle(
    color: DriverColors.text,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.33,
  );
  static const cardTitle = TextStyle(
    color: DriverColors.text,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    height: 1.29,
  );
  static const body = TextStyle(
    color: DriverColors.secondaryText,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.33,
  );
}
