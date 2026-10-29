import 'package:flutter/material.dart';

import '../../controller.dart';
import '../../models.dart';
import '../../scoring.dart';
import '../../strings.dart';
import '../avatars.dart';
import '../components.dart';
import '../frame.dart';
import '../tokens.dart';

const _medals = [
  [Palette.goldHi, Palette.goldLo],
  [Palette.silverHi, Palette.silverLo],
  [Color(0xFFF2B27A), Color(0xFFC4733A)],
  [Color(0xFF5A6790), Palette.darkHi],
];

/// After every round and at the end of the game: the standings on the left,
/// the sheet round by round on the right. Every number is the engine's —
/// [summarize] for the standings, each round's own scores for the sheet.
class ScoreboardView extends StatefulWidget {
  final GameController c;
  const ScoreboardView({super.key, required this.c});

  @override
  State<ScoreboardView> createState() => _ScoreboardViewState();
}

class _ScoreboardViewState extends State<ScoreboardView> {
  GameController get c => widget.c;

  /// EDIT A ROUND arms the sheet: rows only open for editing while it is on,
  /// so a stray tap on the table cannot walk a finished round back open.
  bool _picking = false;

  @override
  Widget build(BuildContext context) {
    final s = c.s;
    final g = summarize(c.rounds, c.playerCount);
    final over = c.screen == Screen.done;

    return ScreenFrame(
      c: c,
      header: TitleHeader(
        title: over ? s.gameOver : s.scoreboard,
        badge: GameBadge(
          s.afterRound(c.playedCount, c.mode.totalRounds),
          tone: BadgeTone.dash,
        ),
        buttons: [HeaderButtons.home(c), HeaderButtons.language(c)],
      ),
      body: LayoutBuilder(builder: (context, box) {
        final side = (box.maxWidth * 0.36).clamp(300.0, 470.0);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: side, child: _Standings(c: c, g: g)),
            const SizedBox(width: 18),
            Expanded(
              child: ScoreSheet(
                c: c,
                onPick: _picking
                    ? (i) {
                        setState(() => _picking = false);
                        c.editRound(i);
                      }
                    : null,
              ),
            ),
          ],
        );
      }),
      bottom: BottomBar(
        height: 72,
        lead: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _picking ? s.tapToEdit : _message(g),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: body(16,
                  weight: FontWeight.w800,
                  color: _picking ? Palette.gold : Palette.secondary),
            ),
            if (over && g.bestSeat != null)
              Text(
                '${s.biggestWin}: ${c.players[g.bestSeat!]} '
                '${signedPoints(g.bestValue)}'
                '${g.worstSeat == null ? '' : '  \u00b7  ${s.biggestLoss}: '
                    '${c.players[g.worstSeat!]} ${signedPoints(g.worstValue)}'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: body(13, color: Palette.muted),
              ),
          ],
        ),
        actions: over
            ? [
                GameButton(
                  label: s.leave,
                  tone: ButtonTone.dark,
                  width: 120,
                  fontSize: 17,
                  onTap: c.goHome,
                ),
                GameButton(
                  label: s.undo,
                  tone: ButtonTone.dark,
                  width: 120,
                  fontSize: 17,
                  onTap: c.undoLast,
                ),
                GameButton(
                  label: s.newGame,
                  width: 200,
                  fontSize: 19,
                  onTap: c.newGame,
                ),
              ]
            : [
                GameButton(
                  label: _picking ? s.doneEditing : s.editARound,
                  tone: ButtonTone.dark,
                  selected: _picking,
                  width: 170,
                  fontSize: 17,
                  onTap: c.playedCount == 0
                      ? null
                      : () => setState(() => _picking = !_picking),
                ),
                GameButton(
                  label: c.playedCount >= c.mode.totalRounds
                      ? s.finish
                      : s.nextRound,
                  width: 230,
                  fontSize: 19,
                  onTap: c.continueAfterResult,
                ),
              ],
      ),
    );
  }

  /// What the bar says: why the round just played was worth more (or that
  /// it was passed), then who is ahead and by how much.
  String _message(GameSummary g) {
    final s = c.s;
    if (c.screen == Screen.result && c.lastMessage != null) {
      return c.lastMessage!;
    }
    if (g.played == 0) return s.noRoundsPlayed;
    final best = g.totals[g.ranking.first];
    final top = [
      for (var i = 0; i < g.totals.length; i++)
        if (g.totals[i] == best) c.players[i],
    ];
    if (c.screen == Screen.done) {
      return '${top.join(' & ')} ${top.length > 1 ? s.tieAt : s.winsWith} '
          '$best ${s.points}';
    }
    final left = c.mode.totalRounds - c.playedCount;
    if (top.length > 1) return s.tiedTop(top, left);
    final second = g.totals[g.ranking[1]];
    return s.leadsBy(top.single, best - second, left);
  }
}

