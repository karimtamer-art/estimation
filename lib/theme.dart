import 'package:flutter/material.dart';

import 'models.dart';

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
  static const blue = Color(0xFF57A6E0);

  /// Labels laid over [red] and [blue] at full strength.
  static const onRed = Color(0xFF3A0D05);
  static const onBlue = Color(0xFF04202F);
  static const red = Color(0xFFE0705C);
}

/// Each game length carries its own accent, so the picker reads at a glance
/// and the chosen length keeps that colour on the screen after it.
extension ModeAccent on GameMode {
  Color get accent => const {
        GameMode.micro: Color(0xFF5FC08B),
        GameMode.mini: Color(0xFF57A6E0),
        GameMode.full: Color(0xFFD9A441),
      }[this]!;

  /// Text laid over [accent] at full strength.
  Color get onAccent => const {
        GameMode.micro: Color(0xFF06241A),
        GameMode.mini: Color(0xFF041825),
        GameMode.full: Color(0xFF1A1205),
      }[this]!;
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

/// The picker draws each length as a glossy button, so every accent also
/// carries a bright top, a deep bottom and a dark rim to bevel against.
extension ModeFace on GameMode {
  /// Top of the button face.
  Color get faceHi => const {
        GameMode.micro: Color(0xFF63E39B),
        GameMode.mini: Color(0xFF62B8F7),
        GameMode.full: Color(0xFFF7C948),
      }[this]!;

  /// Bottom of the button face.
  Color get faceLo => const {
        GameMode.micro: Color(0xFF12864A),
        GameMode.mini: Color(0xFF1358B4),
        GameMode.full: Color(0xFFC26A12),
      }[this]!;

  /// Outline that makes the face sit proud of the background.
  Color get faceRim => const {
        GameMode.micro: Color(0xFF073E22),
        GameMode.mini: Color(0xFF072A52),
        GameMode.full: Color(0xFF4A2905),
      }[this]!;
}

/// One colour per seat, used wherever the four players have to be told apart
/// at a glance — the score graph draws a line per seat in these.
const List<Color> kSeatColors = [
  Color(0xFFF7C948),
  Color(0xFF5AB8F7),
  Color(0xFF5FE0A0),
  Color(0xFFFF7F6B),
];

Color seatColor(int index) => kSeatColors[index % kSeatColors.length];
