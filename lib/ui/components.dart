import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import 'avatars.dart';
import 'tokens.dart';

// ------------------------------------------------------------------- felt

/// The table: a radial wash centred a third of the way down, with a faint
/// dot weave over it. Every screen of the redesign sits on one of these.
class FeltBackground extends StatelessWidget {
  final Felt felt;
  final Widget child;
  const FeltBackground({super.key, this.felt = Felt.navy, required this.child});

  @override
  Widget build(BuildContext context) {
    final t = felt.tones;
    return LayoutBuilder(builder: (context, box) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.36),
            radius: 1.0,
            colors: t,
            stops: const [0, 0.58, 1],
            // CSS "ellipse": stretch the circle to the box, not the short side.
            transform: _Ellipse(box.maxWidth, box.maxHeight),
          ),
        ),
        child: CustomPaint(
            painter: const _Weave(), child: SizedBox.expand(child: child)),
      );
    });
  }
}

class _Ellipse extends GradientTransform {
  final double w, h;
  const _Ellipse(this.w, this.h);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    if (!w.isFinite || !h.isFinite || h == 0) return null;
    // Farthest-corner sizing, as the browser does it for an ellipse.
    final cx = bounds.center.dx;
    final cy = bounds.top + bounds.height * 0.32;
    final sx = (bounds.width / 2) * math.sqrt2 / (bounds.shortestSide / 2);
    final sy = math.max(cy - bounds.top, bounds.bottom - cy) *
        math.sqrt2 /
        (bounds.shortestSide / 2);
    return Matrix4.identity()
      ..translateByDouble(cx, cy, 0, 1)
      ..scaleByDouble(sx, sy, 1, 1)
      ..translateByDouble(-cx, -cy, 0, 1);
  }
}

class _Weave extends CustomPainter {
  const _Weave();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0x14000000);
    for (var y = 0.0; y < size.height; y += 8) {
      for (var x = 0.0; x < size.width; x += 8) {
        canvas.drawCircle(Offset(x, y), 1.2, p);
      }
    }
  }

  @override
  bool shouldRepaint(_Weave old) => false;
}

// ----------------------------------------------------------------- button

enum ButtonTone { gold, dark, green, silver }

class _Face {
  final Color hi, lo, fg, shine;
  const _Face(this.hi, this.lo, this.fg, this.shine);
}

const _faces = {
  ButtonTone.gold:
      _Face(Palette.goldHi, Palette.goldLo, Palette.onGold, Color(0x80FFFFFF)),
  ButtonTone.dark:
      _Face(Palette.darkHi, Palette.darkLo, Palette.text, Color(0x2EFFFFFF)),
  ButtonTone.green: _Face(
      Palette.greenHi, Palette.greenLo, Palette.onGreen, Color(0x66FFFFFF)),
  ButtonTone.silver: _Face(
      Palette.silverHi, Palette.silverLo, Palette.onGold, Color(0x80FFFFFF)),
};
const _disabledFace = _Face(Palette.disabledHi, Palette.disabledLo,
    Palette.disabledText, Color(0x00000000));

/// The chunky game button: a gradient face, a black rim, a hard shadow under
/// it. Pressing — or being the selected option — sinks it 3px onto its
/// shadow. A null [onTap] greys it out.
class GameButton extends StatefulWidget {
  final String? label;
  final Widget? child;
  final VoidCallback? onTap;
  final ButtonTone tone;
  final bool selected;
  final double? width;
  final double height;
  final double fontSize;
  final double radius;
  final String? semantics;

  /// Room either side of the label before it starts to shrink.
  final double inset;

  const GameButton({
    super.key,
    this.label,
    this.child,
    required this.onTap,
    this.tone = ButtonTone.gold,
    this.selected = false,
    this.width,
    this.height = 52,
    this.fontSize = 18,
    this.radius = 12,
    this.semantics,
    this.inset = 12,
  }) : assert(label != null || child != null);

  /// The 46px square header button (home, language, scoreboard).
  const GameButton.icon({
    super.key,
    required Widget this.child,
    required this.onTap,
    this.semantics,
    this.tone = ButtonTone.dark,
    this.selected = false,
  })  : label = null,
        inset = 12,
        width = 46,
        height = 46,
        fontSize = 20,
        radius = 12;

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final f = enabled ? _faces[widget.tone]! : _disabledFace;
    final sunk = enabled && (_down || widget.selected);
    final dy = !enabled ? 2.0 : (sunk ? 1.0 : 4.0);
    final r = BorderRadius.circular(widget.radius);

