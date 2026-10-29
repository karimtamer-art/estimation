import 'package:flutter/material.dart';

import '../../controller.dart';
import '../../models.dart';
import '../components.dart';
import '../frame.dart';
import '../round.dart';
import '../tokens.dart';

/// Everyone else's call, entered by one scorekeeper on a shared pad. One
/// seat is active at a time; a number on the pad saves its call through
/// [GameController.setValue] and hands the pad to the next seat in
/// [GameController.callingOrder]. The engine's rules — no call over the bid
/// winner, the risk going to whoever settles last, no table of exactly 13 —
/// are what grey a number out.
class CallsView extends StatefulWidget {
  final GameController c;
  const CallsView({super.key, required this.c});

  @override
  State<CallsView> createState() => _CallsViewState();
}

class _CallsViewState extends State<CallsView> {
  GameController get c => widget.c;

  /// A seat tapped to change its call. Cleared once it has its number.
  int? _picked;

  /// The seat the pad is entering for: the tapped one, or else the first
  /// seat in calling order still without a number.
  int? get _active {
    final order = c.callingOrder;
    final p = _picked;
    if (p != null && order.contains(p)) return p;
    for (final seat in order) {
      if (c.working.bids[seat] == null) return seat;
    }
    return null;
  }

  /// Who wears LAST CALL · RISK: the one seat still to call, or once the
  /// table has settled, the seat the engine hands the risk to.
  int? get _riskSeat {
    final pending = [
      for (var i = 0; i < c.playerCount; i++)
        if (!c.working.dash[i] && c.working.bids[i] == null) i,
    ];
    if (pending.length == 1) return pending.first;
    if (pending.isEmpty) {
      final r = c.derived.riskIndex;
      if (r >= 0 && !c.working.dash[r]) return r;
    }
    return null;
  }

  Future<void> _choose(int v) async {
    final i = _active;
    if (i == null || !c.canPick(i, v)) return;
    Suit? trump;
    // A super call takes a Color round's trump back off it, and the seat
    // making it names the new one in the same breath.
    if (c.isColorRound && c.lockedTrump != null && v >= c.rules.superCallMin) {
      trump = await _pickTrump();
      if (trump == null) return;
    }
    c.setValue(i, v, trump: trump);
    setState(() => _picked = null);
    // The last call made the table all equal: say why the hand stops here.
    if (c.allEqualEstimates) await _explainAllEqual();
  }

