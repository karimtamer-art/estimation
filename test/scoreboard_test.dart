import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:estimation/controller.dart';
import 'package:estimation/main.dart';
import 'package:estimation/models.dart';
import 'package:estimation/ui/screens/scoreboard.dart';
import 'package:estimation/ui/tokens.dart';

/// The sheet on the result screen, read the way the paper one is: running
/// totals on every row, the call with its markers, and the distance from 13.
void main() {
  testWidgets('every row carries the running total and the call', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1830, 824);
    t.view.devicePixelRatio = 2.0;
    addTearDown(t.view.reset);

    final c = GameController()
      ..players = ['Karim', 'Ali', 'Sara', 'Omar']
      ..mode = GameMode.mini
      ..screen = Screen.result;
    c.rounds = [
      Round(
        bids: [5, 4, 3, 2],
        dash: List<bool>.filled(4, false),
        order: const [0, 1, 2, 3],
        tricks: [5, 4, 2, 2],
        caller: 0,
        trump: Suit.hearts,
        scores: [25, 14, -11, 12],
      ),
      // Ali sits on the Caller's number, so he is its With; Omar called last
      // with the table three over, so he carries the Risk.
      Round(
        bids: [6, 6, 1, 3],
        dash: List<bool>.filled(4, false),
        order: const [0, 1, 2, 3],
        tricks: [6, 5, 1, 1],
        caller: 0,
        trump: Suit.spades,
        scores: [26, -11, 11, -12],
      ),
    ];
    c.resultIndex = 1;

    await t.pumpWidget(EstimationApp(controller: c));
    await t.pumpAndSettle();

    // Running totals, not the round's own points: Karim is 25 then 51.
    final sheet = find.byType(ScoreSheet);
    Finder inSheet(String t) =>
        find.descendant(of: sheet, matching: find.text(t));
    expect(inSheet('25'), findsOneWidget);
    // Round 2's row, and the totals underneath it.
    expect(inSheet('51'), findsNWidgets(2));
    // The round's own points ride beside them.
    expect(find.text(signedPoints(26)), findsOneWidget);
    // Made and missed, at a glance.
    expect(find.text('▲'), findsNWidgets(5));
    expect(find.text('▼'), findsNWidgets(3));
    // Each round's trump, the With a W, the Risk its level.
    expect(find.text('♥'), findsOneWidget);
    expect(find.text('♠'), findsOneWidget);
    expect(find.text('W'), findsOneWidget);
    expect(find.text('1R'), findsOneWidget);
    // How far the calls sat from 13: one over, then three over.
    expect(find.text(signedPoints(1)), findsOneWidget);
    expect(find.text(signedPoints(3)), findsOneWidget);
  });

  testWidgets('a passed round reads as passed', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1830, 824);
    t.view.devicePixelRatio = 2.0;
    addTearDown(t.view.reset);

    final c = GameController()
      ..players = ['Karim', 'Ali', 'Sara', 'Omar']
      ..screen = Screen.result
      ..rounds = [Round.empty(4)..skipped = true];
    c.resultIndex = 0;

    await t.pumpWidget(EstimationApp(controller: c));
    await t.pumpAndSettle();

    expect(find.text('PASSED — next round doubled'), findsOneWidget);
  });
}