    final content = widget.child != null
        ? IconTheme(
            data: IconThemeData(color: f.fg, size: 22),
            child: DefaultTextStyle(
              style: display(widget.fontSize, color: f.fg, spacing: 0.04),
              child: widget.child!,
            ),
          )
        : Text(
            widget.label!.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: display(widget.fontSize, color: f.fg, spacing: 0.04),
          );

    return Semantics(
      button: true,
      enabled: enabled,
      selected: widget.selected,
      label: widget.semantics,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTap: enabled
            ? () {
                Haptics.tap();
                widget.onTap!();
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 70),
          transform: Matrix4.translationValues(0, sunk ? 3 : 0, 0),
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: vgrad(f.hi, f.lo),
            borderRadius: r,
            border: Border.all(color: Palette.outline, width: 2),
            boxShadow: hardShadow(dy),
          ),
          child: Stack(
            children: [
              // The 1px bevel catching the light along the top edge.
              Positioned(
                top: 0,
                left: widget.radius / 2,
                right: widget.radius / 2,
                height: 1,
                child: ColoredBox(color: f.shine),
              ),
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: widget.inset),
                  child: FittedBox(fit: BoxFit.scaleDown, child: content),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ badge, plaque

enum BadgeTone { call, dash, risk }

/// CALL (gold), DASH (silver) and LAST CALL · RISK (red) tags.
class GameBadge extends StatelessWidget {
  final String label;
  final BadgeTone tone;
  final double size;
  const GameBadge(this.label,
      {super.key, this.tone = BadgeTone.call, this.size = 15});

  @override
  Widget build(BuildContext context) {
    final (hi, lo, fg) = switch (tone) {
      BadgeTone.call => (Palette.goldHi, Palette.goldLo, Palette.onGold),
      BadgeTone.dash => (Palette.silverHi, Palette.silverLo, Palette.onGold),
      BadgeTone.risk => (Palette.riskHi, Palette.riskLo, Palette.text),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        gradient: vgrad(hi, lo),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Palette.outline, width: 2),
        boxShadow: hardShadow(size >= 15 ? 3 : 2),
      ),
      child: Text(label.toUpperCase(),
          style: display(size, color: fg, spacing: 0.06)),
    );
  }
}

enum PlaqueTone { silver, green, orange, red }

/// Header chip: the trump ("HEARTS" with its suit) or where the table's
/// calls sit against 13 ("UNDER 1", "OVER 2", "EXACTLY 13").
class Plaque extends StatelessWidget {
  final String label;
  final PlaqueTone tone;
  final Suit? suit;
  const Plaque(this.label,
      {super.key, this.tone = PlaqueTone.silver, this.suit});

  @override
  Widget build(BuildContext context) {
    final (hi, lo, fg) = switch (tone) {
      PlaqueTone.silver => (
          Palette.silverHi,
          const Color(0xFFD9DDE0),
          Palette.onGold
        ),
      PlaqueTone.green => (Palette.greenHi, Palette.greenLo, Palette.onGreen),
      PlaqueTone.orange => (
          Palette.orangeHi,
          Palette.orangeLo,
          const Color(0xFF2A1207)
        ),
      PlaqueTone.red => (
          const Color(0xFFFF9B87),
          Palette.redLo,
          const Color(0xFF2A0B07)
        ),
    };
    final big = tone == PlaqueTone.silver;
    return Container(
      height: 46,
      padding: EdgeInsetsDirectional.only(
          start: suit != null ? 10 : 14, end: big ? 16 : 14),
      decoration: BoxDecoration(
        gradient: vgrad(hi, lo),
        borderRadius: BorderRadius.circular(big ? 12 : 10),
        border: Border.all(color: Palette.outline, width: 2),
        boxShadow: hardShadow(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (suit != null) ...[
            SuitGlyph(suit!, size: 26),
            const SizedBox(width: 8),
          ],
          Text(label.toUpperCase(),
              style: display(big ? 20 : 18, color: fg, spacing: 0.03)),
        ],
      ),
    );
  }
}

