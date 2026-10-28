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
class BidView extends StatefulWidget {
  final GameController c;
  const BidView({super.key, required this.c});

  @override
  State<BidView> createState() => _BidViewState();
}

class _BidViewState extends State<BidView> {
  GameController get c => widget.c;

  int? _seat;
  late int _bid;
  Suit? _suit;

  @override
  void initState() {
    super.initState();
    // Opens on whatever the round already holds, so coming back is an edit.
    final held = c.working.caller;
    _seat = held != null && !c.working.dash[held] ? held : null;
    _bid =
        (_seat == null ? null : c.working.bids[_seat!]) ?? c.rules.minCallerBid;
    _suit = c.working.trump;
  }

  /// Every number the engine would take from [_seat] as the Caller.
  List<int> get _allowed {
    final seat = _seat;
    return [
      for (var n = c.rules.minCallerBid; n <= c.rules.tricks; n++)
        if (seat == null || c.canPick(seat, n, asCaller: true)) n,
    ];
  }

  void _pickSeat(int i) {
    setState(() {
      _seat = _seat == i ? null : i;
      final ok = _allowed;
      if (ok.isNotEmpty && !ok.contains(_bid)) _bid = ok.first;
    });
  }

  void _step(int d) {
    final ok = _allowed;
    final i = ok.indexOf(_bid);
    final next = i + d;
    if (i < 0 || next < 0 || next >= ok.length) return;
    setState(() => _bid = ok[next]);
  }

  bool get _ready =>
      _seat != null &&
      _allowed.contains(_bid) &&
      (_suit != null || c.lockedTrump != null);

  void _go() {
    if (!_ready) return;
    c.applyCall(_seat!, c.lockedTrump == null ? _suit : null, _bid);
  }

  @override
  Widget build(BuildContext context) {
    final s = c.s;
    final ok = _allowed;
    final i = ok.indexOf(_bid);
    final summary = _seat == null
        ? s.pickWhoWon
        : s.bidsSummary(c.players[_seat!], _bid, _suit?.label(c.arabic));

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
            SizedBox(width: side, child: _bidPanel(s, ok, i)),
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
              spacing: 0.02,
              color: _seat == null ? Palette.secondary : Palette.gold),
        ),
        actions: [
          // The dash window opens by itself as the round starts; this is the
          // way back into it.
          GameButton(
            label: s.editDash,
            tone: ButtonTone.dark,
            width: 150,
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
            onTap: _ready ? _go : null,
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

  Widget _bidPanel(Str s, List<int> ok, int i) {
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
          _heading(s.winningBid),
          const SizedBox(height: 8),
          Row(
            children: [
              GameButton(
                label: '−',
                tone: ButtonTone.dark,
                width: 62,
                height: 62,
                radius: 14,
                fontSize: 30,
                onTap: i > 0 ? () => _step(-1) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 72,
                  decoration: BoxDecoration(
                    color: Palette.inset,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Palette.outline, width: 2),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x8C000000),
                          offset: Offset(0, 4),
                          blurRadius: 8,
                          spreadRadius: -4),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('$_bid',
                          style: display(56, height: 1).copyWith(shadows: [
                            const Shadow(
                                offset: Offset(0, 3), color: Palette.outline),
                          ])),
                      const SizedBox(width: 10),
                      Text(s.tricksWord.toUpperCase(),
                          style: display(18, color: Palette.muted)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GameButton(
                label: '+',
                tone: ButtonTone.dark,
                width: 62,
                height: 62,
                radius: 14,
                fontSize: 30,
                onTap: i >= 0 && i < ok.length - 1 ? () => _step(1) : null,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _heading(s.trump),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final su in kColorOrder) ...[
                if (su != kColorOrder.first) const SizedBox(width: 10),
                Expanded(
                  child: _SuitPick(
                    suit: su,
                    label: su.label(c.arabic),
                    selected: _suit == su,
                    onTap: () => setState(() => _suit = su),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${s.trumpOrder} '
            '${kColorOrder.map((x) => x.symbol).join('  ')}',
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

/// A trump on a white card; gold and sunk when it is the one picked.
class _SuitPick extends StatelessWidget {
  final Suit suit;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SuitPick({
    required this.suit,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          height: 84,
          transform: Matrix4.translationValues(0, selected ? 3 : 0, 0),
          decoration: BoxDecoration(
            gradient: selected
                ? vgrad(Palette.goldHi, Palette.goldLo)
                : vgrad(Colors.white, const Color(0xFFD9DDE0)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Palette.outline, width: 2),
            boxShadow: [
              BoxShadow(
                  offset: Offset(0, selected ? 1 : 4), color: Palette.outline),
              if (selected)
                const BoxShadow(color: Color(0x66FFD23F), spreadRadius: 4),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SuitGlyph(suit,
                  size: 34,
                  color: selected && suit == Suit.sun ? Palette.onGold : null),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label.toUpperCase(),
                      style: display(12, color: Palette.onGold, spacing: 0.06)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
