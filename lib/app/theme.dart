import 'package:flutter/material.dart';

abstract final class Palette {
  static const navy = Color(0xff102f49);
  static const turquoise = Color(0xff15a89a);
  static const cream = Color(0xfffff6e7);
  static const gold = Color(0xfff4b744);
  static const coral = Color(0xffe96b62);
  static const tealInk = Color(0xff08685f);
  static const redInk = Color(0xff982f2d);
  static const paper = Color(0xfffffcf6);
  static const muted = Color(0xff496376);
  static const line = Color(0xffe4d9c6);
  static const mint = Color(0xffe0f4eb);
  static const blush = Color(0xffffe8e2);
}

ThemeData rahalaTheme() {
  const scheme = ColorScheme.light(
    primary: Palette.navy,
    onPrimary: Palette.cream,
    primaryContainer: Palette.mint,
    onPrimaryContainer: Palette.navy,
    secondary: Palette.tealInk,
    onSecondary: Colors.white,
    secondaryContainer: Palette.mint,
    onSecondaryContainer: Palette.navy,
    surface: Palette.paper,
    onSurface: Palette.navy,
    onSurfaceVariant: Palette.muted,
    outline: Palette.muted,
    outlineVariant: Palette.line,
    error: Palette.redInk,
    errorContainer: Palette.blush,
    onErrorContainer: Palette.redInk,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.cream,
    fontFamily: 'NotoSansArabic',
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.cream,
      foregroundColor: Palette.navy,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    dividerTheme: const DividerThemeData(color: Palette.line),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Palette.paper,
      indicatorColor: Palette.mint,
      height: 68,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(15)),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        side: const BorderSide(color: Palette.muted),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(15)),
        ),
      ),
    ),
    inputDecorationTheme: const InputDecorationThemeData(
      filled: true,
      fillColor: Palette.paper,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
    ),
  );
}

String digits(int value) => value.toString().split('').map((digit) {
  final index = int.tryParse(digit);
  return index == null ? digit : '٠١٢٣٤٥٦٧٨٩'[index];
}).join();

TextStyle heading(BuildContext context, {double size = 23, Color? color}) =>
    TextStyle(
      fontFamily: 'NotoSansArabic',
      fontSize: size,
      color: color ?? Theme.of(context).colorScheme.onSurface,
      fontWeight: FontWeight.w800,
      height: 1.28,
    );
