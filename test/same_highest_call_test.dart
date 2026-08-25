import 'package:flutter_test/flutter_test.dart';

import 'package:estimation/models.dart';
import 'package:estimation/rules.dart';
import 'package:estimation/scoring.dart';
import 'package:estimation/strings.dart';

const s = Str(false);

Round called(List<int?> bids, {Suit trump = Suit.sun, List<bool>? dash}) =>
    Round(
      bids: bids,
      dash: dash ?? List<bool>.filled(bids.length, false),
      order: List<int>.generate(bids.length, (i) => i),
      tricks: List<int?>.filled(bids.length, null),
      trump: trump,
    );

void main() {
  final rules = Rules.defaults();

  bool fires(List<int?> bids,
          {Suit trump = Suit.sun,
          bool color = true,
          Rules? with_,
          List<bool>? dash}) =>
      sameHighestCall(called(bids, trump: trump, dash: dash), with_ ?? rules,
          isColorRound: color, trump: trump);

  group('three or more on the highest call', () {
    test('the table shares the top call', () {
      expect(fires([4, 4, 4, 3]), isTrue);
      expect(fires([3, 3, 3, 2]), isTrue);
      expect(fires([4, 4, 4, 4]), isTrue); // all four is three or more
    });

    test('a higher call held alone kills it', () {
      expect(fires([6, 2, 2, 2]), isFalse);
      expect(fires([3, 3, 3, 5]), isFalse);
    });

    test('two on the top is not enough', () {
      expect(fires([5, 5, 3, 2]), isFalse);
    });

    test('it is the shared top, not the total', () {
      // 4+4+4+3 = 15 and 3+3+3+2 = 11 both fire; 6+2+2+2 = 12 does not.
      // Nothing here turns on the total sitting over, under or on thirteen.
      expect(fires([4, 4, 4, 3]), isTrue);
      expect(fires([3, 3, 3, 2]), isTrue);
      expect(fires([6, 2, 2, 2]), isFalse);
    });

    test('a dashed seat called nothing, so it is not counted', () {
      expect(fires([4, 4, 4, 0], dash: [false, false, false, true]), isTrue);
      // ...and a dash cannot itself be the shared top call.
      expect(fires([0, 0, 0, 4], dash: [true, true, true, false]), isFalse);
    });
  });

  group('where the rule is played', () {
    test('the normal auction rounds are left alone by default', () {
      expect(fires([4, 4, 4, 3], color: false), isFalse);
    });

    test('unless the table turns it on for the whole game', () {
      final r = Rules.defaults()..sameHighestCallColorOnly = false;
      expect(fires([4, 4, 4, 3], color: false, with_: r), isTrue);
    });

    test('every colour is covered out of the box', () {
      for (final su in kColorOrder) {
        expect(fires([4, 4, 4, 3], trump: su), isTrue, reason: su.name);
      }
    });

    test('and the table can cut it back to sun alone', () {
      final r = Rules.defaults()..sameHighestCallSuits = [Suit.sun];
      expect(fires([4, 4, 4, 3], trump: Suit.sun, with_: r), isTrue);
      expect(fires([4, 4, 4, 3], trump: Suit.hearts, with_: r), isFalse);
    });

    test('switched off entirely, nothing fires', () {
      final r = Rules.defaults()..sameHighestCallDouble = false;
      expect(fires([4, 4, 4, 3], with_: r), isFalse);
    });

    test('and the count of seats is the table\'s to set', () {
      final r = Rules.defaults()..sameHighestCallMin = 2;
      expect(fires([5, 5, 3, 2], with_: r), isTrue);
    });
  });

  group('what it does to the round', () {
    /// A colour round for Full: thirteen normal rounds come first.
    List<Round> upToColor(Round color) => [
          for (var i = 0; i < 13; i++)
            Round(
              bids: const [5, 4, 3, 2],
              dash: List<bool>.filled(4, false),
              order: const [0, 1, 2, 3],
              tricks: const [5, 4, 3, 1],
              trump: Suit.hearts,
            ),
          color,
        ];

    test('it doubles the colour round it fires in', () {
      final rounds = upToColor(Round(
        bids: const [4, 4, 4, 3],
        dash: List<bool>.filled(4, false),
        order: const [0, 1, 2, 3],
        tricks: const [4, 4, 4, 1],
        trump: Suit.sun,
      ));
      recomputeAll(rounds, rules, 4, s, mode: GameMode.full);
      expect(rounds.last.mult, 2);
      // The plain rounds before it are untouched.
      expect(rounds.first.mult, 1);
    });

    test('and leaves a colour round nobody shared at face value', () {
      final rounds = upToColor(Round(
        bids: const [6, 2, 2, 2],
        dash: List<bool>.filled(4, false),
        order: const [0, 1, 2, 3],
        tricks: const [6, 2, 2, 3],
        trump: Suit.sun,
      ));
      recomputeAll(rounds, rules, 4, s, mode: GameMode.full);
      expect(rounds.last.mult, 1);
    });

    test('stacking is a setting, not an assumption', () {
      List<Round> game(Rules r) {
        // A passed round leaves the next one running at x2, and the colour
        // round after it is where the top call is shared. A passed round takes
        // no Color slot, so the thirteen normal rounds still come first.
        final rounds = <Round>[
          for (var i = 0; i < 13; i++)
            Round(
              bids: const [5, 4, 3, 2],
              dash: List<bool>.filled(4, false),
              order: const [0, 1, 2, 3],
              tricks: const [5, 4, 3, 1],
              trump: Suit.hearts,
            ),
          Round.empty(4)..skipped = true,
          Round(
            bids: const [4, 4, 4, 3],
            dash: List<bool>.filled(4, false),
            order: const [0, 1, 2, 3],
            tricks: const [4, 4, 4, 1],
            trump: Suit.sun,
          ),
        ];
        recomputeAll(rounds, r, 4, s, mode: GameMode.full);
        return rounds;
      }

      final stacked = game(Rules.defaults());
      expect(stacked.last.mult, 4); // x2 already running, x2 on top

      final flat = game(Rules.defaults()..sameHighestCallStacks = false);
      expect(flat.last.mult, 2); // lifted to x2, and no further
    });
  });
}