/// A suit printed in its own colour, for light faces.
class SuitGlyph extends StatelessWidget {
  final Suit suit;
  final double size;
  final Color? color;
  const SuitGlyph(this.suit, {super.key, this.size = 24, this.color});

  @override
  Widget build(BuildContext context) => Text(
        suit.symbol,
        style: TextStyle(
          fontSize: size,
          height: 1,
          color: color ?? suitInk(suit),
          fontFamilyFallback: const ['Segoe UI Symbol', 'Noto Sans Symbols'],
        ),
      );
}

// ------------------------------------------------------------- round tile

/// The calendar page: a red ROUND strip over a cream number. A gold ×N coin
/// sits on its corner when the round is worth more than face value.
class RoundTile extends StatelessWidget {
  final int round;
  final int of;
  final int multiplier;
  final String roundLabel;
  final String ofLabel;

  /// Side of the square tile. The pull-down handle is the big one.
  final double size;

  /// Whether to say "of N" beside the tile.
  final bool showOf;

  /// A chevron under the number: true points up, false down, null none.
  final bool? chevronUp;

  /// Keys the square itself, without the "of N" beside it.
  final Key? tileKey;
  const RoundTile({
    super.key,
    this.tileKey,
    required this.round,
    required this.of,
    this.multiplier = 1,
    this.roundLabel = 'ROUND',
    this.ofLabel = 'of',
    this.size = 62,
    this.showOf = true,
    this.chevronUp,
  });

  @override
  Widget build(BuildContext context) {
    final k = size / 62;
    final big = size > 62;
    final tile = Container(
      key: tileKey,
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10 * k),
        border: Border.all(color: Palette.outline, width: big ? 2.5 : 2),
        boxShadow: hardShadow(big ? 5 : 3),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10 * k - 2),
        child: Column(
          children: [
            Container(
              height: 18 * k,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: vgrad(Palette.roundRedHi, Palette.roundRedLo),
                border: const Border(
                    bottom: BorderSide(color: Palette.outline, width: 2)),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(roundLabel.toUpperCase(),
                    style: display(11 * k, spacing: 0.12, height: 1)),
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    gradient: vgrad(Palette.creamHi, Palette.creamLo)),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$round',
                          style: display(chevronUp == null ? 30 * k : 26 * k,
                              color: Palette.onGold, height: 1)),
                      if (chevronUp != null)
                        Icon(
                          chevronUp!
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 15 * k,
                          color: Palette.onGold,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (!showOf) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          tile,
          if (multiplier > 1)
            PositionedDirectional(
              bottom: -8,
              end: -20,
              child: MultCoin(multiplier, size: 28),
            ),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            tile,
            if (multiplier > 1)
              PositionedDirectional(
                top: -14,
                end: -20,
                child: MultCoin(multiplier, size: 28),
              ),
          ],
        ),
        SizedBox(width: multiplier > 1 ? 18 : 12),
        Text('$ofLabel $of', style: display(18, color: Palette.secondary)),
      ],
    );
  }
}

/// The gold ×N coin.
class MultCoin extends StatelessWidget {
  final int n;
  final double size;
  const MultCoin(this.n, {super.key, this.size = 30});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: vgrad(Palette.goldHi, Palette.goldLo),
          border: Border.all(color: Palette.outline, width: 2),
          boxShadow: hardShadow(2),
        ),
        child: Text('×$n',
            style: display(size * 0.45, color: Palette.onGold, height: 1)),
      );
}

// ------------------------------------------------------------ phase track

/// DASH → BID → CALLS → TRICKS. Done phases read lighter than those ahead.
class PhaseTrack extends StatelessWidget {
  final List<String> phases;
  final int current;
  const PhaseTrack({super.key, required this.phases, required this.current});

  @override
  Widget build(BuildContext context) {
    final out = <Widget>[];
    for (var k = 0; k < phases.length; k++) {
      if (k > 0) {
        out.add(Container(
          width: 22,
          height: 3,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0x2EFFFFFF),
            borderRadius: BorderRadius.circular(2),
          ),
        ));
      }
      final on = k == current;
      out.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: on ? vgrad(Palette.goldHi, Palette.goldLo) : null,
          color: on ? null : const Color(0x40000000),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: on ? Palette.outline : const Color(0x59000000),
            width: 2,
          ),
          boxShadow: on ? hardShadow(3) : null,
        ),
        child: Text(
          phases[k].toUpperCase(),
          style: display(15,
              spacing: 0.05,
              color: on
                  ? Palette.onGold
                  : k < current
                      ? const Color(0xFFC5CDE0)
                      : Palette.muted),
        ),
      ));
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(mainAxisSize: MainAxisSize.min, children: out),
    );
  }
}

