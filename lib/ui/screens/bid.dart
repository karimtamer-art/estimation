import 'package:flutter/material.dart';

import '../../controller.dart';
import '../../models.dart';
import '../../strings.dart';
import '../avatars.dart';
import '../components.dart';
import '../frame.dart';
import 'dash.dart';
import '../round.dart';
import '../tokens.dart';

/// Who won the bid, for how many, under which trump. Nothing reaches the
/// round until CONTINUE TO CALLS, which settles all three in one press —
/// the same [GameController.applyCall] the old call panel's Confirm made.
/// Color rounds never open here: their table goes straight to the calls.
class BidView extends StatefulWidget {
  final GameController c;
  const BidView({super.key, required this.c});

  /// Preview only: open with this seat, bid and trump already picked.
  static (int, int?, Suit?)? debugPick;

  @override
  State<BidView> createState() => _BidViewState();
}

class _BidViewState extends State<BidView> {
  GameController get c => widget.c;

  int? _seat;
  int? _bid;
  Suit? _suit;

  @override
  void initState() {
    super.initState();
    // Opens on whatever the round already holds, so coming back is an edit.
    final held = c.working.caller;
    _seat = held != null && !c.working.dash[held] ? held : null;
    _bid = _seat == null ? null : c.working.bids[_seat!];
    _suit = c.working.trump;
    final pick = BidView.debugPick;
    if (pick != null) {
      _seat = pick.$1;
      _bid = pick.$2;
      _suit = pick.$3;
    }
  }

  /// The lowest winning bid: the engine's minimum in a normal round, none in
  /// a Color round.
  int get _min => c.isColorRound ? 1 : c.rules.minCallerBid;

  /// Whether the engine would take [n] from the picked seat as the Caller.
  bool _open(int n) {
    if (n < _min) return false;
    final seat = _seat;
    return seat == null || c.isColorRound || c.canPick(seat, n, asCaller: true);
  }

  void _pickSeat(int i) {
    setState(() {
      _seat = _seat == i ? null : i;
      if (_bid != null && !_open(_bid!)) _bid = null;
    });
  }

  void _go(int bid) =>
      c.applyCall(_seat!, c.lockedTrump == null ? _suit : null, bid);

  @override
  Widget build(BuildContext context) {
    final s = c.s;
    // A bid the round no longer takes (its type changed, or the seat did)
    // is dropped rather than carried on.
    if (_bid != null && !_open(_bid!)) _bid = null;
    final bid = _bid;
    final trump = c.lockedTrump ?? _suit;
    final (String summary, bool done) = _seat == null
        ? (s.pickWhoWon, false)
        : bid == null
            ? (s.pickWinningBid, false)
            : trump == null
                ? (s.pickTrump, false)
                : (
                    s.bidsSummary(
                        c.players[_seat!], bid, trump.label(c.arabic)),
                    true
                  );

    return ScreenFrame(
      c: c,
      scoreSheet: true,
      header: RoundHeader(c: c),
      body: LayoutBuilder(builder: (context, box) {
        final side = (box.maxWidth * 0.42).clamp(380.0, 520.0);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _whoWon(s)),
            const SizedBox(width: 18),
            SizedBox(width: side, child: _bidPanel(s)),
          ],
        );
      }),
      bottom: BottomBar(
        height: 72,
        lead: Text(
          summary.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: display(22,
              spacing: 0.02, color: done ? Palette.gold : Palette.secondary),
        ),
        actions: [
          // Back to the dash window, which opens by itself as the round
          // starts.
          GameButton(
            label: s.back,
            tone: ButtonTone.dark,
            width: 110,
            fontSize: 17,
            onTap: () => DashModal.show(context, c),
          ),
          GameButton(
            label: s.allPassed,
            tone: ButtonTone.dark,
            width: 150,
            fontSize: 17,
            onTap: c.skipRound,
          ),
          GameButton(
            label: s.continueToCalls,
            width: 240,
            fontSize: 19,
            onTap: done ? () => _go(bid!) : null,
          ),
        ],
      ),
    );
  }

  Widget _heading(String t) => Text(t.toUpperCase(),
      style: display(18, color: Palette.secondary, spacing: 0.06));

  Widget _whoWon(Str s) {
    final totals = c.totals;
    Widget tile(int i) => _SeatPick(
          name: c.players[i],
          avatar: c.avatars[i],
          total: totals[i],
          pts: s.pts,
          crown: c.leaderIndex == i,
          clown: c.laggardIndex == i,
          dashed: c.working.dash[i],
          selected: _seat == i,
          callLabel: s.callBadge,
          dashLabel: s.dash,
          onTap: c.working.dash[i] ? null : () => _pickSeat(i),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(s.whoWonBid),
        const SizedBox(height: 10),
        for (var row = 0; row < 2; row++) ...[
          if (row > 0) const SizedBox(height: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tile(row * 2)),
                const SizedBox(width: 12),
                Expanded(child: tile(row * 2 + 1)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _bidPanel(Str s) {
    final color = c.isColorRound;
    Widget numbers(int from, int to) => Row(
          children: [
            for (var n = from; n <= from + 6; n++) ...[
              if (n > from) const SizedBox(width: 8),
              Expanded(
                child: n > to
                    ? const SizedBox.shrink()
                    : KeyedSubtree(key: ValueKey('bid$n'), child: _number(n)),
              ),
            ],
          ],
        );
    final panel = Container(
      width: 520,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Palette.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Palette.panelBorder, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FittedBox(
                      fit: BoxFit.scaleDown, child: _heading(s.winningBid)),
                ),
              ),
              const SizedBox(width: 10),
              GameBadge(
                color
                    ? s.colorAnyNumber
                    : s.normalRoundMin(c.rules.minCallerBid),
                tone: color ? BadgeTone.call : BadgeTone.dash,
                size: 12,
              ),
            ],
          ),
          const SizedBox(height: 10),
          // A keypad: 1 sits on the left in Arabic too.
          Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              children: [
                numbers(1, 7),
                const SizedBox(height: 10),
                numbers(8, c.rules.tricks),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _heading(s.trump),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final su in kColorOrder) ...[
                if (su != kColorOrder.first) const SizedBox(width: 8),
                Expanded(
                  child: _SuitPick(
                    suit: su,
                    label: su.label(c.arabic),
                    selected: (c.lockedTrump ?? _suit) == su,
                    onTap: c.lockedTrump != null && c.lockedTrump != su
                        ? null
                        : () => setState(() => _suit = su),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(
            s.trumpOrder(
              Suit.sun.label(c.arabic),
              kColorOrder.skip(1).map((x) => x.symbol).join(' '),
            ),
            style: body(14, color: Palette.secondary).copyWith(
                fontFamilyFallback: const ['Segoe UI Symbol', 'Cairo']),
          ),
        ],
      ),
    );
    // The panel is drawn at the mockup's size and shrinks on a short phone.
    return Align(
      alignment: AlignmentDirectional.topCenter,
      child: FittedBox(fit: BoxFit.scaleDown, child: panel),
    );
  }

  /// One bid number: chunky and pressable, gold when it is the bid; dashed
  /// and struck out when the round will not take it.
  Widget _number(int n) {
    if (!_open(n)) {
      return Semantics(
        button: true,
        enabled: false,
        label: '$n',
        child: CustomPaint(
          foregroundPainter: const DashedEdge(
              radius: 12, color: Color(0x40FFFFFF), strike: true),
          child: Container(
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0x26000000),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('$n',
                style: display(24, color: const Color(0x66B5BFD6), height: 1)),
          ),
        ),
      );
    }
    final on = _bid == n;
    return GameButton(
      label: '$n',
      tone: on ? ButtonTone.gold : ButtonTone.dark,
      selected: on,
      height: 56,
      fontSize: 24,
      inset: 2,
      onTap: () => setState(() => _bid = n),
    );
  }
}

