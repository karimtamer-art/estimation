import 'package:flutter/material.dart';

import '../../controller.dart';
import '../components.dart';
import '../frame.dart';
import '../round.dart';
import '../tokens.dart';

/// How many each seat took, entered by one scorekeeper on a shared pad in
/// [GameController.trickOrder]. The pad offers only what the engine accepts
/// ([GameController.canPick]), so the table never hands out more than 13.
/// When one seat is left it is filled with what remains, marked AUTO. No
/// points here: they land on the scoresheet once the round is scored.
class TricksView extends StatefulWidget {
  final GameController c;
  const TricksView({super.key, required this.c});

  @override
  State<TricksView> createState() => _TricksViewState();
}

class _TricksViewState extends State<TricksView> {
  GameController get c => widget.c;

  /// A seat tapped to correct its count.
  int? _picked;

  /// The seat filled with the leftover tricks, not by hand.
  int? _auto;

  /// The seat the pad is entering for: the tapped one, or else the first
  /// seat in trick order still without a count.
  int? get _active {
    final p = _picked;
    if (p != null) return p;
    for (final seat in c.trickOrder) {
      if (c.working.tricks[seat] == null) return seat;
    }
    return null;
  }

  /// An automatic count only stands while every other count does: touching
  /// any other seat takes it back off.
  void _dropAuto({required int except}) {
    final a = _auto;
    if (a == null || a == except) return;
    c.clearTrick(a);
    _auto = null;
  }

  void _choose(int v) {
    final seat = _active;
    if (seat == null || !c.canPick(seat, v)) return;
    _dropAuto(except: seat);
    if (seat == _auto) _auto = null;
    c.setValue(seat, v);
    _picked = null;
    // One seat left: it took whatever the others did not.
    final open = [
      for (var i = 0; i < c.playerCount; i++)
        if (c.working.tricks[i] == null) i,
    ];
    if (open.length == 1) {
      final rest = c.rules.tricks - c.trickSum;
      if (rest >= 0) {
        c.setValue(open.single, rest);
        _auto = open.single;
      }
    }
    setState(() {});
  }

  void _tap(int seat) {
    _dropAuto(except: seat);
    setState(() => _picked = seat);
  }

  @override
  Widget build(BuildContext context) {
    final s = c.s;
    final assigned = c.trickSum;
    final active = _active;
    final waiting = [
      for (final i in c.trickOrder)
        if (c.working.tricks[i] == null) c.players[i],
    ];
    final over = assigned - c.rules.tricks;
    final (String msg, Color msgColor) = waiting.isNotEmpty
        ? (s.waitingOn(waiting), Palette.gold)
        : over < 0
            ? (s.unassigned(-over), Palette.gold)
            : over > 0
                ? (s.tooMany(over), Palette.redText)
                : (s.readyBang, Palette.greenText);
    final ok = c.tricksComplete && c.validationError == null;

    return ScreenFrame(
      c: c,
      scoreSheet: true,
      header: RoundHeader(c: c, center: TableBanner(c: c)),
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                for (var i = 0; i < c.playerCount; i++) ...[
                  if (i > 0) const SizedBox(width: Gap.cards),
                  Expanded(child: _seat(i, active == i)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _pad(active),
        ],
      ),
      bottom: BottomBar(
        lead: CountLead(
          count: assigned,
          suffix: s.tricksOf,
          message: msg,
          messageColor: msgColor,
        ),
        middle: TrickBar(assigned: assigned, total: c.rules.tricks),
        actions: [
          GameButton(
            label: s.back,
            tone: ButtonTone.dark,
            width: 110,
            onTap: c.backToBids,
          ),
          GameButton(
            label: s.scoreRound,
            width: 210,
            fontSize: 19,
            onTap: ok ? c.commit : null,
          ),
        ],
      ),
    );
  }