class _Standings extends StatelessWidget {
  final GameController c;
  final GameSummary g;
  const _Standings({required this.c, required this.g});

  @override
  Widget build(BuildContext context) {
    final s = c.s;
    return LayoutBuilder(
      builder: (context, box) => Column(
        children: [
          for (var k = 0; k < g.ranking.length; k++) ...[
            if (k > 0) const SizedBox(height: 10),
            Expanded(child: _row(s, k, g.ranking[k], box.maxWidth)),
          ],
        ],
      ),
    );
  }

  Widget _row(Str s, int place, int seat, double width) {
    final top = seat == g.leader;
    final fg = top ? Palette.onGold : Palette.text;
    final medal = _medals[place.clamp(0, _medals.length - 1)];
    // A narrow column tightens the row rather than squeezing the name out.
    final tight = width < 420;
    final medalSize = tight ? 32.0 : 40.0;
    final face = tight ? 44.0 : 56.0;
    final gap = tight ? 8.0 : 14.0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: tight ? 10 : 16),
      decoration: BoxDecoration(
        gradient: top
            ? vgrad(Palette.goldHi, Palette.goldLo)
            : vgrad(Palette.darkHi, Palette.darkLo),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.outline, width: 2),
        boxShadow: hardShadow(4),
      ),
      child: Row(
        children: [
          Container(
            width: medalSize,
            height: medalSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: vgrad(medal[0], medal[1]),
              border: Border.all(color: Palette.outline, width: 2),
              boxShadow: hardShadow(2),
            ),
            child: Text('${place + 1}',
                style: display(medalSize * 0.55,
                    color: Palette.onGold, height: 1)),
          ),
          SizedBox(width: gap),
          HeadMark(
            size: face,
            crown: c.crowned.contains(seat),
            kooz: c.koozed.contains(seat),
            child: Container(
              width: face,
              height: face,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF4F6F5), width: 3),
                boxShadow: const [
                  BoxShadow(color: Palette.outline, spreadRadius: 1.5),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: AvatarFace(index: c.avatars[seat], size: face - 6),
              ),
            ),
          ),
          SizedBox(width: gap),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.players[seat],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: body(20, weight: FontWeight.w900, color: fg)),
                Opacity(
                  opacity: 0.8,
                  child: Text(s.madeOfCalls(g.won[seat], g.played),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: body(13, weight: FontWeight.w800, color: fg)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // A long total gives way before the name does.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                signedPoints(g.totals[seat], plus: false),
                style: display(40, color: fg, height: 1).copyWith(
                  shadows: top
                      ? null
                      : const [
                          Shadow(offset: Offset(0, 3), color: Palette.outline)
                        ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The paper sheet, in the table's colours. Every row reads the way the
/// paper one does: each seat's running total with the round's points beside
/// it, ▲ or ▼ for made or missed, and the call it made — the caller's in
/// gold, W on a With, 1R/2R on the Risk, DASH on a dash. The last column
/// says how far the calls sat from 13. It opens on the latest round, just
/// above the totals. With [onPick] set, a played round is tapped to edit it.
class ScoreSheet extends StatelessWidget {
  final GameController c;
  final ValueChanged<int>? onPick;
  const ScoreSheet({super.key, required this.c, this.onPick});

  static const _roundW = 58.0;
  static const _trumpW = 46.0;
  static const _diffW = 50.0;

  Widget _grid(List<Widget> seats,
      {required Widget round, Widget? trump, Widget? diff}) {
    return Row(
      children: [
        SizedBox(width: _roundW, child: round),
        SizedBox(width: _trumpW, child: trump),
        for (final w in seats) Expanded(child: w),
        SizedBox(width: _diffW, child: Center(child: diff)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = c.s;
    final totals = c.totals;

    // Running totals after each round, worked out once for the whole sheet.
    final running = <List<int>>[];
    final acc = List<int>.filled(c.playerCount, 0);
    for (final r in c.rounds) {
      for (var k = 0; k < c.playerCount; k++) {
        acc[k] += k < r.scores.length ? r.scores[k] : 0;
      }
      running.add(List<int>.from(acc));
    }

    final head = display(14, color: Palette.secondary, spacing: 0.06);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Palette.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Palette.panelBorder, width: 1.5),
      ),
      child: Column(
        children: [
          Container(
            height: 46,
            color: const Color(0x4D000000),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _grid(
              [
                for (final p in c.players)
                  Center(
                    child: Text(p.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: head),
                  ),
              ],
              round: Text(s.roundCol.toUpperCase(), style: head),
              trump: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(s.trumpCol.toUpperCase(), style: head),
              ),
              diff: Text('±13', style: head),
            ),
          ),
          Expanded(
            child: c.rounds.isEmpty
                ? Center(
                    child:
                        Text(s.noRounds, style: body(15, color: Palette.muted)),
                  )
                // Reversed so it opens on the round just played, sitting on
                // the totals; older rounds are a scroll up.
                : ListView(
                    reverse: true,
                    children: [
                      for (var i = c.rounds.length - 1; i >= 0; i--)
                        _row(i, running[i]),
                    ],
                  ),
          ),
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: const BoxDecoration(
              color: Color(0x59000000),
              border:
                  Border(top: BorderSide(color: Color(0x80000000), width: 2)),
            ),
            child: _grid(
              [
                for (var k = 0; k < totals.length; k++)
                  Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        signedPoints(totals[k], plus: false),
                        style: display(24,
                            color: c.crowned.contains(k)
                                ? Palette.gold
                                : c.koozed.contains(k)
                                    ? Palette.redText
                                    : Palette.text),
                      ),
                    ),
                  ),
              ],
              round: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(s.totalWord.toUpperCase(),
                    style: display(16, color: Palette.gold, spacing: 0.06)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(int i, List<int> running) {
    final s = c.s;
    final r = c.rounds[i];
    final d = derive(r, c.rules);
    // The seat that holds the call: the one pressed, or the first on the top
    // number. Anyone else on that number is its With.
    final caller = r.caller ?? d.callerOrWith.indexWhere((x) => x);
    final t = r.trump;
    final pickable = onPick != null && !r.skipped;

    final row = Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: pickable
            ? const Color(0x1FFFD23F)
            : i.isOdd
                ? const Color(0x08FFFFFF)
                : null,
        border: Border(
          top: const BorderSide(color: Color(0x0FFFFFFF)),
          // A passed round is ruled off in red, as on the paper sheet.
          bottom: r.skipped
              ? const BorderSide(color: Palette.redLo, width: 1.5)
              : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _roundW,
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '${i + 1}', style: display(18)),
              if (r.mult > 1)
                TextSpan(
                    text: ' ×${r.mult}',
                    style: display(12, color: Palette.gold)),
            ])),
          ),
          SizedBox(
            width: _trumpW,
            child: r.skipped || t == null
                ? null
                : Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: SuitGlyph(t,
                        size: 20,
                        color: t == Suit.sun
                            ? Palette.gold
                            : t.isRed
                                ? const Color(0xFFFF6B5B)
                                : Palette.text),
                  ),
          ),
          if (r.skipped)
            Expanded(
              child: Text(s.passedRow,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: display(14, color: Palette.redText, spacing: 0.04)),
            )
          else
            for (var k = 0; k < c.playerCount; k++)
              Expanded(
                child: _cell(r, d, k, running[k],
                    isCaller: k == caller,
                    isWith: k != caller && d.callerOrWith[k]),
              ),
          SizedBox(
            width: _diffW,
            child: r.skipped
                ? null
                : Center(
                    child: Text(signedPoints(d.total - c.rules.tricks),
                        style: display(15, color: Palette.muted)),
                  ),
          ),
        ],
      ),
    );
    return pickable
        ? Semantics(
            button: true,
            child: GestureDetector(onTap: () => onPick!(i), child: row),
          )
        : row;
  }

  /// One seat on one round: ▲/▼, its running total and what the round was
  /// worth, then the call it made.
  Widget _cell(Round r, Derived d, int k, int total,
      {required bool isCaller, required bool isWith}) {
    final score = k < r.scores.length ? r.scores[k] : 0;
    final made = r.dash[k] ? r.tricks[k] == 0 : r.tricks[k] == r.bids[k];
    final risk = d.riskIndex == k && d.riskLevel > 0;
    return Container(
      decoration: const BoxDecoration(
        border: BorderDirectional(start: BorderSide(color: Color(0x14FFFFFF))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(made ? '▲' : '▼',
                style: TextStyle(
                    fontSize: 11,
                    color: made ? Palette.greenText : Palette.redText)),
            const SizedBox(width: 5),
            Text(signedPoints(total, plus: false), style: display(19)),
            const SizedBox(width: 5),
            Text(signedPoints(score),
                style: display(12,
                    color: score > 0
                        ? Palette.greenText
                        : score < 0
                            ? Palette.redText
                            : Palette.muted)),
            const SizedBox(width: 6),
            _CallChip(
              call: r.dash[k] ? null : r.bids[k],
              caller: isCaller,
              isWith: isWith,
              risk: risk ? c.s.riskLabel(d.riskLevel) : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// What a seat called on one round: the number in its own box — gold for
/// the caller — with W on a With, the Risk in red, or DASH.
class _CallChip extends StatelessWidget {
  /// Null for a dash.
  final int? call;
  final bool caller;
  final bool isWith;
  final String? risk;
  const _CallChip({
    required this.call,
    this.caller = false,
    this.isWith = false,
    this.risk,
  });

  @override
  Widget build(BuildContext context) {
    Widget tag(String text, List<Color> face, Color fg) => Container(
          margin: const EdgeInsetsDirectional.only(start: 3),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            gradient: vgrad(face[0], face[1]),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Palette.outline, width: 1.5),
          ),
          child: Text(text, style: display(10, color: fg)),
        );

    final n = call;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(minWidth: 26),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            gradient: caller
                ? vgrad(Palette.goldHi, Palette.goldLo)
                : n == null
                    ? vgrad(Palette.silverHi, Palette.silverLo)
                    : null,
            color: caller || n == null ? null : const Color(0x33000000),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: caller || n == null
                    ? Palette.outline
                    : const Color(0x33FFFFFF),
                width: 1.5),
          ),
          child: Text(
            n == null ? 'DASH' : '$n',
            textAlign: TextAlign.center,
            style: display(n == null ? 10 : 14,
                color: caller || n == null ? Palette.onGold : Palette.text),
          ),
        ),
        if (isWith)
          tag('W', const [Color(0xFF86B6F5), Color(0xFF3F78D4)], Palette.text),
        if (risk != null)
          tag(risk!, const [Palette.riskHi, Palette.riskLo], Palette.text),
      ],
    );
  }
}
