import 'package:flutter_test/flutter_test.dart';

import 'package:estimation/models.dart';
import 'package:estimation/rules.dart';
import 'package:estimation/scoring.dart';
import 'package:estimation/strings.dart';

const s = Str(false);

Round build({
  required List<int?> bids,
  required List<int?> tricks,
  List<bool>? dash,
  List<int>? order,
  int mult = 1,
}) {
  return Round(
    bids: bids,
    dash: dash ?? List<bool>.filled(bids.length, false),
    order: order ?? List<int>.generate(bids.length, (i) => i),
    tricks: tricks,
    mult: mult,
  );
}

void main() {
  final rules = Rules.defaults();

  test('caller making the bid exactly scores 10 + tricks + 10', () {
    // Caller bid 6 and ate 6. Total 6+3+3+2 = 14 -> over round, no risk (diff 1).
    final r = build(bids: [6, 3, 3, 2], tricks: [6, 3, 2, 2]);
    final out = scoreRound(r, rules, s);
    // round score 10 + tricks 6 + caller 10 = 26
    expect(out.scores[0], 26);
  });

  test('caller missing costs round score + difference + caller penalty', () {
    // Caller bid 6, ate 4 -> -10 -2 -10 = -22
    final r = build(bids: [6, 3, 3, 2], tricks: [4, 3, 4, 2]);
    final out = scoreRound(r, rules, s);
    expect(out.scores[0], -22);
  });

  test('With scores identically to the caller', () {
    final r = build(bids: [6, 6, 1, 2], tricks: [6, 6, 1, 0]);
    final out = scoreRound(r, rules, s);
    expect(out.scores[0], out.scores[1]);
  });

  test('risk lands on the last player to estimate and scales in steps of two',
      () {
    // total 5+3+3+4 = 15 -> two away from 13 -> one risk level
    final r = build(
      bids: [5, 3, 3, 4],
      tricks: [5, 3, 3, 2],
      order: [0, 1, 2, 3],
    );
    final d = derive(r, rules);
    expect(d.riskIndex, 3);
    expect(d.riskLevel, 1);
    expect(d.over, isTrue);
  });

  test('risk level 2 at four away from 13', () {
    final r = build(bids: [5, 5, 5, 2], tricks: [5, 5, 3, 0]);
    expect(derive(r, rules).riskLevel, 2);
  });

  test('dash pays over/under rates', () {
    // total of live estimates 4+4+2 = 10 -> under round
    final r = build(
      bids: [0, 4, 4, 2],
      tricks: [0, 4, 4, 5],
      dash: [true, false, false, false],
      order: [1, 2, 3],
    );
    final out = scoreRound(r, rules, s);
    expect(out.derived.over, isFalse);
    expect(out.scores[0], rules.dashUnder);
  });

  test('nobody making their bid zeroes the round', () {
    final r = build(bids: [5, 4, 3, 2], tricks: [4, 5, 2, 2]);
    final out = scoreRound(r, rules, s);
    expect(out.allMissed, isTrue);
    expect(out.scores.every((x) => x == 0), isTrue);
  });

  test('all-miss ladder doubles then triples the following rounds', () {
    final miss = () => build(bids: [5, 4, 3, 2], tricks: [4, 5, 2, 2]);
    final rounds = [miss(), miss(), build(bids: [5, 4, 3, 2], tricks: [5, 4, 3, 1])];
    final chain = recomputeAll(rounds, rules, 4, s);
    expect(rounds[0].mult, 1);
    expect(rounds[1].mult, 2); // after one all-miss
    expect(rounds[2].mult, 3); // after two
    expect(chain.streak, 0); // last round had a winner
  });

  test('multiplier scales the whole round', () {
    final r = build(bids: [6, 3, 3, 2], tricks: [6, 3, 2, 2], mult: 2);
    final out = scoreRound(r, rules, s);
    expect(out.scores[0], 52);
  });
}
