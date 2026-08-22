import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF0F1C22);
  static const surface = Color(0xFF17282F);
  static const raise = Color(0xFF1E343C);
  static const line = Color(0xFF2A444E);
  static const text = Color(0xFFEEF4F5);
  static const dim = Color(0xFF7F98A2);
  static const faint = Color(0xFF3D5A65);
  static const gold = Color(0xFFD9A441);
  static const onGold = Color(0xFF1A1205);
  static const green = Color(0xFF5FC08B);
  static const red = Color(0xFFE0705C);
}

/// Platform monospace, used for every number so columns stay aligned.
const String kMono = 'monospace';

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: base.colorScheme.copyWith(
      surface: AppColors.surface,
      primary: AppColors.gold,
      onPrimary: AppColors.onGold,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
  );
}

/// Small uppercase mono label used for section headers and tags.
TextStyle labelStyle({Color? color, double size = 10}) => TextStyle(
      fontFamily: kMono,
      fontSize: size,
      letterSpacing: 1.6,
      color: color ?? AppColors.dim,
    );

TextStyle numberStyle({Color? color, double size = 28, FontWeight? weight}) =>
    TextStyle(
      fontFamily: kMono,
      fontSize: size,
      fontWeight: weight ?? FontWeight.w600,
      color: color ?? AppColors.gold,
      height: 1,
    );
