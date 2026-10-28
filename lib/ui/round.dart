import 'package:flutter/material.dart';

import '../controller.dart';
import '../models.dart';
import 'components.dart';
import 'frame.dart';
import 'pulldown.dart';
import 'screens/scoreboard.dart';
import 'tokens.dart';

/// The stops on the phase track. The engine walks finer steps (see
/// [BidStep]); this is how they group for the table. The dash has no stop
/// of its own: its window opens over the bid.
enum RoundPhase { bid, calls, tricks }

/// Which phase the round on screen is in, read off the engine's own step.
RoundPhase phaseOf(GameController c) {
  if (c.screen == Screen.tricks) return RoundPhase.tricks;
  // A Color round has no dash and no pressed call: the table just estimates.
  if (c.isColorRound) return RoundPhase.calls;
  switch (c.bidStep) {
    case BidStep.dash:
    case BidStep.caller:
    case BidStep.trump:
    case BidStep.callerBid:
      return RoundPhase.bid;
    case BidStep.table:
    case BidStep.ready:
      return RoundPhase.calls;
  }
}

/// Round number being played, counted the way the old header counted it.
int roundNumber(GameController c) =>
    (c.editingIndex ?? c.playedCount) + 1 > c.mode.totalRounds
        ? c.mode.totalRounds
        : (c.editingIndex ?? c.playedCount) + 1;

/// Round tile · phase track (or [center]) · home, language, scoreboard.
/// The tile is the pull-down scoresheet's handle.
class RoundHeader extends StatelessWidget {
  final GameController c;
  final Widget? center;
  const RoundHeader({super.key, required this.c, this.center});

  @override
  Widget build(BuildContext context) {
    final s = c.s;
    final phase = phaseOf(c);
    return SizedBox(
      height: 62,
      child: Row(
        children: [
          SizedBox(
            width: 230,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: ScoreHandle(c: c),
            ),
          ),
          Expanded(
            child: Center(
              child: center != null
                  ? FittedBox(fit: BoxFit.scaleDown, child: center)
                  : PhaseTrack(
                      phases: [s.phaseBid, s.phaseCalls, s.phaseTricks],
                      current: phase.index,
                    ),
            ),
          ),
          SizedBox(
            width: 230,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                HeaderButtons.home(c),
                const SizedBox(width: 10),
                HeaderButtons.language(c),
                const SizedBox(width: 10),
                GameButton.icon(
                  onTap: () => showScoreSheet(context, c),
                  semantics: s.scoreboard,
                  child: const Icon(Icons.bar_chart_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The running sheet, opened over the round from its header.
Future<void> showScoreSheet(BuildContext context, GameController c) {
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0xA8040816),
    builder: (_) => Directionality(
      textDirection: c.arabic ? TextDirection.rtl : TextDirection.ltr,
      child: Dialog(
        backgroundColor: const Color(0xFF18203A),
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Palette.outline, width: 3),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: ScreenTitle(c.s.scoreboard, size: 28)),
                  GameButton.icon(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(child: ScoreSheet(c: c)),
            ],
          ),
        ),
      ),
    ),
  );
}

/// What the round is played under and where the calls sit against 13: the
/// trump plaque, the Color-round badge, and TOTAL / UNDER / OVER.
class TableBanner extends StatelessWidget {
  final GameController c;
  const TableBanner({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    final s = c.s;
    final total = c.derived.total;
    final diff = total - c.rules.tricks;
    final trump = c.lockedTrump ?? c.working.trump;
    final (String label, PlaqueTone tone) = !c.bidsComplete
        ? (s.totalOf(total), PlaqueTone.silver)
        : diff == 0
            ? (s.exactly13, PlaqueTone.red)
            : diff < 0
                ? (s.underBy(-diff), PlaqueTone.green)
                : (s.overBy(diff), PlaqueTone.orange);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (trump != null) ...[
          Plaque(trump.label(c.arabic), suit: trump),
          const SizedBox(width: 12),
        ],
        // A Color round says which colour of the run it is, and that the
        // trump came with it rather than from a caller.
        if (c.lockedTrump != null) ...[
          GameBadge(
            s.colorRoundOf(c.colorRoundNumber, c.mode.colorRounds),
            tone: BadgeTone.dash,
            size: 14,
          ),
          const SizedBox(width: 12),
        ],
        Plaque(label, tone: tone),
      ],
    );
  }
}
