import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:estimation/controller.dart';
import 'package:estimation/main.dart';
import 'package:estimation/models.dart';
import 'package:estimation/screens.dart';
import 'package:estimation/theme.dart';
import 'package:estimation/widgets.dart';

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
  testWidgets('the call panel settles the caller, the trump and the number',
      (t) async {
    final c = await pumpEntry(t, Screen.bid);

    // The +/- pair is gone from the estimate screen, and so is the pad that
    // used to open off the number: a seat speaks through its buttons now.
    expect(find.text('+'), findsNothing);
    expect(find.text('−'), findsNothing);
    expect(find.text('Caller'), findsNWidgets(4));
    expect(find.text('Edit'), findsNWidgets(4));
    expect(find.text('Dash'), findsNWidgets(4));

    // Nothing can be fixed before the call is: Edit is held shut.
    await t.tap(find.text('Edit').first);
    await t.pumpAndSettle();
    expect(find.byType(CallPanel), findsNothing);

    // Seat 0 takes the call. The panel asks for the trump and the number
    // together, and neither reaches the round until Confirm.
    await t.tap(find.text('Caller').first);
    await t.pumpAndSettle();
    expect(find.byType(CallPanel), findsOneWidget);

    final inPanel = find.descendant(
      of: find.byType(CallPanel),
      matching: find.text('7'),
    );
    await t.tap(inPanel);
    await t.tap(find.descendant(
      of: find.byType(CallPanel),
      matching: find.text('♥'),
    ));
    await t.pumpAndSettle();
    expect(c.working.caller, isNull, reason: 'nothing lands before Confirm');

    await t.tap(find.text('CONFIRM'));
    await t.pumpAndSettle();
    expect(c.working.caller, 0);
    expect(c.working.trump, Suit.hearts);
    expect(c.working.bids[0], 7);

    // With the call down, the rest of the table can be filled in.
    await t.tap(find.text('Edit').at(1));
    await t.pumpAndSettle();
    expect(find.byType(CallPanel), findsOneWidget);
    await t.tap(find.descendant(
      of: find.byType(CallPanel),
      matching: find.text('3'),
    ));
    await t.pumpAndSettle();
    await t.tap(find.text('CONFIRM'));
    await t.pumpAndSettle();
    expect(c.working.bids[1], 3);
  });

  testWidgets('the call can be handed back from the panel that took it',
      (t) async {
    final c = await pumpEntry(t, Screen.bid);

    await t.tap(find.text('Caller').first);
    await t.pumpAndSettle();
    await t.tap(find.descendant(
      of: find.byType(CallPanel),
      matching: find.text('7'),
    ));
    await t.tap(find.descendant(
      of: find.byType(CallPanel),
      matching: find.text('♠'),
    ));
    await t.pumpAndSettle();
    await t.tap(find.text('CONFIRM'));
    await t.pumpAndSettle();
    expect(c.working.caller, 0);

    // Pressing Caller on the seat that holds it offers the way out.
    await t.tap(find.text('Caller').first);
    await t.pumpAndSettle();
    await t.tap(find.text('Clear the call'));
    await t.pumpAndSettle();
    expect(c.working.caller, isNull);
  });

  testWidgets('counting tricks: no steppers, and Got them fills the call',
      (t) async {
    final c = await pumpEntry(t, Screen.tricks);

    expect(find.text('+'), findsNothing);
    expect(find.text('−'), findsNothing);
    expect(find.text('Got them'), findsNWidgets(4));

    // Seat 0 called 5, so one press is five.
    await t.tap(find.text('Got them').first);
    await t.pumpAndSettle();
    expect(c.working.tricks[0], 5);
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
    expect(find.text('Estimation'), findsOneWidget);
    expect(find.text('Calculator'), findsOneWidget);

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
    // The sheet is folded away behind its tab, so only the seats wear them.
    expect(find.image(const AssetImage('assets/crown.png')), findsOneWidget);
    expect(find.image(const AssetImage('assets/koz.png')), findsOneWidget);

    // Pull the sheet down and the same two seats wear them again, over their
    // columns on the sheet.
    await t.tap(find.byType(ScoreTab));
    await t.pumpAndSettle();
    expect(find.image(const AssetImage('assets/crown.png')), findsNWidgets(2));
    expect(find.image(const AssetImage('assets/koz.png')), findsNWidgets(2));
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

    // Scoped to the screen: the sheet behind the tab carries the same names.
    final done = find.byType(DoneScreen);
    Finder on(String text) =>
        find.descendant(of: done, matching: find.text(text));

    expect(on('Game Result'), findsOneWidget);
    expect(on('Sara wins with 30 points'), findsOneWidget);

    // Standings run best to worst, with the middle places numbered.
    expect(on('2ND'), findsOneWidget);
    expect(on('3RD'), findsOneWidget);
    // Sara took it and Omar wears it, so neither is numbered.
    expect(on('1ST'), findsNothing);
    expect(on('4TH'), findsNothing);

    // Three seats made their 3; Omar ate a fourth and did not.
    expect(on('1W · 0L'), findsNWidgets(3));
    expect(on('0W · 1L'), findsOneWidget);

    // Each of the two turns up twice: once in the standings, once as the
    // round it took.
    expect(on('Sara'), findsNWidgets(2));
    expect(on('Omar'), findsNWidgets(2));
    expect(on('Biggest win'), findsOneWidget);
    expect(on('+30'), findsOneWidget);
    expect(on('Biggest loss'), findsOneWidget);

    // The sheet is folded away behind its tab, so the standings rows are the
    // only place either one is worn.
    expect(find.image(const AssetImage('assets/crown.png')), findsOneWidget);
    expect(find.image(const AssetImage('assets/koz.png')), findsOneWidget);
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

    final done = find.byType(DoneScreen);
    Finder on(String text) =>
        find.descendant(of: done, matching: find.text(text));

    // Everyone shares the top, so it is said as a tie and every seat is
    // numbered — no crown to hand out and nobody singled out for the koz.
    expect(on('Karim & Ali & Sara & Omar tie at 10 points'), findsOneWidget);
    expect(on('1ST'), findsOneWidget);
    expect(on('4TH'), findsOneWidget);
    expect(find.image(const AssetImage('assets/crown.png')), findsNothing);
    expect(find.image(const AssetImage('assets/koz.png')), findsNothing);
  });
}
