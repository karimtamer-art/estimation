import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:estimation/controller.dart';
import 'package:estimation/main.dart';
import 'package:estimation/models.dart';
import 'package:estimation/scoring.dart';
import 'package:estimation/ui/screens/scoreboard.dart';
import 'package:estimation/ui/tokens.dart';
import 'package:estimation/theme.dart';

/// A phone held sideways, which is the only way this app is used. An overflow
/// anywhere in the seat column fails these outright.
Future<GameController> pumpEntry(WidgetTester t, Screen screen) async {
  SharedPreferences.setMockInitialValues({});
  t.view.physicalSize = const Size(1600, 720);
  t.view.devicePixelRatio = 2.0;
  addTearDown(t.view.reset);

  final c = GameController()
    ..players = ['Karim', 'Ali', 'Sara', 'Omar']
    ..screen = screen;
  if (screen == Screen.tricks) {
    c.working.bids = [5, 4, 3, 3];
    c.working.tricks = List<int?>.filled(4, null);
  }
  // The shell listens to the controller the way the real app does, so a press
  // that changes the round is followed by the rebuild it causes.
  await t.pumpWidget(MaterialApp(
    theme: buildTheme(),
    home: AnimatedBuilder(
      animation: c,
      builder: (_, __) => HomeShell(c: c),
    ),
  ));
  await t.pumpAndSettle();
  return c;
}

