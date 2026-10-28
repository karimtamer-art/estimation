import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controller.dart';
import '../models.dart';
import 'components.dart';
import 'round.dart';
import 'tokens.dart';

/// The scoresheet folded away above a round, pulled down by the round tile
/// in the header (see [ScoreHandle]).
///
/// One value, [AnimationController.value], runs from 0 (shut) to 1 (open):
/// the sheet slides with it, the backdrop darkens with it, and the round
/// behind fades to half. A finger on the tile drives it directly; letting go
/// snaps it one way or the other. While the sheet is out, the tile leaves its
/// header slot and rides the sheet's foot; shut, it is back in its slot.
class ScoreboardOverlay extends StatefulWidget {
  final GameController c;
  final Widget child;
  const ScoreboardOverlay({super.key, required this.c, required this.child});

  /// For the dev preview only: start with the sheet down.
  static bool debugStartOpen = false;

  @override
  State<ScoreboardOverlay> createState() => _ScoreboardOverlayState();
}

class _ScoreboardOverlayState extends State<ScoreboardOverlay>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 280);
  static const _fling = 700.0;

  late final AnimationController _t =
      AnimationController(vsync: this, duration: _duration);

  /// The header tile, so the riding copy can start and end where it sits.
  final _tileKey = GlobalKey();
  final _stackKey = GlobalKey();

  /// Where the sheet is headed, or rests: what a tap toggles from.
  bool _open = false;

  /// Whether the drag in progress began from an open sheet.
  bool _fromOpen = false;

  /// How far a full pull travels, for turning finger pixels into [_t].
  double _travel = 1;

  GameController get c => widget.c;

  @override
  void initState() {
    super.initState();
    if (ScoreboardOverlay.debugStartOpen) {
      _open = true;
      _t.value = 1;
    }
    // The tip and the riding tile need the header tile laid out once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  void _snap(bool open) {
    if (open != _open) {
      Haptics.snap();
      if (open) c.markScoreHintSeen();
      setState(() => _open = open);
    }
    final left = open ? 1 - _t.value : _t.value;
    _t.animateTo(
      open ? 1 : 0,
      duration: _duration * left.clamp(0.3, 1.0),
      curve: open ? Curves.easeOutCubic : Curves.easeInCubic,
    );
  }

  void _dragStart(DragStartDetails _) {
    _t.stop();
    _fromOpen = _open;
  }

  void _dragUpdate(DragUpdateDetails d) {
    _t.value = (_t.value + d.primaryDelta! / _travel).clamp(0.0, 1.0);
  }

  void _dragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0; // positive is downward
    _snap(_fromOpen
        ? !(v < -_fling || (_t.value < 0.65 && v < _fling))
        : v > _fling || (_t.value > 0.35 && v > -_fling));
  }

  /// The header tile's box in the overlay's own coordinates.
  Rect? _slot() {
    final tile = _tileKey.currentContext?.findRenderObject() as RenderBox?;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (tile == null || stack == null || !tile.attached || !tile.hasSize) {
      return null;
    }
    return tile.localToGlobal(Offset.zero, ancestor: stack) & tile.size;
  }

  /// The tile with the sheet's gestures on it, wherever it is drawn.
  Widget _handle(Widget tile) => Semantics(
        button: true,
        expanded: _open,
        label: _open ? c.s.pushUpSheet : c.s.pullDownSheet,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _snap(!_open),
          onVerticalDragStart: _dragStart,
          onVerticalDragUpdate: _dragUpdate,
          onVerticalDragEnd: _dragEnd,
          child: ExcludeSemantics(child: tile),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return PopScope(
      canPop: !_open,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _snap(false);
      },
      child: _SheetScope(
        state: this,
        child: LayoutBuilder(builder: (context, box) {
          final sheetH = box.maxHeight * 0.83;
          _travel = sheetH;
          return AnimatedBuilder(
            animation: _t,
            child: widget.child,
            builder: (context, game) {
              final t = _t.value;
              // Reduced motion: the sheet stays put and only fades.
              final slide = still ? 0.0 : -sheetH * (1 - t);
              final slot = _slot();
              // Open, the tile hangs from the middle of the sheet's foot.
              const hung = 82.0;
              final foot = Rect.fromLTWH(
                  (box.maxWidth - hung) / 2, sheetH - 34, hung, hung);
              final ride = slot == null
                  ? null
                  : still
                      ? (t < 0.5 ? slot : foot)
                      : Rect.lerp(slot, foot, t)!;
              return Stack(
                key: _stackKey,
                children: [
                  Positioned.fill(
                    child: Opacity(opacity: 1 - 0.5 * t, child: game),
                  ),
                  if (t > 0) ...[
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () => _snap(false),
                        child: ColoredBox(
                          color: const Color(0xFF040816)
                              .withValues(alpha: 0.55 * t),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 40,
                      right: 40,
                      // The top edge and its corners sit above the screen,
                      // so only the sides and the rounded foot show.
                      top: slide - 30,
                      height: sheetH + 30,
                      child: Opacity(
                        opacity: still ? t : 1,
                        child: _Sheet(
                          c: c,
                          onDragStart: _dragStart,
                          onDragUpdate: _dragUpdate,
                          onDragEnd: _dragEnd,
                        ),
                      ),
                    ),
                    if (ride != null)
                      Positioned.fromRect(
                        rect: ride,
                        child: _handle(RoundTile(
                          round: roundNumber(c),
                          of: c.mode.totalRounds,
                          multiplier: c.currentMult,
                          roundLabel: c.s.round,
                          size: ride.width,
                          showOf: false,
                          chevronUp: _open,
                        )),
                      ),
                  ],
                  // First game only: point at the tile until it is used.
                  if (!c.seenScoreHint && t == 0 && slot != null)
                    PositionedDirectional(
                      start: rtl ? box.maxWidth - slot.right : slot.left,
                      top: slot.bottom + 10,
                      child: _CoachMark(
                        text: c.s.pullForScores,
                        arrowAt: slot.width / 2,
                        onTap: c.markScoreHintSeen,
                      ),
                    ),
                ],
              );
            },
          );
        }),
      ),
    );
  }
}

