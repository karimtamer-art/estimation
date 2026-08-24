import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:estimation/controller.dart';
import 'package:estimation/main.dart';
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

  testWidgets('counting tricks keeps its steppers', (t) async {
    await pumpEntry(t, Screen.tricks);
    expect(find.text('+'), findsNWidgets(4));
    expect(find.text('−'), findsNWidgets(4));
  });
}