void main() {
  testWidgets('bid & trump settles the caller, the trump and the number',
      (t) async {
    final c = await pumpEntry(t, Screen.bid);
    expect(find.text('WHO WON THE BID?'), findsOneWidget);

    // Nobody picked yet: the way on is held shut.
    await t.tap(find.text('CONTINUE TO CALLS'));
    await t.pumpAndSettle();
    expect(c.working.caller, isNull);

    // Seat 0 won it for 7 in hearts. The bid opens on the minimum, and
    // nothing reaches the round until the table moves on.
    await t.tap(find.text('Karim'));
    for (var i = 0; i < 3; i++) {
      await t.tap(find.text('+'));
      await t.pumpAndSettle();
    }
    await t.tap(find.text('♥'));
    await t.pumpAndSettle();
    expect(c.working.caller, isNull, reason: 'nothing lands before Continue');
    expect(find.text('KARIM BIDS 7 · HEARTS'), findsOneWidget);

    await t.tap(find.text('CONTINUE TO CALLS'));
    await t.pumpAndSettle();
    expect(c.working.caller, 0);
    expect(c.working.trump, Suit.hearts);
    expect(c.working.bids[0], 7);

    // With the call down, the rest of the table fills in on the pad. The
    // caller's own number came with the bid, and the seat after it is up.
    expect(find.text('BID'), findsOneWidget);
    expect(c.callingOrder, [1, 2, 3]);
    await t.tap(find.byKey(const ValueKey('pad3')));
    await t.pumpAndSettle();
    expect(c.working.bids[1], 3);
    // Nobody calls over the bid winner's 7.
    await t.tap(find.byKey(const ValueKey('pad8')));
    await t.pumpAndSettle();
    expect(c.working.bids[2], isNull);
    await t.tap(find.byKey(const ValueKey('pad7')));
    await t.pumpAndSettle();
    expect(c.working.bids[2], 7);
  });

  testWidgets('the bid never goes under the minimum, and a dasher cannot win',
      (t) async {
    final c = await pumpEntry(t, Screen.bid);
    c.toggleDash(1);
    await t.pumpAndSettle();

    // Ali dashed, so pressing him picks nobody.
    await t.tap(find.text('Ali'));
    await t.pumpAndSettle();
    expect(find.text('PICK WHO WON THE BID'), findsOneWidget);

    await t.tap(find.text('Sara'));
    await t.pumpAndSettle();
    await t.tap(find.text('−'));
    await t.pumpAndSettle();
    await t.tap(find.text('♠'));
    await t.pumpAndSettle();
    await t.tap(find.text('CONTINUE TO CALLS'));
    await t.pumpAndSettle();
    expect(c.working.caller, 2);
    expect(c.working.bids[2], c.rules.minCallerBid);
  });

  testWidgets('back from the calls hands the call back to the bid screen',
      (t) async {
    final c = await pumpEntry(t, Screen.bid);

    await t.tap(find.text('Karim'));
    await t.tap(find.text('♠'));
    await t.pumpAndSettle();
    await t.tap(find.text('CONTINUE TO CALLS'));
    await t.pumpAndSettle();
    expect(c.working.caller, 0);

    // Back is the way out, and the round goes back to asking who won the bid.
    await t.tap(find.text('BACK'));
    await t.pumpAndSettle();
    expect(c.working.caller, isNull);
    expect(find.text('WHO WON THE BID?'), findsOneWidget);
  });

  testWidgets('counting tricks: the pad enters each seat in turn, never past '
      '13, and fills the last one by itself', (t) async {
    final c = await pumpEntry(t, Screen.tricks);
    Future<void> press(int v) async {
      await t.tap(find.byKey(ValueKey('pad$v')));
      await t.pumpAndSettle();
    }

    // Seat 0 is up first and called 5: that key is its EXACT.
    expect(find.text('ENTER TRICKS ↓'), findsOneWidget);
    expect(find.text('EXACT'), findsOneWidget);
    await press(5);
    expect(c.working.tricks[0], 5);
    expect(find.text('✓ EXACT'), findsOneWidget);

    // Seat 1 called 4 and took one more.
    await press(5);
    expect(c.working.tricks[1], 5);
    expect(find.text('1 OVER'), findsOneWidget);

    // Ten are out: four more for seat 2 would make 14, so it is struck out.
    await press(4);
    expect(c.working.tricks[2], isNull);
    await press(3);
    expect(c.working.tricks[2], 3);

    // One seat left: it gets the 0 remaining by itself, marked AUTO.
    expect(c.working.tricks[3], 0);
    expect(find.text('AUTO'), findsOneWidget);
    expect(find.text('3 SHORT'), findsOneWidget);

    // No points on this screen: they wait for the scoresheet.
    expect(find.textContaining('+'), findsNothing);

    // Correcting seat 1 takes the automatic count back off, and it is
    // worked out again once seat 1 has its new number.
    await t.tap(find.text('Ali'));
    await t.pumpAndSettle();
    expect(c.working.tricks[3], isNull);
    await press(4);
    expect(c.working.tricks[1], 4);
    expect(c.working.tricks[3], 1);
    expect(find.text('AUTO'), findsOneWidget);

    // The round is scored by the engine, exactly as it would score it.
    final r = scoreRound(c.working.copy()..mult = c.currentMult, c.rules, c.s);
    await t.tap(find.text('SCORE ROUND'));
    await t.pumpAndSettle();
    expect(c.screen, Screen.result);
    expect(c.rounds.single.scores, r.scores);
  });

  testWidgets('the home wordmark fits, both languages', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1600, 720);
    t.view.devicePixelRatio = 2.0;
    addTearDown(t.view.reset);

    final c = GameController();
    // The whole app, so toggling the language actually rebuilds the shell.
    await t.pumpWidget(EstimationApp(controller: c));
    await t.pumpAndSettle();
    expect(find.text('ESTIMATION'), findsOneWidget);
    expect(find.text('CALCULATOR'), findsOneWidget);

    c.toggleLanguage();
    await t.pumpAndSettle();
    expect(find.text('حاسبة'), findsOneWidget);
  });

  testWidgets('the crown and the koz land on the right seats', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1600, 720);
    t.view.devicePixelRatio = 2.0;
    addTearDown(t.view.reset);

    final c = GameController()
      ..players = ['Karim', 'Ali', 'Sara', 'Omar']
      ..screen = Screen.bid
      // One round on the sheet: Sara out front, Omar propping it up.
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

    expect(c.laggardIndex, 3);
    expect(c.leaderIndex, 2);
    // Who won the bid? carries them beside the names.
    expect(find.image(const AssetImage('assets/crown.png')), findsOneWidget);
    expect(find.image(const AssetImage('assets/clown.png')), findsOneWidget);

    // Open the sheet from the header: it is the scoreboard's own sheet, and
    // the leader's and the last seat's totals are marked on it.
    await t.tap(find.byIcon(Icons.bar_chart_rounded));
    await t.pumpAndSettle();
    expect(find.byType(ScoreSheet), findsOneWidget);
    expect(find.text('30'), findsWidgets);
  });

  testWidgets('the end screen ranks the table and names the two rounds worth '
      'remembering', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1600, 720);
    t.view.devicePixelRatio = 2.0;
    addTearDown(t.view.reset);

    final c = GameController()
      ..players = ['Karim', 'Ali', 'Sara', 'Omar']
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

    expect(find.text('GAME OVER'), findsOneWidget);
    expect(find.text('Sara wins with 30 points'), findsOneWidget);

    // Three seats made their 3; Omar ate a fourth and did not.
    expect(find.text('made 1 of 1 calls'), findsNWidgets(3));
    expect(find.text('made 0 of 1 calls'), findsOneWidget);

    // The two rounds worth remembering, named with the seat that played them.
    expect(
      find.text('Biggest win: Sara ${signedPoints(30)}  \u00b7  '
          'Biggest loss: Omar ${signedPoints(-10)}'),
      findsOneWidget,
    );

    // Sara took it and Omar wears it: one crown, one clown, in the standings.
    expect(find.image(const AssetImage('assets/crown.png')), findsOneWidget);
    expect(find.image(const AssetImage('assets/clown.png')), findsOneWidget);
  });
  testWidgets('a table level all the way across crowns nobody', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1600, 720);
    t.view.devicePixelRatio = 2.0;
    addTearDown(t.view.reset);

    final c = GameController()
      ..players = ['Karim', 'Ali', 'Sara', 'Omar']
      ..screen = Screen.done
      ..rounds = [
        Round(
          bids: [3, 3, 3, 3],
          dash: List<bool>.filled(4, false),
          order: const [],
          tricks: [3, 3, 3, 4],
          scores: [10, 10, 10, 10],
        ),
      ];

    await t.pumpWidget(EstimationApp(controller: c));
    await t.pumpAndSettle();

    // Everyone shares the top, so it is said as a tie — no crown to hand out
    // and nobody singled out for the clown.
    expect(find.text('Karim & Ali & Sara & Omar tie at 10 points'),
        findsOneWidget);
    expect(find.image(const AssetImage('assets/crown.png')), findsNothing);
    expect(find.image(const AssetImage('assets/clown.png')), findsNothing);
  });
}
