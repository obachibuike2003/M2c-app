import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The website's design tokens (css/style.css :root), as Flutter colours.
class Brand {
  static const red = Color(0xFFE0182D);
  static const red600 = Color(0xFFC81226);
  static const red700 = Color(0xFFA30D1D);
  static const redSoft = Color(0xFFFDEAED);
  static const yellow = Color(0xFFFFC83D);
  static const ink = Color(0xFF111216);
  static const text = Color(0xFF2A2C33);
  static const muted = Color(0xFF62666F);
  static const line = Color(0xFFE8E9EE);
  static const bg = Color(0xFFF5F5F7);
  static const green = Color(0xFF0B7A43);
  static const greenSoft = Color(0xFFE4F5EB);
  static const blue = Color(0xFF1D4ED8);
  static const blueSoft = Color(0xFFE8EEFD);
  static const star = Color(0xFFF5A50B);

  static const radius = 18.0;
  static const radiusSm = 12.0;

  static List<BoxShadow> get shadow => const [
        BoxShadow(color: Color(0x0A111216), blurRadius: 2, offset: Offset(0, 1)),
        BoxShadow(color: Color(0x0F111216), blurRadius: 24, offset: Offset(0, 8)),
      ];

  /// Headings use Outfit, body text Plus Jakarta Sans, like the site.
  static TextStyle head(double size, {FontWeight weight = FontWeight.w700, Color color = ink}) =>
      GoogleFonts.outfit(fontSize: size, fontWeight: weight, color: color, height: 1.15);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: Brand.red, primary: Brand.red, surface: Colors.white),
    scaffoldBackgroundColor: Brand.bg,
  );
  final body = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(bodyColor: Brand.text, displayColor: Brand.ink);
  return base.copyWith(
    textTheme: body,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Brand.ink,
      elevation: 0,
      scrolledUnderElevation: 1,
      titleTextStyle: Brand.head(20),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Brand.red,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 50),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Brand.ink,
        minimumSize: const Size(48, 50),
        side: const BorderSide(color: Color(0xFFCFD1D8)),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(Brand.radiusSm), borderSide: const BorderSide(color: Color(0xFFD3D5DC))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Brand.radiusSm), borderSide: const BorderSide(color: Color(0xFFD3D5DC))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Brand.radiusSm), borderSide: const BorderSide(color: Brand.red, width: 2)),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Colors.white,
      selectedColor: Brand.ink,
      side: const BorderSide(color: Color(0xFFD3D5DC)),
      shape: const StadiumBorder(),
      labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: Brand.ink),
      secondaryLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: Colors.white),
      showCheckmark: false,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: Brand.ink),
  );
}
