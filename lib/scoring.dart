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

  const Derived({
    required this.total,
    required this.top,
    required this.callerOrWith,
    required this.riskIndex,
    required this.riskLevel,
    required this.over,
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

  return Derived(
    total: total,
    top: top,
    callerOrWith: cw,
    riskIndex: riskIdx,
    riskLevel: risk,
    over: total > rules.tricks,
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
