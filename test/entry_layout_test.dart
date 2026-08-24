import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:estimation/controller.dart';
import 'package:estimation/main.dart';
import 'package:estimation/models.dart';
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
  await t.pumpWidget(MaterialApp(theme: buildTheme(), home: HomeShell(c: c)));
  await t.pumpAndSettle();
  return c;
}

void main() {
  testWidgets('estimating: no steppers, and the number opens the pad',
      (t) async {
    final c = await pumpEntry(t, Screen.bid);

    // The +/- pair is gone from the estimate screen.
    expect(find.text('+'), findsNothing);
    expect(find.text('−'), findsNothing);

    // Every seat offers Caller, and the pad opens off the number itself.
    expect(find.text('Caller'), findsNWidgets(4));
    await t.tap(find.text('·').first);
    await t.pumpAndSettle();
    expect(find.text('13'), findsWidgets);

    await t.tap(find.text('7').first);
    await t.pumpAndSettle();
    expect(c.working.bids[0], 7);
  });

  testWidgets('pressing Caller marks the seat and holds the top', (t) async {
    final c = await pumpEntry(t, Screen.bid);

    await t.tap(find.text('Caller').first);
    await t.pumpAndSettle();
    expect(c.working.caller, 0);

    // Pressing it again hands the call back to the estimates.
    await t.tap(find.text('Caller').first);
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
    // Once on the seat itself, once over that seat's column on the sheet.
    expect(find.image(const AssetImage('assets/crown.png')), findsNWidgets(2));
    expect(find.image(const AssetImage('assets/koz.png')), findsNWidgets(2));
  });

  testWidgets('game over crowns the winner and kozzes the loser', (t) async {
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

    // Sara took it, Omar wears it.
    expect(find.text('Sara'), findsOneWidget);
    expect(find.text('wins with 30 points'), findsOneWidget);
    expect(find.text('Omar'), findsOneWidget);
    expect(find.text('loses with -10 points'), findsOneWidget);
    // Once in its panel, once over its column on the sheet below.
    expect(find.image(const AssetImage('assets/crown.png')), findsNWidgets(2));
    expect(find.image(const AssetImage('assets/koz.png')), findsNWidgets(2));
  });

  testWidgets('a table level all the way across gets no koz', (t) async {
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

    // Everyone shares the crown; nobody is singled out for the koz.
    expect(find.image(const AssetImage('assets/crown.png')), findsOneWidget);
    expect(find.image(const AssetImage('assets/koz.png')), findsNothing);
  });
}
