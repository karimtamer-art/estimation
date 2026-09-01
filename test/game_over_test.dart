import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:estimation/controller.dart';
import 'package:estimation/main.dart';
import 'package:estimation/models.dart';
import 'package:estimation/scoring.dart';
import 'package:estimation/screens.dart';

/// Plays [mode] all the way out, the way the table does it: score a round,
/// press Continue, score the next. Leaves the controller on whatever screen
/// the game actually landed on.
GameController playOut(GameMode mode) {
  final c = GameController()
    ..players = ['Karim', 'Ali', 'Sara', 'Omar']
    ..mode = mode
    ..screen = Screen.bid;

  for (var i = 0; i < mode.totalRounds; i++) {
    c.working = Round(
      bids: <int?>[5, 4, 3, 2],
      dash: List<bool>.filled(4, false),
      order: const [0, 1, 2, 3],
      tricks: <int?>[5, 4, 3, 1],
      caller: 0,
      trump: mode.fixedTrump(i) ?? Suit.hearts,
    );
    c.commit();
    c.continueAfterResult();
  }
  return c;
}

void main() {
  // The white screen: the round counter walks one past the last round, and
  // the Color order has nothing at that index to hand back.
  group('the round after the last one has no trump to look up', () {
    for (final mode in GameMode.values) {
      test('${mode.name}: fixedTrump past the end is null, not a crash', () {
        expect(mode.fixedTrump(mode.totalRounds), isNull);
        expect(mode.fixedTrump(mode.totalRounds + 5), isNull);
      });
    }
  });

  test('every color round still gets its trump, in order', () {
    expect(
      [
        for (var i = 0; i < GameMode.full.totalRounds; i++)
          GameMode.full.fixedTrump(i)
      ],
      [...List<Suit?>.filled(13, null), ...kColorOrder],
    );
    expect(
      [
        for (var i = 0; i < GameMode.mini.totalRounds; i++)
          GameMode.mini.fixedTrump(i)
      ],
      [...List<Suit?>.filled(5, null), ...kColorOrder],
    );
    // Micro has no color rounds at all, so it never fixes one.
    expect(
      [
        for (var i = 0; i < GameMode.micro.totalRounds; i++)
          GameMode.micro.fixedTrump(i)
      ],
      List<Suit?>.filled(5, null),
    );
  });

  for (final mode in GameMode.values) {
    testWidgets('${mode.name}: playing every round lands on the end screen',
        (t) async {
      SharedPreferences.setMockInitialValues({});
      t.view.physicalSize = const Size(1600, 720);
      t.view.devicePixelRatio = 2.0;
      addTearDown(t.view.reset);

      final c = playOut(mode);
      expect(c.screen, Screen.done);
      // The tab over the sheet reads this on the done screen; walking off the
      // end of the Color order here is what used to blank the app.
      expect(() => c.currentMult, returnsNormally);

      await t.pumpWidget(EstimationApp(controller: c));
      await t.pumpAndSettle();

      expect(t.takeException(), isNull);
      expect(find.byType(DoneScreen), findsOneWidget);
    });
  }

  // ------------------------------------------------ what the end screen says

  Round played({
    required List<int?> bids,
    required List<int?> tricks,
    required List<int> scores,
    List<bool>? dash,
  }) =>
      Round(
        bids: bids,
        dash: dash ?? List<bool>.filled(bids.length, false),
        order: const [],
        tricks: tricks,
        scores: scores,
      );

  test('the summary totals, ranks and counts the rounds each seat made', () {
    final g = summarize([
      played(
          bids: [3, 3, 3, 3], tricks: [3, 3, 3, 4], scores: [10, 20, 30, -10]),
      played(
          bids: [4, 2, 2, 5], tricks: [4, 2, 3, 4], scores: [24, 12, -11, -25]),
    ], 4);

    expect(g.played, 2);
    expect(g.totals, [34, 32, 19, -35]);
    // Best first, and the seat number breaks a tie so the order never drifts.
    expect(g.ranking, [0, 1, 2, 3]);
    expect(g.won, [2, 2, 1, 0]);
    expect(g.lost, [0, 0, 1, 2]);
    expect(g.leader, 0);
    expect(g.laggard, 3);
    // The single best and worst round of the game, not the totals.
    expect(g.bestSeat, 2);
    expect(g.bestValue, 30);
    expect(g.worstSeat, 3);
    expect(g.worstValue, -25);
  });

  test('a round the table passed belongs to nobody', () {
    final g = summarize([
      played(
          bids: [3, 3, 3, 3], tricks: [3, 3, 3, 4], scores: [10, 20, 30, -10]),
      Round.empty(4)..skipped = true,
    ], 4);

    expect(g.played, 1);
    // The pass adds nothing to either column.
    expect(g.won, [1, 1, 1, 0]);
    expect(g.lost, [0, 0, 0, 1]);
  });

  test('a dash that took nothing counts as a round made', () {
    final g = summarize([
      played(
        bids: [0, 4, 4, 5],
        tricks: [0, 4, 4, 5],
        scores: [33, 24, 24, 25],
        dash: [true, false, false, false],
      ),
    ], 4);
    expect(g.won, [1, 1, 1, 1]);
  });

  test('a shared top or bottom leaves the crown and the koz unclaimed', () {
    final g = summarize([
      played(
          bids: [3, 3, 3, 3], tricks: [3, 3, 3, 4], scores: [10, 10, 10, 10]),
    ], 4);
    expect(g.leader, isNull);
    expect(g.laggard, isNull);
    expect(g.ranking, [0, 1, 2, 3]);
  });

  test('a game with nothing on the sheet has no best or worst round', () {
    final g = summarize(const [], 4);
    expect(g.played, 0);
    expect(g.bestSeat, isNull);
    expect(g.worstSeat, isNull);
    expect(g.leader, isNull);
    expect(g.totals, [0, 0, 0, 0]);
  });

  // The screen is landscape-only, so it has to hold at the short end of the
  // phones it runs on as well as the long one. An overflow throws here.
  for (final size in const [
    Size(1600, 720),
    Size(1280, 600),
    Size(2400, 1080)
  ]) {
    testWidgets(
        'the end screen fits ${size.width.toInt()}x'
        '${size.height.toInt()}', (t) async {
      SharedPreferences.setMockInitialValues({});
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 2.0;
      addTearDown(t.view.reset);

      final c = GameController()
        ..players = ['Abdelrahman', 'Ali', 'Sara', 'Omar']
        ..mode = GameMode.mini
        ..screen = Screen.done
        ..rounds = [
          Round(
            bids: [3, 3, 3, 3],
            dash: List<bool>.filled(4, false),
            order: const [],
            tricks: [3, 3, 3, 4],
            scores: [10, 20, 30, -10],
          ),
        ];

      await t.pumpWidget(EstimationApp(controller: c));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }
}
