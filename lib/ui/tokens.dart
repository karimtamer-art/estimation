import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models.dart';

/// The "navy game" palette. Every colour the redesign paints with is named
/// here; the widgets in this folder never write a hex of their own.
class Palette {
  /// Outline and hard drop shadow on every raised piece.
  static const outline = Color(0xFF050505);

  static const gold = Color(0xFFFFD23F);
  static const goldHi = Color(0xFFFFE55C);
  static const goldLo = Color(0xFFF2B705);

  static const silverHi = Color(0xFFFFFFFF);
  static const silverLo = Color(0xFFC8CCD0);

  static const darkHi = Color(0xFF3A4766);
  static const darkLo = Color(0xFF1D2540);

  static const greenHi = Color(0xFF8CF0A8);
  static const greenLo = Color(0xFF33B567);
  static const onGreen = Color(0xFF0B2A16);
  static const greenText = Color(0xFF8CF0A8);

  static const redHi = Color(0xFFFFA594);
  static const redLo = Color(0xFFE0533F);
  static const redText = Color(0xFFFF8F7A);

  static const orangeHi = Color(0xFFFFB38A);
  static const orangeLo = Color(0xFFF07A2B);

  static const riskHi = Color(0xFFFF7A63);
  static const riskLo = Color(0xFFD9402C);

  static const disabledHi = Color(0xFF3A4440);
  static const disabledLo = Color(0xFF252D2A);
  static const disabledText = Color(0xFF8E9A95);

  static const inset = Color(0xFF0A1128);

  static const text = Color(0xFFFFFFFF);
  static const secondary = Color(0xFFB5BFD6);
  static const muted = Color(0xFF8E9BBD);
  static const onGold = Color(0xFF1A1A17);

  /// The made-it frame on an avatar.
  static const madeFrame = Color(0xFF4FD27E);
  static const plainFrame = Color(0xFFE4EAE7);

  static const panel = Color(0x38000000); // rgba(0,0,0,0.22)
  static const panelBorder = Color(0x4D000000); // rgba(0,0,0,0.3)
  static const bar = Color(0x42000000); // rgba(0,0,0,0.26)
  static const barBorder = Color(0x59000000); // rgba(0,0,0,0.35)

  static const roundRedHi = Color(0xFFE8473A);
  static const roundRedLo = Color(0xFFB8261C);
  static const creamHi = Color(0xFFFFFBEF);
  static const creamLo = Color(0xFFE9DCB8);

  /// Suit colours on a silver plaque or a light chip.
  static const suitRed = Color(0xFFE0261B);
  static const suitBlack = Color(0xFF1A1A17);
  static const suitSun = Color(0xFFF2A705);
}

/// The four table cloths offered in Settings. Navy is the house felt.
enum Felt { navy, burgundy, charcoal, purple }

extension FeltTones on Felt {
  /// Centre, mid (58%) and edge of the radial wash.
  List<Color> get tones => const {
        Felt.navy: [Color(0xFF22407A), Color(0xFF152B57), Color(0xFF0B1838)],
        Felt.burgundy: [
          Color(0xFF6E1F2E),
          Color(0xFF4A1420),
          Color(0xFF2A0B12)
        ],
        Felt.charcoal: [
          Color(0xFF3A3F47),
          Color(0xFF262A30),
          Color(0xFF15181C)
        ],
        Felt.purple: [Color(0xFF4B2A7A), Color(0xFF321B56), Color(0xFF1C0F33)],
      }[this]!;

  String label(bool ar) => ar
      ? const {
          Felt.navy: 'كحلي',
          Felt.burgundy: 'خمري',
          Felt.charcoal: 'فحمي',
          Felt.purple: 'بنفسجي',
        }[this]!
      : const {
          Felt.navy: 'Navy',
          Felt.burgundy: 'Burgundy',
          Felt.charcoal: 'Charcoal',
          Felt.purple: 'Purple',
        }[this]!;
}

/// A top-to-bottom two-stop fill, the face of every raised piece.
LinearGradient vgrad(Color hi, Color lo) => LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [hi, lo],
    );

/// The hard, unblurred drop shadow under buttons, badges and plaques.
List<BoxShadow> hardShadow([double dy = 4]) => [
      BoxShadow(offset: Offset(0, dy), blurRadius: 0, color: Palette.outline),
    ];

const _numberShadow = [
  Shadow(offset: Offset(0, 2), blurRadius: 0, color: Color(0x80050505)),
];

/// Lilita One for headings, numbers, badges and button labels. It has no
/// Arabic, so Arabic falls through to Lalezar, the closest display weight.
TextStyle display(
  double size, {
  Color color = Palette.text,
  double spacing = 0,
  bool shadow = false,
  double? height,
}) =>
    GoogleFonts.lilitaOne(
      fontSize: size,
      color: color,
      letterSpacing: size * spacing,
      height: height,
      shadows: shadow ? _numberShadow : null,
    ).copyWith(fontFamilyFallback: [GoogleFonts.lalezar().fontFamily!]);

/// Nunito for names (900) and helper text (700); Arabic falls to Cairo.
TextStyle body(
  double size, {
  FontWeight weight = FontWeight.w700,
  Color color = Palette.text,
}) =>
    GoogleFonts.nunito(fontSize: size, fontWeight: weight, color: color)
        .copyWith(fontFamilyFallback: [GoogleFonts.cairo().fontFamily!]);

/// The colour a suit is printed in on a light face.
Color suitInk(Suit s) => s == Suit.sun
    ? Palette.suitSun
    : s.isRed
        ? Palette.suitRed
        : Palette.suitBlack;

/// Mockup spacing: 24 at the sides, 18 top and bottom, 14–16 between bands.
/// Each seat's colour on the scoresheet, in seat order: its dot by the name
/// and its line on the chart.
const kSeatInk = [
  Color(0xFFFFD23F),
  Color(0xFF4DA3FF),
  Color(0xFF4FD27E),
  Color(0xFFFF6B5B),
];

class Gap {
  static const side = 24.0;
  static const edge = 18.0;
  static const band = 14.0;
  static const cards = 16.0;
}

/// A points figure with its sign, as it reads on the sheet: +16, −4, 0.
/// Wrapped as a left-to-right run so Arabic text around it cannot flip the
/// sign to the far end of the number.
String signedPoints(int v, {bool plus = true}) {
  final t = v < 0
      ? '${String.fromCharCode(0x2212)}${-v}'
      : (v > 0 && plus ? '+$v' : '$v');
  if (t == '$v') return t;
  return '${String.fromCharCode(0x2066)}$t${String.fromCharCode(0x2069)}';
}

/// The light tap under the finger on a button press. Switched from
/// Settings; the app keeps [on] in step with the saved preference.
class Haptics {
  static bool on = true;

  static void tap() {
    if (on) HapticFeedback.selectionClick();
  }

  /// A sheet settling open or shut.
  static void snap() {
    if (on) HapticFeedback.lightImpact();
  }
}
