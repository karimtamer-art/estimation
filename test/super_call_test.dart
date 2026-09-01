import 'package:flutter_test/flutter_test.dart';

import 'package:estimation/models.dart';
import 'package:estimation/rules.dart';
import 'package:estimation/scoring.dart';
import 'package:estimation/strings.dart';

const s = Str(false);

/// A four-seat round with seat 0 holding the call. The rest of the table is
/// filled in so the tricks total 13, and seat 0 is not the last to estimate —
/// the Risk sits on seat 3 unless a test moves it, and it only pays at all
/// when the table lands two or more away from 13.
Round call(
  int bid,
  int eaten, {
  required List<int> others,
  required List<int> othersEat,
  List<int>? order,
  int mult = 1,
}) {
  return Round(
    bids: <int?>[bid, ...others],
    dash: List<bool>.filled(1 + others.length, false),
    order: order ?? List<int>.generate(1 + others.length, (i) => i),
    tricks: <int?>[eaten, ...othersEat],
    caller: 0,
    mult: mult,
  );
}

void main() {
  final rules = Rules.defaults();

  // ----------------------------------------------------- the square itself

  test('super 8 made exactly is the square, not 10 + tricks + 10', () {
    // 8 + 2 + 1 + 1 = 12, one under, so no Risk. Seat 3 misses.
    final r = call(8, 8, others: [2, 1, 1], othersEat: [2, 1, 2]);
    final out = scoreRound(r, rules, s);
    expect(out.derived.superCall[0], isTrue);
    expect(out.scores[0], 64);
  });

  test('super 8 missed costs half the square, whatever it ate', () {
    // Eating 7 costs exactly what eating nothing costs: the call is the price.
    for (final eaten in [7, 6, 3, 0]) {
      final r =
          call(8, eaten, others: [2, 1, 1], othersEat: [2, 1, 10 - eaten]);
      final out = scoreRound(r, rules, s);
      expect(out.scores[0], -32, reason: 'eating $eaten on a called 8');
    }
  });

  test('super 9 squares to 81 and halves to -40', () {
    final made = call(9, 9, others: [2, 1, 1], othersEat: [2, 1, 1]);
    expect(scoreRound(made, rules, s).scores[0], 81);

    final missed = call(9, 7, others: [2, 1, 1], othersEat: [2, 1, 3]);
    expect(scoreRound(missed, rules, s).scores[0], -40);
  });

  test('super 10 squares to 100 and halves to -50', () {
    final made = call(10, 10, others: [1, 1, 1], othersEat: [1, 1, 1]);
    expect(scoreRound(made, rules, s).scores[0], 100);

    final missed = call(10, 8, others: [1, 1, 1], othersEat: [1, 1, 3]);
    expect(scoreRound(missed, rules, s).scores[0], -50);
  });

  test('the square runs all the way up to a called 13', () {
    const want = {8: 64, 9: 81, 10: 100, 11: 121, 12: 144, 13: 169};
    for (final e in want.entries) {
      final bid = e.key;
      // One seat soaks up whatever the call leaves; the other two call zero.
      final r =
          call(bid, bid, others: [13 - bid, 0, 0], othersEat: [13 - bid, 0, 0]);
      expect(scoreRound(r, rules, s).scores[0], e.value,
          reason: 'super $bid made');
    }
  });

  test('a missed call is halved with the remainder dropped', () {
    const want = {8: -32, 9: -40, 10: -50, 11: -60, 12: -72, 13: -84};
    for (final e in want.entries) {
      final bid = e.key;
      // The caller comes up one short and the spare trick goes to seat 1,
      // which puts seat 1 off its own call too — so seats 2 and 3 (calling
      // nothing, taking nothing) are the winners and the round is not a wipe.
      final r = call(bid, bid - 1,
          others: [13 - bid, 0, 0], othersEat: [13 - bid + 1, 0, 0]);
      expect(scoreRound(r, rules, s).scores[0], e.value,
          reason: 'super $bid missed');
    }
  });

  // --------------------------------------------------------- the modifiers

  test('sole winner still pays its ten on top of the square', () {
    // Only seat 0 makes it: 64 + 10.
    final r = call(8, 8, others: [2, 1, 1], othersEat: [3, 0, 2]);
    expect(scoreRound(r, rules, s).scores[0], 74);
  });

  test('super 9 sole winner is 91', () {
    // Everyone else off: seat 1 called 2 and ate 4, seats 2 and 3 called 1
    // and ate nothing. 81 + 10.
    final r = call(9, 9, others: [2, 1, 1], othersEat: [4, 0, 0]);
    expect(scoreRound(r, rules, s).scores[0], 91);
  });

  test('sole loser still costs its ten under the halved square', () {
    // Seat 0 is the only one off: -32 and the sole loser -10.
    final r = call(8, 7, others: [2, 1, 1], othersEat: [2, 1, 1]);
    expect(scoreRound(r, rules, s).scores[0], -42);
  });

  test('the Risk still lands on the super caller when it settles last', () {
    // 8 + 4 + 2 + 1 = 15, two over -> one Risk level, and seat 0 estimated
    // last, so it carries it: 64 + 10.
    final r = call(8, 8,
        others: [4, 2, 1], othersEat: [3, 2, 0], order: [1, 2, 3, 0]);
    final out = scoreRound(r, rules, s);
    expect(out.derived.riskIndex, 0);
    expect(out.derived.riskLevel, 1);
    expect(out.scores[0], 74);
  });

  test('the round multiplier scales the whole super call', () {
    final made = call(8, 8, others: [2, 1, 1], othersEat: [2, 1, 2], mult: 2);
    expect(scoreRound(made, rules, s).scores[0], 128);

    final missed = call(8, 6, others: [2, 1, 1], othersEat: [2, 1, 4], mult: 2);
    expect(scoreRound(missed, rules, s).scores[0], -64);
  });

  test('nobody making it still zeroes the round, super call included', () {
    // Every seat off its number, and the tricks still total 13.
    final r = call(8, 7, others: [2, 1, 1], othersEat: [4, 2, 0]);
    final out = scoreRound(r, rules, s);
    expect(out.allMissed, isTrue);
    expect(out.scores.every((x) => x == 0), isTrue);
  });

  // ------------------------------------------------- what it must NOT touch

  test('a call under the threshold is untouched by the super formula', () {
    // The worked examples from the README, unchanged: call 6 and make it is
    // still 26, call 6 and eat 4 is still -22.
    final made = call(6, 6, others: [3, 3, 2], othersEat: [3, 2, 2]);
    final madeOut = scoreRound(made, rules, s);
    expect(madeOut.derived.superCall[0], isFalse);
    expect(madeOut.scores[0], 26);

    final missed = call(6, 4, others: [3, 3, 2], othersEat: [3, 4, 2]);
    expect(scoreRound(missed, rules, s).scores[0], -22);
  });

  test('a seven is the last normal call, an eight is the first super one', () {
    final seven = call(7, 7, others: [3, 2, 1], othersEat: [3, 2, 1]);
    expect(scoreRound(seven, rules, s).scores[0], 27); // 10 + 7 + 10

    final eight = call(8, 8, others: [3, 1, 1], othersEat: [3, 1, 1]);
    expect(scoreRound(eight, rules, s).scores[0], 64);
  });

  test('a seat that is neither Caller nor With never scores on the square', () {
    // Seat 1 called 8 but seat 0 holds the pressed call, so seat 1 is scored
    // the ordinary way even though its number is over the threshold.
    final r = Round(
      bids: const <int?>[9, 8, 1, 1],
      dash: const [false, false, false, false],
      order: const [0, 1, 2, 3],
      tricks: const <int?>[9, 2, 1, 1],
      caller: 0,
    );
    final out = scoreRound(r, rules, s);
    expect(out.derived.superCall, [true, false, false, false]);
    expect(out.scores[0], 81);
    expect(out.scores[1], -26); // -10, the -6 difference, and the sole loser
  });

  test('a dash is still a dash, never a super call', () {
    // Seat 0 dashes; seat 1 holds a super call of 8.
    final r = Round(
      bids: const <int?>[0, 8, 2, 1],
      dash: const [true, false, false, false],
      order: const [1, 2, 3],
      tricks: const <int?>[0, 8, 2, 3],
      caller: 1,
    );
    final out = scoreRound(r, rules, s);
    expect(out.derived.superCall[0], isFalse);
    expect(out.scores[0], rules.dashUnder); // 11 on the table, under
    expect(out.scores[1], 64);
  });

  test('a With sitting on the same super call scores the same square', () {
    // The app has always paid Caller and With alike; the square keeps that.
    // Seat 2 makes its 2 and seat 3 misses its 1, so neither sole bonus
    // fires and the two squares stand on their own.
    final r = call(8, 8, others: [8, 2, 1], othersEat: [3, 2, 0]);
    final out = scoreRound(r, rules, s);
    expect(out.derived.callerOrWith, [true, true, false, false]);
    expect(out.derived.superCall, [true, true, false, false]);
    expect(out.scores[0], 64);
    expect(out.scores[1], -32);
  });

  test('turning the rule off restores the old caller scoring', () {
    final off = Rules.defaults()..superCallOwnScore = false;

    final made = call(8, 8, others: [2, 1, 1], othersEat: [2, 1, 2]);
    final out = scoreRound(made, off, s);
    expect(out.derived.superCall[0], isFalse);
    expect(out.scores[0], 28); // 10 + 8 + 10, the way it scored before

    final missed = call(8, 6, others: [2, 1, 1], othersEat: [2, 1, 4]);
    expect(scoreRound(missed, off, s).scores[0], -22); // -10, -2, -10
  });

  test('the breakdown shows one super line, no round score and no caller', () {
    final r = call(8, 8, others: [2, 1, 1], othersEat: [2, 1, 2]);
    final labels =
        scoreRound(r, rules, s).lines[0].map((l) => l.label).toList();
    expect(labels, contains(s.superCall));
    expect(labels, isNot(contains(s.roundScore)));
    expect(labels, isNot(contains(s.tricksAmount)));
    expect(labels, isNot(contains(s.callerWith)));
  });
}
