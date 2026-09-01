import 'models.dart';
import 'rules.dart';
import 'strings.dart';

/// Everything the app infers from the estimates alone — the player never
/// picks any of this.
class Derived {
  /// Sum of all non-dash estimates.
  final int total;

  /// Highest estimate on the table, or null if everyone dashed.
  final int? top;

  /// Per player: true if they are Caller or With. The Caller is whoever the
  /// table pressed Caller on, or the highest estimate when nobody did; anyone
  /// matching that estimate is With. The two score identically, so a tie at
  /// the top needs no tie-break.
  final List<bool> callerOrWith;

  /// Player carrying the Risk: the last one to settle their estimate.
  final int riskIndex;

  /// Risk level = how far the table sits from 13, in steps of 2.
  final int riskLevel;

  /// True when the table over-estimated (total > tricks).
  final bool over;

  /// Per player: true if this seat owns the call AND called high enough to
  /// make it a Super Call, so it scores on the square instead of the Caller
  /// components. Always all-false while [Rules.superCallOwnScore] is off.
  final List<bool> superCall;

  const Derived({
    required this.total,
    required this.top,
    required this.callerOrWith,
    required this.riskIndex,
    required this.riskLevel,
    required this.over,
    required this.superCall,
  });
}

Derived derive(Round r, Rules rules) {
  var total = 0;
  for (var i = 0; i < r.bids.length; i++) {
    if (!r.dash[i]) total += r.bids[i] ?? 0;
  }

  // The estimate that owns the round. A pressed Caller button says it
  // outright; with nobody pressed it is the highest estimate on the table.
  int? top;
  final chosen = r.caller;
  if (chosen != null && chosen < r.bids.length && !r.dash[chosen]) {
    top = r.bids[chosen];
  } else {
    for (var i = 0; i < r.bids.length; i++) {
      final b = r.bids[i];
      if (!r.dash[i] && b != null && (top == null || b > top)) top = b;
    }
  }

  final cw = List<bool>.generate(
    r.bids.length,
    (i) => !r.dash[i] && r.bids[i] != null && r.bids[i] == top,
  );

  final riskIdx = r.order.isEmpty ? -1 : r.order.last;
  final lvl = ((total - rules.tricks).abs() / 2).floor();
  final risk = (riskIdx >= 0 && !r.dash[riskIdx]) ? lvl : 0;

  // A Super Call belongs to whoever owns the call. Caller and With hold the
  // same number and the app has always scored them identically, so a With
  // sitting on a Super Call is a Super Call too — splitting them would pay two
  // seats wildly different amounts for the very same estimate.
  final sup = List<bool>.generate(
    r.bids.length,
    (i) =>
        rules.superCallOwnScore &&
        cw[i] &&
        (r.bids[i] ?? 0) >= rules.superCallMin,
  );

  return Derived(
    total: total,
    top: top,
    callerOrWith: cw,
    riskIndex: riskIdx,
    riskLevel: risk,
    over: total > rules.tricks,
    superCall: sup,
  );
}

class RoundResult {
  final List<int> scores;
  final List<List<ScoreLine>> lines;
  final bool allMissed;
  final Derived derived;
  const RoundResult(this.scores, this.lines, this.allMissed, this.derived);
}

