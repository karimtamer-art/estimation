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

  /// Per player: true if they are Caller or With. Caller is simply the highest
  /// estimate; anyone matching it is With. The two score identically, so a tie
  /// at the top needs no tie-break.
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

  int? top;
  for (var i = 0; i < r.bids.length; i++) {
    final b = r.bids[i];
    if (!r.dash[i] && b != null && (top == null || b > top)) top = b;
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

class ChainResult {
  /// Multiplier the next round starts at (sa'aydeh carry).
  final int pendingMult;

  /// Consecutive rounds where nobody made their bid.
  final int streak;
  const ChainResult(this.pendingMult, this.streak);
}

/// Rescores the whole game in order. Multipliers depend on history, so editing
/// round 4 correctly rebuilds rounds 5 onward.
ChainResult recomputeAll(List<Round> rounds, Rules rules, int n, Str s) {
  var streak = 0;
  for (final r in rounds) {
    final base =
        streak > 0 ? rules.ladder[(streak - 1).clamp(0, rules.ladder.length - 1)] : 1;
    r.mult = base * r.houseMult;

    if (r.skipped) {
      r.scores = List<int>.filled(n, 0);
      r.lines = List<List<ScoreLine>>.generate(n, (_) => const []);
      streak++;
      continue;
    }

    final out = scoreRound(r, rules, s);
    r.scores = out.scores;
    r.lines = out.lines;
    streak = out.allMissed ? streak + 1 : 0;
  }

  final pending =
      streak > 0 ? rules.ladder[(streak - 1).clamp(0, rules.ladder.length - 1)] : 1;
  return ChainResult(pending, streak);
}
