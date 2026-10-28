import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:estimation/controller.dart';
import 'package:estimation/main.dart';
import 'package:estimation/models.dart';

/// Starts a game and lets the dash window come up, the way the app does it:
/// the round raises the flag, the next frame opens the dialog.
Future<GameController> startGame(WidgetTester t) async {
  SharedPreferences.setMockInitialValues({});
  t.view.physicalSize = const Size(1600, 720);
  t.view.devicePixelRatio = 2.0;
  addTearDown(t.view.reset);

  final c = GameController()..draftPlayers = ['Karim', 'Ali', 'Sara', 'Omar'];
  await t.pumpWidget(EstimationApp(controller: c));
  c.startGame();
  await t.pumpAndSettle();
  return c;
}

void main() {
  testWidgets('every round opens with the dash window', (t) async {
    await startGame(t);
    expect(find.text('WAIT FOR DASH!'), findsOneWidget);
    // Every seat is offered by name.
    for (final name in ['Karim', 'Ali', 'Sara', 'Omar']) {
      expect(find.text(name), findsWidgets);
    }
  });

  testWidgets('tapping a seat dashes it, and Done closes the window',
      (t) async {
    final c = await startGame(t);

    await t.tap(find.text('Sara').last);
    await t.pumpAndSettle();
    expect(c.working.dash[2], isTrue);

    await t.tap(find.text('DONE'));
    await t.pumpAndSettle();
    expect(find.text('WAIT FOR DASH!'), findsNothing);
    // The dash survives the window closing — the seat shows it on the sheet.
    expect(c.working.dash[2], isTrue);
  });

  testWidgets('no clock: the window waits until the table answers', (t) async {
    final c = await startGame(t);

    // A minute on, nobody has pressed anything, and it is still up.
    await t.pump(const Duration(minutes: 1));
    await t.pumpAndSettle();
    expect(find.text('WAIT FOR DASH!'), findsOneWidget);

    // A tap outside does not close it either.
    await t.tapAt(const Offset(5, 5));
    await t.pumpAndSettle();
    expect(find.text('WAIT FOR DASH!'), findsOneWidget);

    // With nobody dashed the button offers Skip.
    expect(find.text('DONE'), findsNothing);
    await t.tap(find.text('SKIP'));
    await t.pumpAndSettle();
    expect(find.text('WAIT FOR DASH!'), findsNothing);
    expect(c.working.dash.any((x) => x), isFalse);
  });

  testWidgets('the window honours the dash limit', (t) async {
    final c = await startGame(t);
    expect(c.rules.maxDash, 2);

    await t.tap(find.text('Karim').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Ali').last);
    await t.pumpAndSettle();
    // Two is the house maximum, so the third press does nothing.
    await t.tap(find.text('Sara').last);
    await t.pumpAndSettle();

    expect(c.working.dash, [true, true, false, false]);
  });

  testWidgets('color rounds open without the dash window', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1600, 720);
    t.view.devicePixelRatio = 2.0;
    addTearDown(t.view.reset);

    final c = GameController()
      ..draftPlayers = ['Karim', 'Ali', 'Sara', 'Omar']
      ..mode = GameMode.mini;

    await t.pumpWidget(EstimationApp(controller: c));
    c.startGame();
    // Mini is five normal rounds then five color ones; with five on the sheet,
    // the round about to open is a color round.
    c.rounds.addAll(List.generate(5, (_) => Round.empty(4)));
    c.continueAfterResult();
    await t.pumpAndSettle();

    expect(c.isColorRound, isTrue);
    expect(c.dashPromptPending, isFalse);
    expect(find.text('WAIT FOR DASH!'), findsNothing);
  });
}