// ------------------------------------------------------------ avatar tile

/// [idle] is the dimmed frame of a seat that is still undecided.
enum AvatarFrame { plain, caller, made, dash, idle }

enum BubbleTone { plain, leader, last }

/// A seat's face in a framed rounded square. Optional extras: the running
/// total on the top-end corner, and the crown or the kooz hat on its head
/// for whoever is first or last (see [HeadMark]).
class AvatarTile extends StatelessWidget {
  final int avatar;
  final double size;
  final AvatarFrame frame;
  final String? total;
  final BubbleTone bubble;
  final bool crown;
  final bool kooz;
  final VoidCallback? onTap;
  final String? semantics;

  const AvatarTile({
    super.key,
    required this.avatar,
    this.size = 88,
    this.frame = AvatarFrame.plain,
    this.total,
    this.bubble = BubbleTone.plain,
    this.crown = false,
    this.kooz = false,
    this.onTap,
    this.semantics,
  });

  @override
  Widget build(BuildContext context) {
    final frameColor = switch (frame) {
      AvatarFrame.plain => Palette.plainFrame,
      AvatarFrame.caller => Palette.gold,
      AvatarFrame.made => Palette.madeFrame,
      AvatarFrame.dash => Palette.silverLo,
      AvatarFrame.idle => const Color(0x80FFFFFF),
    };
    final radius = (size * 0.16).clamp(12.0, 18.0);

    Widget tile = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: frameColor, width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0xB3000000), spreadRadius: 1.5),
          BoxShadow(
              color: Color(0x73000000),
              offset: Offset(0, 3),
              spreadRadius: 1.5),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 3),
        child: AvatarFace(index: avatar, size: size - 6),
      ),
    );
    if (onTap != null) {
      tile = Semantics(
        button: true,
        label: semantics,
        child: GestureDetector(onTap: onTap, child: tile),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        tile,
        if (total != null)
          PositionedDirectional(
            top: -9,
            end: -16,
            child: Container(
              constraints: const BoxConstraints(minWidth: 28),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              decoration: BoxDecoration(
                color: switch (bubble) {
                  BubbleTone.plain => const Color(0xFFF4F6F5),
                  BubbleTone.leader => Palette.gold,
                  BubbleTone.last => Palette.redText,
                },
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xB3000000), width: 1.5),
                boxShadow: const [
                  BoxShadow(color: Color(0x73000000), offset: Offset(0, 2)),
                ],
              ),
              child: Text(total!,
                  textAlign: TextAlign.center,
                  style: display(15, color: Palette.onGold)),
            ),
          ),
        if (crown || kooz) HeadMark.hat(size: size, crown: crown),
      ],
    );
  }
}