class _SheetScope extends InheritedWidget {
  final _ScoreboardOverlayState state;
  const _SheetScope({required this.state, required super.child});

  @override
  bool updateShouldNotify(_SheetScope old) => old.state != state;
}

/// The round tile in the header, made the sheet's handle: tap it or drag it
/// down. While the sheet is out it leaves its slot to ride the sheet, so it
/// is hidden here. Outside a [ScoreboardOverlay] it is just the tile.
class ScoreHandle extends StatelessWidget {
  final GameController c;
  const ScoreHandle({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_SheetScope>();
    Widget tile({Key? tileKey}) => RoundTile(
          tileKey: tileKey,
          round: roundNumber(c),
          of: c.mode.totalRounds,
          multiplier: c.currentMult,
          roundLabel: c.s.round,
          ofLabel: c.s.of,
          chevronUp: scope == null ? null : false,
        );
    if (scope == null) return tile();
    final st = scope.state;
    return AnimatedBuilder(
      animation: st._t,
      child: st._handle(tile(tileKey: st._tileKey)),
      builder: (context, handle) => Opacity(
        opacity: st._t.value > 0 ? 0 : 1,
        child: handle,
      ),
    );
  }
}

/// A one-time tip under the tile, its arrow pointing up at it.
class _CoachMark extends StatelessWidget {
  final String text;
  final double arrowAt;
  final VoidCallback onTap;
  const _CoachMark({
    required this.text,
    required this.arrowAt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const fill = Color(0xFFFFF4D6);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsetsDirectional.only(start: arrowAt - 9),
            child: CustomPaint(
              size: const Size(18, 9),
              painter: _Arrow(fill),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Palette.outline, width: 2),
              boxShadow: hardShadow(3),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.swipe_down_rounded,
                    size: 20, color: Palette.onGold),
                const SizedBox(width: 8),
                Text(text,
                    style: body(14,
                        weight: FontWeight.w800, color: Palette.onGold)),
                const SizedBox(width: 8),
                const Icon(Icons.close_rounded,
                    size: 18, color: Color(0x991A1A17)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Arrow extends CustomPainter {
  final Color fill;
  _Arrow(this.fill);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height + 2)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height + 2);
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = Palette.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_Arrow old) => old.fill != fill;
}

/// The sheet's face. Its content arrives in later steps; for now it holds
/// the empty state. A drag anywhere on it moves it like the tile does.
class _Sheet extends StatelessWidget {
  final GameController c;
  final GestureDragStartCallback onDragStart;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  const _Sheet({
    required this.c,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: onDragStart,
      onVerticalDragUpdate: onDragUpdate,
      onVerticalDragEnd: onDragEnd,
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 30 + 18, 22, 16),
        decoration: BoxDecoration(
          gradient: vgrad(const Color(0xFF22305A), const Color(0xFF151D38)),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Palette.outline, width: 3),
          boxShadow: const [
            BoxShadow(offset: Offset(0, 8), color: Palette.outline),
            BoxShadow(
              offset: Offset(0, 18),
              blurRadius: 40,
              color: Color(0x80000000),
            ),
          ],
        ),
        child: Column(
          children: [
            _SheetHeader(c: c),
            const SizedBox(height: 10),
            Container(height: 2, color: const Color(0x1AFFFFFF)),
            const SizedBox(height: 12),
            _Chart(c: c),
            Expanded(
              child: c.playedCount == 0
                  ? Center(
                      child: Text(
                        c.s.scoresAfterFirst,
                        style: body(15, color: Palette.muted),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

/// The sheet's grid: a round column, a column per seat, and the ±13 column.
/// Rows below line up on the same widths.
const _roundCol = 56.0;
const _diffCol = 60.0;

/// R · each seat's name and running total · ±13.
class _SheetHeader extends StatelessWidget {
  final GameController c;
  const _SheetHeader({required this.c});

  @override
  Widget build(BuildContext context) {
    final totals = c.totals;
    final edge = display(15, color: Palette.muted);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: _roundCol,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child:
                Text(c.s.roundShort, textAlign: TextAlign.center, style: edge),
          ),
        ),
        for (var i = 0; i < c.playerCount; i++)
          Expanded(child: _seat(i, totals[i])),
        SizedBox(
          width: _diffCol,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('±13', textAlign: TextAlign.center, style: edge),
          ),
        ),
      ],
    );
  }

  Widget _seat(int i, int total) {
    // Crown and clown go to an outright first and last only, as everywhere
    // else in the game: a shared place wears nothing.
    final top = i == c.leaderIndex;
    final low = i == c.laggardIndex;
    final ink = top
        ? Palette.gold
        : total > 0
            ? Palette.greenText
            : total < 0
                ? Palette.redText
                : Palette.text;
    final figure = Text(
      c.playedCount == 0 ? '0' : signedPoints(total),
      maxLines: 1,
      style: display(30, color: ink, height: 1.1),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 30,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: kSeatInk[i % kSeatInk.length],
                    shape: BoxShape.circle,
                    border: Border.all(color: Palette.outline, width: 1.5),
                  ),
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    c.players[i].toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: display(17, spacing: 0.1),
                  ),
                ),
                if (top || low) ...[
                  const SizedBox(width: 6),
                  Image.asset(
                    top ? 'assets/crown.png' : 'assets/clown.png',
                    width: 28,
                    height: 28,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: top
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0x24FFD23F),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: const Color(0xFFC99A1E), width: 2),
                    ),
                    child: figure,
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: figure,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Each seat's total before the first round and after every round since,
/// passed rounds included (they add nothing, so the line runs flat).
List<List<int>> runningTotals(GameController c) => [
      for (var i = 0; i < c.playerCount; i++)
        [
          0,
          ...() {
            var sum = 0;
            return [
              for (final r in c.rounds)
                sum += i < r.scores.length ? r.scores[i] : 0,
            ];
          }(),
        ],
    ];

/// The running totals as a line per seat, drawn in as the sheet opens on a
/// round it has not shown yet.
class _Chart extends StatefulWidget {
  final GameController c;
  const _Chart({required this.c});