/// Scores one round. Components are additive; the sum is then multiplied by
/// [Round.mult].
RoundResult scoreRound(Round r, Rules rules, Str s) {
  final n = r.bids.length;
  final d = derive(r, rules);

  final made = List<bool>.generate(
    n,
    (i) => r.dash[i] ? r.tricks[i] == 0 : r.tricks[i] == r.bids[i],
  );
  final wins = made.where((m) => m).length;
  final allMissed = wins == 0;

  if (allMissed && rules.allMissZero) {
    return RoundResult(
      List<int>.filled(n, 0),
      List<List<ScoreLine>>.generate(n, (_) => const []),
      true,
      d,
    );
  }

  final scores = <int>[];
  final lines = <List<ScoreLine>>[];

  for (var i = 0; i < n; i++) {
    final l = <ScoreLine>[];
    final w = made[i];
    final sign = w ? 1 : -1;
    void add(String label, int v) {
      if (v != 0) l.add(ScoreLine(label, v));
    }

    if (r.dash[i]) {
      add(s.dashCall, sign * (d.over ? rules.dashOver : rules.dashUnder));
      if (rules.dashStacksRound) add(s.roundScore, sign * rules.roundScore);
      if (rules.dashStacksSole) {
        if (w && wins == 1) add(s.sole, rules.soleBonus);
        if (!w && wins == n - 1) add(s.soleLoser, -rules.soleBonus);
      }
    } else if (d.superCall[i]) {
      // The square stands in for the round score, the tricks and the Caller
      // bonus all at once — none of the three are added on top of it. A miss
      // is priced off the call alone, so eating 7 on a called 8 costs exactly
      // what eating nothing costs.
      final bid = r.bids[i] ?? 0;
      final div = rules.superCallLossDiv < 1 ? 1 : rules.superCallLossDiv;
      final square = bid * bid;
      add(s.superCall, w ? square : -(square ~/ div));
      if (i == d.riskIndex && d.riskLevel > 0) {
        add('${s.risk} \u00d7${d.riskLevel}',
            sign * rules.perRisk * d.riskLevel);
      }
      if (w && wins == 1) add(s.sole, rules.soleBonus);
      if (!w && wins == n - 1) add(s.soleLoser, -rules.soleBonus);
    } else {
      final bid = r.bids[i] ?? 0;
      final eaten = r.tricks[i] ?? 0;
      add(s.roundScore, sign * rules.roundScore);
      add(
        s.tricksAmount,
        w ? bid : -(rules.lossTricksIsDiff ? (bid - eaten).abs() : bid),
      );
      if (d.callerOrWith[i]) add(s.callerWith, sign * rules.callerOrWith);
      if (i == d.riskIndex && d.riskLevel > 0) {
        add('${s.risk} \u00d7${d.riskLevel}', sign * rules.perRisk * d.riskLevel);
      }
      if (w && wins == 1) add(s.sole, rules.soleBonus);
      if (!w && wins == n - 1) add(s.soleLoser, -rules.soleBonus);
    }

    final base = l.fold<int>(0, (a, x) => a + x.value);
    if (r.mult > 1) {
      l.add(ScoreLine('${s.multiplier} \u00d7${r.mult}', base * r.mult - base));
    }
    lines.add(l);
    scores.add(base * r.mult);
  }

  return RoundResult(scores, lines, allMissed, d);
}

/// Three or more seats sharing the HIGHEST call on the table — the Egyptian
/// Color-round rule that doubles the hand.
///
/// It is about the top of the table being shared, not about matching numbers
/// anywhere on it and not about what the estimates total:
///
///   [4, 4, 4, 3] -> yes, three seats hold the top call of 4
///   [3, 3, 3, 2] -> yes
///   [6, 2, 2, 2] -> no, the top call of 6 is held alone
///   [3, 3, 3, 5] -> no, the top call of 5 is held alone
///   [5, 5, 3, 2] -> no, only two seats hold the top
///
/// A dashed seat called nothing, so it is not counted either way. [trump] is
/// passed in rather than read off the round, because the estimate screen asks
/// this question while the round is still being called.
bool sameHighestCall(
  Round r,
  Rules rules, {
  required bool isColorRound,
  required Suit? trump,
}) {
  if (!rules.sameHighestCallDouble) return false;
  if (rules.sameHighestCallColorOnly && !isColorRound) return false;
  if (trump == null || !rules.sameHighestCallSuits.contains(trump)) {
    return false;
  }

  int? top;
  var sharing = 0;
  for (var i = 0; i < r.bids.length; i++) {
    if (r.dash[i]) continue;
    final b = r.bids[i];
    if (b == null) continue;
    if (top == null || b > top) {
      top = b;
      sharing = 1;
    } else if (b == top) {
      sharing++;
    }
  }
  return top != null && sharing >= rules.sameHighestCallMin;
}

/// What the end screen has to say about a finished game. Read off the rounds
/// themselves, so it costs nothing to keep and never disagrees with the sheet.
class GameSummary {
  /// Final score per seat.
  final List<int> totals;

  /// Seat indices, best total first. Ties keep the seating order.
  final List<int> ranking;

  /// Rounds each seat made its number in, and rounds it did not. A round the
  /// table passed belongs to nobody and is counted in neither.
  final List<int> won;
  final List<int> lost;

  /// The outright top and bottom of the table, or null while it is shared —
  /// nobody wears the crown or the koz on a tie.
  final int? leader;
  final int? laggard;

  /// The single biggest round score of the game and the seat that took it,
  /// and the same for the worst. Null seats mean no round was played.
  final int? bestSeat;
  final int bestValue;
  final int? worstSeat;
  final int worstValue;

  /// Rounds actually played, passes excluded.
  final int played;

  const GameSummary({
    required this.totals,
    required this.ranking,
    required this.won,
    required this.lost,
    required this.leader,
    required this.laggard,
    required this.bestSeat,
    required this.bestValue,
    required this.worstSeat,
    required this.worstValue,
    required this.played,
  });
}

