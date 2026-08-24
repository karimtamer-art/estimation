import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:estimation/controller.dart';
import 'package:estimation/main.dart';
import 'package:estimation/models.dart';
import 'package:estimation/widgets.dart';

/// Starts a game and lets the dash window come up, the way the app does it:
/// the round raises the flag, the next frame opens the dialog.
Future<GameController> startGame(WidgetTester t) async {
  SharedPreferences.setMockInitialValues({});
  t.view.physicalSize = const Size(1600, 720);
  t.view.devicePixelRatio = 2.0;
  addTearDown(t.view.reset);

  final c = GameController()..players = ['Karim', 'Ali', 'Sara', 'Omar'];
  await t.pumpWidget(EstimationApp(controller: c));
  c.startGame();
  await t.pumpAndSettle();
  return c;
}

void main() {
  testWidgets('every round opens with the dash window', (t) async {
    await startGame(t);
    expect(find.text('Wait for dash'), findsOneWidget);
    expect(find.text('$kDashWindowSeconds'), findsOneWidget);
    // Every seat is offered by name.
    for (final name in ['Karim', 'Ali', 'Sara', 'Omar']) {
      expect(find.text(name), findsWidgets);
    }
    await t.pump(const Duration(seconds: kDashWindowSeconds + 1));
    await t.pumpAndSettle();
  });

  testWidgets('tapping a seat dashes it, and Done closes the window',
      (t) async {
    final c = await startGame(t);

    await t.tap(find.widgetWithText(InkWell, 'Sara').last);
    await t.pumpAndSettle();
    expect(c.working.dash[2], isTrue);

    await t.tap(find.text('Done'));
    await t.pumpAndSettle();
    expect(find.text('Wait for dash'), findsNothing);
    // The dash survives the window closing — the seat shows it on the sheet.
    expect(c.working.dash[2], isTrue);
  });

  testWidgets('the countdown ticks and closes the window on its own',
      (t) async {
    await startGame(t);

    await t.pump(const Duration(seconds: 1));
    expect(find.text('${kDashWindowSeconds - 1}'), findsOneWidget);

    await t.pump(const Duration(seconds: kDashWindowSeconds - 1));
    await t.pumpAndSettle();
    expect(find.text('Wait for dash'), findsNothing);
  });

  testWidgets('the window honours the dash limit', (t) async {
    final c = await startGame(t);
    expect(c.rules.maxDash, 2);

    await t.tap(find.widgetWithText(InkWell, 'Karim').last);
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(InkWell, 'Ali').last);
    await t.pumpAndSettle();
    // Two is the house maximum, so the third press does nothing.
    await t.tap(find.widgetWithText(InkWell, 'Sara').last);
    await t.pumpAndSettle();

    expect(c.working.dash, [true, true, false, false]);

    await t.pump(const Duration(seconds: kDashWindowSeconds + 1));
    await t.pumpAndSettle();
  });

  testWidgets('color rounds open without the dash window', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1600, 720);
    t.view.devicePixelRatio = 2.0;
    addTearDown(t.view.reset);

    // Mini is five normal rounds then five color ones; with five played, the
    // round about to open is a color round.
    final c = GameController()
      ..players = ['Karim', 'Ali', 'Sara', 'Omar']
      ..mode = GameMode.mini
      ..rounds = List.generate(5, (_) => Round.empty(4));

    await t.pumpWidget(EstimationApp(controller: c));
    c.startGame();
    await t.pumpAndSettle();

    expect(c.isColorRound, isTrue);
    expect(c.dashPromptPending, isFalse);
    expect(find.text('Wait for dash'), findsNothing);
  });
}