  @override
  State<_Chart> createState() => _ChartState();
}

class _ChartState extends State<_Chart> with SingleTickerProviderStateMixin {
  /// How many rounds the lines were last drawn in for. The sheet leaves the
  /// tree when it shuts, so this outlives any one state.
  static int _drawnFor = -1;

  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  int get _rounds => widget.c.rounds.length;

  @override
  void initState() {
    super.initState();
    _drawIn();
  }

  @override
  void didUpdateWidget(_Chart old) {
    super.didUpdateWidget(old);
    _drawIn();
  }

  void _drawIn() {
    if (_rounds == _drawnFor) {
      if (!_draw.isAnimating) _draw.value = 1;
      return;
    }
    _drawnFor = _rounds;
    _draw.forward(from: 0);
  }

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 132,
      decoration: BoxDecoration(
        color: const Color(0x40000000),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14FFFFFF), width: 1.5),
      ),
      child: AnimatedBuilder(
        animation: _draw,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _ChartPainter(
            series: runningTotals(widget.c),
            progress: Curves.easeOut.transform(_draw.value),
            rtl: Directionality.of(context) == TextDirection.rtl,
            label: body(11, color: Palette.muted),
          ),
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<List<int>> series;
  final double progress;
  final bool rtl;
  final TextStyle label;
  _ChartPainter({
    required this.series,
    required this.progress,
    required this.rtl,
    required this.label,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final all = series.expand((s) => s);
    final lo = math.min(0, all.reduce(math.min));
    final hi = math.max(10, all.reduce(math.max));
    final points = series.first.length; // rounds + the start at 0
    // Room on the labels' side for "+hi"; the far side keeps the end dots in.
    const near = 38.0, far = 14.0, top = 14.0, bottom = 12.0;
    final plot = Rect.fromLTRB(
      rtl ? far : near,
      top,
      size.width - (rtl ? near : far),
      size.height - bottom,
    );
    double x(int k) {
      final f = points < 2 ? 0.0 : k / (points - 1);
      return rtl ? plot.right - f * plot.width : plot.left + f * plot.width;
    }

    double y(int v) => plot.bottom - (v - lo) / (hi - lo) * plot.height;

    // A faint line at every round.
    final grid = Paint()
      ..color = const Color(0x0FFFFFFF)
      ..strokeWidth = 1;
    for (var k = 1; k < points; k++) {
      canvas.drawLine(Offset(x(k), plot.top), Offset(x(k), plot.bottom), grid);
    }

    // The zero line, dashed.
    final zero = y(0);
    final dash = Paint()
      ..color = const Color(0x40FFFFFF)
      ..strokeWidth = 1.5;
    for (var d = plot.left; d < plot.right; d += 10) {
      canvas.drawLine(
          Offset(d, zero), Offset(math.min(d + 5, plot.right), zero), dash);
    }

    void text(String t, double cy, {bool top = false}) {
      final p = TextPainter(
        text: TextSpan(text: t, style: label),
        textDirection: TextDirection.ltr,
      )..layout();
      final dx = rtl ? size.width - 8 - p.width : 8.0;
      p.paint(canvas, Offset(dx, top ? cy : cy - p.height / 2));
    }

    text('+$hi', 6, top: true);
    text('0', zero);

    // Before the first round there is nothing to draw but the zero line.
    if (points < 2) return;
    for (var i = 0; i < series.length; i++) {
      final s = series[i];
      final path = Path()..moveTo(x(0), y(s[0]));
      for (var k = 1; k < s.length; k++) {
        path.lineTo(x(k), y(s[k]));
      }
      // Only as much of the line as the draw-in has reached.
      var shown = path;
      var end = Offset(x(0), y(s[0]));
      final metric = path.computeMetrics().firstOrNull;
      if (metric != null) {
        final upTo = metric.length * progress;
        shown = metric.extractPath(0, upTo);
        end = metric.getTangentForOffset(upTo)?.position ?? end;
      }
      final ink = kSeatInk[i % kSeatInk.length];
      Paint stroke(Color c, double w) => Paint()
        ..color = c
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(shown, stroke(const Color(0x80050505), 6));
      canvas.drawPath(shown, stroke(ink, 3));
      canvas.drawCircle(end, 6, Paint()..color = ink);
      canvas.drawCircle(end, 6, stroke(Palette.outline, 2));
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.progress != progress ||
      old.rtl != rtl ||
      old.series.toString() != series.toString();
}