/// Everything the end screen shows, worked out from the rounds alone.
GameSummary summarize(List<Round> rounds, int n) {
  final totals = List<int>.filled(n, 0);
  final won = List<int>.filled(n, 0);
  final lost = List<int>.filled(n, 0);
  int? bestSeat, worstSeat;
  var bestValue = 0, worstValue = 0;
  var played = 0;

  for (final r in rounds) {
    if (r.skipped) continue;
    played++;
    for (var i = 0; i < n; i++) {
      final score = i < r.scores.length ? r.scores[i] : 0;
      totals[i] += score;

      // Made it is the same question the engine asks: a dash wants nothing,
      // everyone else wants exactly what they called.
      final made = i < r.dash.length && r.dash[i]
          ? (i < r.tricks.length && r.tricks[i] == 0)
          : (i < r.tricks.length &&
              i < r.bids.length &&
              r.tricks[i] != null &&
              r.tricks[i] == r.bids[i]);
      made ? won[i]++ : lost[i]++;

      // Strictly better/worse, so a tie leaves the first seat holding it.
      if (bestSeat == null || score > bestValue) {
        bestSeat = i;
        bestValue = score;
      }
      if (worstSeat == null || score < worstValue) {
        worstSeat = i;
        worstValue = score;
      }
    }
  }

  // Ties broken by seat so the order is the same every time it is built.
  final ranking = List<int>.generate(n, (i) => i)
    ..sort((a, b) {
      final byScore = totals[b].compareTo(totals[a]);
      return byScore != 0 ? byScore : a.compareTo(b);
    });

  int? only(bool highest) {
    if (played == 0) return null;
    var mark = totals[0];
    for (final v in totals) {
      if (highest ? v > mark : v < mark) mark = v;
    }
    final holders = [for (var i = 0; i < n; i++) if (totals[i] == mark) i];
    return holders.length == 1 ? holders.first : null;
  }

  return GameSummary(
    totals: totals,
    ranking: ranking,
    won: won,
    lost: lost,
    leader: only(true),
    laggard: only(false),
    bestSeat: played == 0 ? null : bestSeat,
    bestValue: played == 0 ? 0 : bestValue,
    worstSeat: played == 0 ? null : worstSeat,
    worstValue: played == 0 ? 0 : worstValue,
    played: played,
  );
}

class ChainResult {
  /// Multiplier the next round starts at (sa'aydeh carry).
  final int pendingMult;

  /// Consecutive rounds where nobody made their bid.
  final int streak;
  const ChainResult(this.pendingMult, this.streak);
}

/// Rescores the whole game in order. Multipliers depend on history, so editing
/// round 4 correctly rebuilds rounds 5 onward.
///
/// Sa'aydeh, the two ways a round carries into the next one:
///   * the table passed — the next round is worth [Rules.passMult], and
///     passing again leaves it there rather than stacking;
///   * nobody made their bid — whatever is already on the table is multiplied
///     by [Rules.missMultiply], so 1 becomes 2, 2 becomes 4, and on up.
/// Any round somebody wins puts it back to face value.
ChainResult recomputeAll(
  List<Round> rounds,
  Rules rules,
  int n,
  Str s, {
  /// Needed to know which rounds are the fixed-trump Color ones.
  GameMode mode = GameMode.full,
}) {
  // What the round being walked over is worth, carried from the ones behind
  // it. Never below face value, whatever the rules were edited to.
  var pending = 1;
  var streak = 0;
  final grow = rules.missMultiply < 1 ? 1 : rules.missMultiply;
  final pass = rules.passMult < 1 ? 1 : rules.passMult;

  // Color rounds are counted off the rounds actually played, the same way the
  // rest of the app counts them: a round nobody played takes no Color slot.
  var played = 0;

  for (final r in rounds) {
    var roundMult = pending * r.houseMult;
    if (!r.skipped &&
        sameHighestCall(r, rules,
            isColorRound: mode.fixedTrump(played) != null,
            trump: r.trump)) {
      // Stacking is configured, never assumed: on, the double lands on top of
      // whatever the round was already worth; off, it only lifts a round that
      // was not already worth that much.
      final doubled = rules.sameHighestCallMult < 1
          ? roundMult
          : (rules.sameHighestCallStacks
              ? roundMult * rules.sameHighestCallMult
              : (roundMult < rules.sameHighestCallMult
                  ? rules.sameHighestCallMult
                  : roundMult));
      roundMult = doubled;
    }
    r.mult = roundMult;

    if (r.skipped) {
      r.scores = List<int>.filled(n, 0);
      r.lines = List<List<ScoreLine>>.generate(n, (_) => const []);
      if (pending < pass) pending = pass;
      streak++;
      continue;
    }

    final out = scoreRound(r, rules, s);
    r.scores = out.scores;
    r.lines = out.lines;
    if (out.allMissed) {
      pending *= grow;
      streak++;
    } else {
      pending = 1;
      streak = 0;
    }
    played++;
  }

  return ChainResult(pending, streak);
}