  /// The house rule "all equal → double" has stopped the hand. Says why,
  /// what to do with the cards, and what the round is worth now; the table
  /// confirms once it has dealt again.
  Future<void> _explainAllEqual() async {
    final s = c.s;
    final called = c.working.bids.firstWhere((b) => b != null) ?? 0;
    // What the dealt-again hand carries: the round's own multiplier doubled.
    // A same-highest-call bonus on these calls goes with them.
    final doubled = c.pendingMult * c.working.houseMult * 2;
    Widget step(int n, String text) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: vgrad(Palette.goldHi, Palette.goldLo),
                  shape: BoxShape.circle,
                  border: Border.all(color: Palette.outline, width: 2),
                ),
                child: Text('$n',
                    style: display(13, color: Palette.onGold, height: 1)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: body(16))),
            ],
          ),
        );
    final go = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0xA8040816),
      builder: (ctx) => Directionality(
        textDirection: c.arabic ? TextDirection.rtl : TextDirection.ltr,
        child: Center(
          child: Material(
            type: MaterialType.transparency,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  decoration: BoxDecoration(
                    gradient:
                        vgrad(const Color(0xFF2A3657), const Color(0xFF18203A)),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Palette.outline, width: 3),
                    boxShadow: hardShadow(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child:
                                ScreenTitle(s.allEqualTitle(called), size: 26),
                          ),
                          MultCoin(doubled, size: 40),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(s.allEqualWhy,
                          style: body(16, color: Palette.secondary)),
                      step(1, s.allEqualDeal),
                      step(2, s.allEqualCallAgain),
                      const SizedBox(height: 12),
                      Text(s.allEqualWorth(doubled),
                          style: body(15,
                              weight: FontWeight.w800, color: Palette.gold)),
                      const SizedBox(height: 6),
                      Text(s.allEqualOff,
                          style: body(14, color: Palette.muted)),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          GameButton(
                            label: s.back,
                            tone: ButtonTone.dark,
                            width: 110,
                            onTap: () => Navigator.of(ctx).pop(false),
                          ),
                          const SizedBox(width: 12),
                          GameButton(
                            label: s.dealtAgain,
                            width: 230,
                            fontSize: 17,
                            onTap: () => Navigator.of(ctx).pop(true),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (go == true) c.doubleAndRebid();
  }

  Future<Suit?> _pickTrump() {
    final s = c.s;
    return showDialog<Suit>(
      context: context,
      barrierColor: const Color(0xA8040816),
      builder: (ctx) => Directionality(
        textDirection: c.arabic ? TextDirection.rtl : TextDirection.ltr,
        child: Center(
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient:
                    vgrad(const Color(0xFF2A3657), const Color(0xFF18203A)),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Palette.outline, width: 3),
                boxShadow: hardShadow(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScreenTitle(s.superCallTrump, size: 28),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final su in kColorOrder) ...[
                        if (su != kColorOrder.first) const SizedBox(width: 10),
                        GameButton(
                          tone: ButtonTone.silver,
                          width: 84,
                          height: 84,
                          radius: 14,
                          onTap: () => Navigator.of(ctx).pop(su),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SuitGlyph(su, size: 34),
                              const SizedBox(height: 4),
                              Text(su.label(c.arabic).toUpperCase(),
                                  style: display(12,
                                      color: Palette.onGold, spacing: 0.06)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = c.s;
    final d = c.derived;
    final complete = c.bidsComplete;
    final err = c.validationError;
    final allEqual = c.allEqualEstimates;
    final risk = _riskSeat;
    final active = _active;
    final order = c.callingOrder;

    final waiting = [
      for (final i in order)
        if (c.working.bids[i] == null) c.players[i],
    ];

    final (String msg, Color msgColor) = waiting.isNotEmpty
        ? (s.waitingOn(waiting), Palette.gold)
        : err != null
            ? (err, Palette.redText)
            : (s.tapPlayerToEdit, Palette.greenText);

    return ScreenFrame(
      c: c,
      scoreSheet: true,
      header: RoundHeader(
        c: c,
        center: TableBanner(c: c),
      ),
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                for (var i = 0; i < c.playerCount; i++) ...[
                  if (i > 0) const SizedBox(width: Gap.cards),
                  Expanded(
                    child: _seat(i,
                        risk: risk == i,
                        active: active == i,
                        turn: order.indexOf(i)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _pad(active),
        ],
      ),
      bottom: BottomBar(
        lead: SizedBox(
          width: 330,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text.rich(TextSpan(children: [
                TextSpan(text: '${d.total}', style: display(26)),
                TextSpan(
                    text: ' ${s.calledOf}',
                    style: body(15, color: Palette.secondary)),
              ])),
              const SizedBox(width: 10),
              Flexible(
                child: Text(msg,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: body(14, weight: FontWeight.w800, color: msgColor)),
              ),
            ],
          ),
        ),
        middle: TrickBar(assigned: d.total, overflowTail: true),
        actions: [
          // A Color round has no bid screen to go back to; passing is the
          // way out of it instead.
          c.isColorRound
              ? GameButton(
                  label: s.allPassed,
                  tone: ButtonTone.dark,
                  width: 150,
                  fontSize: 17,
                  onTap: c.skipRound,
                )
              : GameButton(
                  label: s.back,
                  tone: ButtonTone.dark,
                  width: 110,
                  onTap: c.clearCaller,
                ),
          allEqual
              ? GameButton(
                  label: s.rebid,
                  width: 260,
                  fontSize: 17,
                  onTap: _explainAllEqual,
                )
              : GameButton(
                  label: s.playHand,
                  width: 220,
                  fontSize: 19,
                  onTap: complete && err == null ? c.toTricks : null,
                ),
        ],
      ),
    );
  }

  /// 0 to 13 in one row. Numbers the engine refuses the active seat are
  /// dashed and struck through; the seat's current call is lit.
  Widget _pad(int? seat) {
    return SizedBox(
      height: 50,
      child: Row(
        children: [
          for (var v = 0; v <= c.rules.tricks; v++) ...[
            if (v > 0) const SizedBox(width: 6),
            Expanded(
                child:
                    KeyedSubtree(key: ValueKey('pad$v'), child: _key(v, seat))),
          ],
        ],
      ),
    );
  }

  Widget _key(int v, int? seat) {
    final blocked = seat != null && !c.canPick(seat, v);
    if (blocked) {
      return Semantics(
        button: true,
        enabled: false,
        label: '$v',
        child: CustomPaint(
          foregroundPainter:
              const _Dashes(radius: 12, color: Color(0x40FFFFFF)),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0x26000000),
              borderRadius: BorderRadius.circular(12),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$v',
                style: display(22, color: const Color(0x66B5BFD6)).copyWith(
                  decoration: TextDecoration.lineThrough,
                  decorationColor: Palette.redText,
                  decorationThickness: 2.5,
                ),
              ),
            ),
          ),
        ),
      );
    }
    final current = seat != null && c.working.bids[seat] == v;
    return GameButton(
      label: '$v',
      tone: current ? ButtonTone.gold : ButtonTone.dark,
      selected: current,
      height: 50,
      fontSize: 22,
      inset: 2,
      onTap: seat == null ? null : () => _choose(v),
    );
  }

  /// [turn] is the seat's place in the calling order, or -1 when it calls
  /// no number here (the bid winner, a dash).
  Widget _seat(int i,
      {required bool risk, required bool active, required int turn}) {
    final s = c.s;
    final dashed = c.working.dash[i];
    final isCaller = c.working.caller == i && !dashed;
    // The bid winner's number came with the bid and is not entered here.
    final fromBid = isCaller && !c.isColorRound;
    final held = c.working.bids[i];
    final set = held != null || dashed;

    final String callLabel = dashed ? '0' : (held == null ? '?' : '$held');
    final Color callColor = active
        ? Palette.gold
        : set
            ? Palette.text
            : Palette.muted;
    final (String note, Color noteColor) = active
        ? (s.calling, Palette.gold)
        : dashed
            ? (s.zeroTricks, Palette.secondary)
            : fromBid
                ? (s.bidWinner, Palette.secondary)
                : set
                    ? (s.calledNote, Palette.secondary)
                    : (s.waitingTurn, Palette.muted);

    final Border? border = active
        ? Border.all(color: Palette.gold, width: 3)
        : isCaller
            ? Border.all(color: const Color(0xD9FFD23F), width: 1.5)
            : risk
                ? Border.all(color: Palette.riskLo, width: 2)
                : set
                    ? Border.all(color: Palette.panelBorder, width: 1.5)
                    : null;

    final card = Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF283766) : Palette.panel,
        borderRadius: BorderRadius.circular(18),
        border: border,
        boxShadow: active
            ? const [BoxShadow(color: Color(0x59FFD23F), spreadRadius: 3)]
            : null,
      ),
      child: LayoutBuilder(builder: (context, box) {
        // Name and note are fixed; the face and the big number share what
        // is left, so a short phone shrinks them rather than cutting off.
        const fixed = 10 + 26 + 24;
        final face = (box.maxHeight - fixed - 60).clamp(32.0, 72.0);
        final numH = (box.maxHeight - fixed - face).clamp(28.0, 74.0);
        return Column(
          children: [
            AvatarTile(
              avatar: c.avatars[i],
              size: face,
              crown: c.crowned.contains(i),
              kooz: c.koozed.contains(i),
              frame: isCaller ? AvatarFrame.caller : AvatarFrame.plain,
            ),
            const SizedBox(height: 10),
            // Fixed-height lines: Arabic sets taller than Latin, and the
            // card's sums above count on these heights.
            SizedBox(
              height: 26,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(c.players[i],
                    maxLines: 1, style: body(18, weight: FontWeight.w900)),
              ),
            ),
            SizedBox(
              height: numH,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(callLabel,
                        style: display(numH * 0.92, color: callColor, height: 1)
                            .copyWith(shadows: const [
                          Shadow(
                              offset: Offset(0, 3), color: Color(0x80000000)),
                        ])),
                    if (isCaller) ...[
                      const SizedBox(width: 10),
                      GameBadge(s.callBadge),
                    ],
                    if (dashed) ...[
                      const SizedBox(width: 10),
                      GameBadge(s.dash, tone: BadgeTone.dash),
                    ],
                  ],
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 24,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(note.toUpperCase(),
                    style: display(17, color: noteColor, spacing: 0.02)
                        .copyWith(shadows: const [
                      Shadow(offset: Offset(0, 2), color: Color(0x80000000)),
                    ])),
              ),
            ),
          ],
        );
      }),
    );

    // The corner badge: BID for the bid winner's fixed number, otherwise
    // the seat's turn in the calling order.
    final corner = fromBid
        ? GameBadge(s.bidBadge, tone: BadgeTone.dash, size: 12)
        : turn >= 0
            ? GameBadge(s.turnBadge(turn + 1),
                tone: active ? BadgeTone.call : BadgeTone.dash, size: 12)
            : null;

    final editable = turn >= 0;
    return Semantics(
      button: editable,
      selected: active,
      label: '${c.players[i]}, $callLabel',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: editable ? () => setState(() => _picked = i) : null,
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.passthrough,
          children: [
            border == null
                ? CustomPaint(foregroundPainter: const _Dashes(), child: card)
                : card,
            if (corner != null)
              PositionedDirectional(top: 8, start: 8, child: corner),
            if (risk)
              Positioned(
                top: -13,
                left: 0,
                right: 0,
                child: Center(
                  child:
                      GameBadge(s.lastCallRisk, tone: BadgeTone.risk, size: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Dashes extends CustomPainter {
  final double radius;
  final Color color;
  const _Dashes({this.radius = 18, this.color = const Color(0x4DFFFFFF)});

  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(1), Radius.circular(radius));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final m in (Path()..addRRect(rr)).computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 9) {
        final e = d + 5 < m.length ? d + 5 : m.length;
        canvas.drawPath(m.extractPath(d, e), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_Dashes old) => old.color != color;
}