/// The crown on the leader's head, or the kooz hat on the last seat's: either
/// sits centred on a face [size] wide, overlapping its top edge by half its
/// own height and tipped a little. Wrap a face in [HeadMark] or, inside a
/// face's own stack, place [HeadMark.hat].
class HeadMark extends StatelessWidget {
  final Widget child;
  final double size;
  final bool crown;
  final bool kooz;
  const HeadMark({
    super.key,
    required this.child,
    required this.size,
    this.crown = false,
    this.kooz = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!crown && !kooz) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [child, HeadMark.hat(size: size, crown: crown)],
    );
  }

  /// Just the hat, positioned for a stack whose top-left is the face's.
  static Widget hat({required double size, required bool crown}) {
    // crown.png has a margin round the crown itself (217×181 inside 256²);
    // the kooz hat fills its picture. Widths are of what you see.
    final double w, h, top;
    if (crown) {
      w = size * 0.85 * 256 / 217;
      final seen = w * 181 / 256;
      top = -seen * 0.5 - w * 33 / 256;
      h = w;
    } else {
      w = size * 0.95;
      h = w * 91 / 172;
      top = -h * 0.5;
    }
    final asset = crown ? 'assets/crown.png' : 'assets/kooz_hat.png';
    return Positioned(
      top: top,
      left: (size - w) / 2,
      width: w,
      height: h,
      child: IgnorePointer(
        child: Transform.rotate(
          angle: (crown ? -8 : -7) * math.pi / 180,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // The hard drop shadow: the same shape in black, 3px down.
              Positioned.fill(
                top: 3,
                bottom: -3,
                child: Image.asset(asset,
                    color: const Color(0x8C000000),
                    colorBlendMode: BlendMode.srcIn),
              ),
              Positioned.fill(
                child: Image.asset(asset,
                    semanticLabel: crown ? 'leader' : 'last place'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The big silver DASH stamp laid over a seat that dashed.
class DashStamp extends StatelessWidget {
  final String label;
  const DashStamp(this.label, {super.key});

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: -6 * math.pi / 180,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 2),
          decoration: BoxDecoration(
            gradient: vgrad(Palette.silverHi, Palette.silverLo),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: Palette.outline, width: 3),
            boxShadow: hardShadow(5),
          ),
          child: Text(label.toUpperCase(),
              style: display(30, color: Palette.onGold, spacing: 0.04)),
        ),
      );
}

// --------------------------------------------------------------- trick bar

/// Thirteen segments, one per trick. Assigned ones are gold; the whole bar
/// turns red once the table has handed out more than exist. With
/// [overflowTail] going over is legal (calls may), so only the overflow
/// shows, as orange on the last segments.
class TrickBar extends StatelessWidget {
  final int assigned;
  final int total;
  final bool overflowTail;
  const TrickBar({
    super.key,
    required this.assigned,
    this.total = 13,
    this.overflowTail = false,
  });

  @override
  Widget build(BuildContext context) {
    final over = assigned > total && !overflowTail;
    final extra = overflowTail ? assigned - total : 0;
    return Row(
      children: [
        for (var k = 0; k < total; k++) ...[
          if (k > 0) const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: over
                    ? Palette.redLo
                    : extra > 0 && k >= total - extra
                        ? Palette.orangeLo
                        : k < assigned
                            ? Palette.gold
                            : const Color(0x21FFFFFF),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// -------------------------------------------------------------- bottom bar

/// The translucent strip along the foot of a screen: the count and status
/// on the start side, then whatever runs across the middle, then the
/// actions (BACK and the primary).
class BottomBar extends StatelessWidget {
  final Widget lead;
  final Widget? middle;
  final List<Widget> actions;
  final double height;
  const BottomBar({
    super.key,
    required this.lead,
    this.middle,
    this.actions = const [],
    this.height = 76,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 12, 10),
      decoration: BoxDecoration(
        color: Palette.bar,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Palette.barBorder, width: 1.5),
      ),
      child: Row(
        children: [
          if (middle == null) Expanded(child: lead) else lead,
          if (middle != null) ...[
            const SizedBox(width: 18),
            Expanded(child: middle!),
          ],
          for (final a in actions) ...[const SizedBox(width: 16), a],
        ],
      ),
    );
  }
}

/// "9 / 13 tricks · waiting on Omar", the lead of the tricks bar.
class CountLead extends StatelessWidget {
  final int count;
  final String suffix;
  final String message;
  final Color messageColor;
  final double width;
  const CountLead({
    super.key,
    required this.count,
    required this.suffix,
    required this.message,
    this.messageColor = Palette.gold,
    this.width = 300,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text.rich(TextSpan(children: [
            TextSpan(text: '$count', style: display(26)),
            TextSpan(
                text: ' $suffix',
                style: body(15, color: const Color(0xFFB9C7C1))),
          ])),
          const SizedBox(width: 10),
          Flexible(
            child: Text(message,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: body(14, weight: FontWeight.w800, color: messageColor)),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ panel

enum PanelEdge { normal, caller, pending, active }

/// The card a seat sits in. The caller's card wears a gold edge; a card
/// still waiting on input has a dashed one; the card the shared pad is
/// entering for glows gold.
class SeatPanel extends StatelessWidget {
  final Widget child;
  final PanelEdge edge;
  final EdgeInsetsGeometry padding;
  const SeatPanel({
    super.key,
    required this.child,
    this.edge = PanelEdge.normal,
    this.padding = const EdgeInsets.fromLTRB(16, 18, 16, 14),
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(18);
    final inner = Padding(padding: padding, child: child);
    if (edge == PanelEdge.pending) {
      return CustomPaint(
        painter: const DashedEdge(),
        child: DecoratedBox(
          decoration: BoxDecoration(color: Palette.panel, borderRadius: r),
          child: inner,
        ),
      );
    }
    if (edge == PanelEdge.active) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF283766),
          borderRadius: r,
          border: Border.all(color: Palette.gold, width: 3),
          boxShadow: const [
            BoxShadow(color: Color(0x59FFD23F), spreadRadius: 3),
          ],
        ),
        child: inner,
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Palette.panel,
        borderRadius: r,
        border: Border.all(
          color: edge == PanelEdge.caller
              ? const Color(0xD9FFD23F)
              : Palette.panelBorder,
          width: 1.5,
        ),
      ),
      child: inner,
    );
  }
}

/// A dashed outline for something that is not there to be pressed, with an
/// optional red stroke corner to corner when it is struck out.
class DashedEdge extends CustomPainter {
  final double radius;
  final Color color;
  final bool strike;
  const DashedEdge({
    this.radius = 18,
    this.color = const Color(0x4DFFFFFF),
    this.strike = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(0.75), Radius.circular(radius));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final m in (Path()..addRRect(rr)).computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 9) {
        canvas.drawPath(m.extractPath(d, math.min(d + 5, m.length)), paint);
      }
    }
    if (strike) {
      final inset = radius * 0.6;
      canvas.drawLine(
        Offset(inset, size.height - inset),
        Offset(size.width - inset, inset),
        Paint()
          ..color = const Color(0x99FF6B5B)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(DashedEdge old) =>
      old.radius != radius || old.color != color || old.strike != strike;
}

/// A titled section panel, as used for Settings' two columns.
class SectionPanel extends StatelessWidget {
  final Widget child;
  const SectionPanel({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Palette.panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Palette.panelBorder, width: 1.5),
        ),
        child: child,
      );
}

// ----------------------------------------------------------------- switch

/// 72×40 pill: gold when on, dark when off, with a white knob.
class GameSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semantics;
  const GameSwitch(
      {super.key, required this.value, this.onChanged, this.semantics});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: semantics,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 72,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          alignment: value
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          decoration: BoxDecoration(
            gradient: value
                ? vgrad(Palette.goldHi, Palette.goldLo)
                : vgrad(const Color(0xFF2A3350), const Color(0xFF1A2038)),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Palette.outline, width: 2),
            boxShadow: hardShadow(2),
          ),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: vgrad(Colors.white, const Color(0xFFD9DDE0)),
              border: Border.all(color: Palette.outline, width: 2),
              boxShadow: hardShadow(2),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- stepper

/// Dark − / + around a big Lilita number. Either side goes null (greyed)
/// when the engine will not take the next value that way.
class GameStepper extends StatelessWidget {
  final String value;
  final VoidCallback? onDec;
  final VoidCallback? onInc;
  final double numberSize;
  final double buttonSize;
  final double numberWidth;
  const GameStepper({
    super.key,
    required this.value,
    this.onDec,
    this.onInc,
    this.numberSize = 46,
    this.buttonSize = 52,
    this.numberWidth = 72,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GameButton(
          label: '−',
          onTap: onDec,
          tone: ButtonTone.dark,
          width: buttonSize,
          height: buttonSize,
          fontSize: 26,
          semantics: 'minus',
        ),
        SizedBox(
          width: numberWidth,
          child: Text(value,
              textAlign: TextAlign.center,
              style: display(numberSize, shadow: true, height: 1)),
        ),
        GameButton(
          label: '+',
          onTap: onInc,
          tone: ButtonTone.dark,
          width: buttonSize,
          height: buttonSize,
          fontSize: 26,
          semantics: 'plus',
        ),
      ],
    );
  }
}

/// The screen title in Lilita with its hard black underlay.
class ScreenTitle extends StatelessWidget {
  final String text;
  final double size;
  const ScreenTitle(this.text, {super.key, this.size = 40});

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: display(size, spacing: 0.02).copyWith(shadows: const [
          Shadow(offset: Offset(0, 3), color: Palette.outline),
        ]),
      );
}