/// A seat in "who won the bid?": gold when picked, dimmed when it dashed.
class _SeatPick extends StatelessWidget {
  final String name;
  final int avatar;
  final int total;
  final String pts;
  final bool crown;
  final bool clown;
  final bool dashed;
  final bool selected;
  final String callLabel;
  final String dashLabel;
  final VoidCallback? onTap;

  const _SeatPick({
    required this.name,
    required this.avatar,
    required this.total,
    required this.pts,
    required this.crown,
    required this.clown,
    required this.dashed,
    required this.selected,
    required this.callLabel,
    required this.dashLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Palette.onGold : Palette.text;
    final face = Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF4F6F5), width: 3),
        boxShadow: const [BoxShadow(color: Palette.outline, spreadRadius: 1.5)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: AvatarFace(index: avatar, size: 58),
      ),
    );
    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      transform: Matrix4.translationValues(0, selected ? 3 : 0, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: selected
            ? vgrad(Palette.goldHi, Palette.goldLo)
            : vgrad(Palette.darkHi, Palette.darkLo),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.outline, width: 2),
        boxShadow: hardShadow(selected ? 2 : 5),
      ),
      child: Row(
        children: [
          face,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: body(20, weight: FontWeight.w900, color: fg)),
                    ),
                    if (crown || clown) ...[
                      const SizedBox(width: 8),
                      Image.asset(
                        crown ? 'assets/crown.png' : 'assets/clown.png',
                        width: 34,
                        height: 34,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Opacity(
                  opacity: 0.8,
                  child: Text('${signedPoints(total, plus: false)} $pts',
                      style: body(14, color: fg)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    final tag = selected
        ? GameBadge(callLabel, size: 14)
        : dashed
            ? GameBadge(dashLabel, tone: BadgeTone.dash, size: 14)
            : null;
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: dashed ? 0.55 : 1,
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.passthrough,
            children: [
              tile,
              if (tag != null)
                PositionedDirectional(
                  top: -12 + (selected ? 3 : 0),
                  end: 12,
                  child: tag,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A trump on a silver button, in its own ink; gold and sunk when it is the
/// one picked. Sun has no suit, so it shows a sun.
class _SuitPick extends StatelessWidget {
  final Suit suit;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  const _SuitPick({
    required this.suit,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GameButton(
      tone: selected ? ButtonTone.gold : ButtonTone.silver,
      selected: selected,
      height: 84,
      radius: 14,
      inset: 4,
      semantics: label,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          suit == Suit.sun
              ? Icon(Icons.wb_sunny_rounded,
                  size: 34,
                  color: selected ? Palette.onGold : suitInk(Suit.sun))
              : SuitGlyph(suit, size: 34),
          const SizedBox(height: 4),
          Text(label.toUpperCase(),
              style: display(12, color: Palette.onGold, spacing: 0.06)),
        ],
      ),
    );
  }
}
