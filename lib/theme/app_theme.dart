import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    scaffoldBackgroundColor: const Color(0xff090B10),

    splashFactory: NoSplash.splashFactory,

    colorScheme: const ColorScheme.dark(
      primary: Color(0xff9A7CFF),
      secondary: Color(0xffB388FF),
      surface: Color(0xff111318),
    ),

    textTheme: GoogleFonts.interTextTheme(
      ThemeData.dark().textTheme,
    ).apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),

    dividerColor: Colors.white10,

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
  );
}