  /// 0 to 13 in one row. The active seat's call is the gold EXACT key;
  /// counts that would take the table past 13 are struck out.
  Widget _pad(int? seat) {
    return SizedBox(
      height: 50,
      child: Row(
        children: [
          for (var v = 0; v <= c.rules.tricks; v++) ...[
            if (v > 0) const SizedBox(width: 6),
            Expanded(
              child: KeyedSubtree(
                key: ValueKey('pad$v'),
                child: _key(v, seat),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _key(int v, int? seat) {
    if (seat != null && !c.canPick(seat, v)) return _BlockedKey(v);
    final called = seat == null
        ? null
        : c.working.dash[seat]
            ? 0
            : c.working.bids[seat];
    final exact = called == v;
    final current = seat != null && c.working.tricks[seat] == v;
    return GameButton(
      tone: exact ? ButtonTone.gold : ButtonTone.dark,
      selected: current,
      height: 50,
      inset: 2,
      semantics: exact ? '$v, ${c.s.exact}' : '$v',
      onTap: seat == null ? null : () => _choose(v),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$v',
                style: display(exact ? 19 : 22,
                    color: exact ? Palette.onGold : Palette.text, height: 1)),
            if (exact)
              Text(c.s.exact.toUpperCase(),
                  style: display(9,
                      color: Palette.onGold, spacing: 0.06, height: 1.1)),
          ],
        ),
      ),
    );
  }

  Widget _seat(int i, bool active) {
    final s = c.s;
    final dashed = c.working.dash[i];
    final called = dashed ? 0 : (c.working.bids[i] ?? 0);
    final took = c.working.tricks[i];
    final made = took != null && took == called;
    final isCaller = c.working.caller == i && !dashed;

    final (String status, Color statusColor) = took == null
        ? active
            ? (s.enterTricksHere, Palette.gold)
            : (s.waitingDots, Palette.muted)
        : made
            ? (s.exactMark, Palette.greenText)
            : took < called
                ? (s.shortBy(called - took), Palette.redText)
                : (s.overBy2(took - called), Palette.redText);

    final edge = active
        ? PanelEdge.active
        : isCaller
            ? PanelEdge.caller
            : took == null
                ? PanelEdge.pending
                : PanelEdge.normal;

    final panel = SeatPanel(
      edge: edge,
      child: LayoutBuilder(builder: (context, box) {
        // Name and status are fixed; the face and the count share what is
        // left.
        const fixed = 12 + 26 + 8 + 26;
        final face = (box.maxHeight - fixed - 50).clamp(36.0, 80.0);
        final numH = (box.maxHeight - fixed - face).clamp(30.0, 56.0);
        return Column(
          children: [
            AvatarTile(
              avatar: c.avatars[i],
              size: face,
              frame: isCaller
                  ? AvatarFrame.caller
                  : made
                      ? AvatarFrame.made
                      : AvatarFrame.plain,
            ),
            const SizedBox(height: 12),
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
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: took == null ? '–' : '$took',
                          style: TextStyle(
                              color: active ? Palette.gold : Palette.text),
                        ),
                        TextSpan(
                          text: '/$called',
                          style: const TextStyle(color: Color(0xFFB9C7C1)),
                        ),
                      ]),
                      style: display(46, height: 1, shadow: true),
                      // Took over called reads left to right in Arabic too.
                      textDirection: TextDirection.ltr,
                    ),
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
              height: 26,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(status.toUpperCase(),
                    style: display(20, color: statusColor, spacing: 0.02)
                        .copyWith(shadows: const [
                      Shadow(offset: Offset(0, 2), color: Color(0x80000000)),
                    ])),
              ),
            ),
          ],
        );
      }),
    );

    return Semantics(
      button: true,
      selected: active,
      label: '${c.players[i]}, ${took ?? '–'} / $called',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _tap(i),
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.passthrough,
          children: [
            panel,
            if (_auto == i && took != null)
              PositionedDirectional(
                top: 8,
                start: 8,
                child: GameBadge(s.autoBadge, tone: BadgeTone.dash, size: 12),
              ),
          ],
        ),
      ),
    );
  }
}

/// A pad number the engine will not take: dashed and struck through.
class _BlockedKey extends StatelessWidget {
  final int v;
  const _BlockedKey(this.v);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: false,
      label: '$v',
      child: CustomPaint(
        foregroundPainter: const _Dashes(),
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
}

class _Dashes extends CustomPainter {
  const _Dashes();

  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(1), const Radius.circular(12));
    final paint = Paint()
      ..color = const Color(0x40FFFFFF)
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
  bool shouldRepaint(_Dashes old) => false;
}
