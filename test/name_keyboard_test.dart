import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:estimation/controller.dart';
import 'package:estimation/main.dart';

/// The name boxes are one line each: Return moves on to the next seat, the
/// last seat's Return and any tap elsewhere put the keyboard away.
void main() {
  Future<GameController> show(WidgetTester t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1280, 620) * 2;
    t.view.devicePixelRatio = 2.0;
    addTearDown(t.view.reset);
    final c = GameController()
      ..toSetup()
      ..toPlayers();
    await t.pumpWidget(EstimationApp(controller: c));
    await t.pumpAndSettle();
    return c;
  }

  EditableText field(WidgetTester t, int i) =>
      t.widget<EditableText>(find.byType(EditableText).at(i));

  testWidgets('Return moves to the next name, then closes', (t) async {
    final c = await show(t);
    await t.tap(find.byType(TextFormField).at(0));
    await t.pump();
    await t.enterText(find.byType(TextFormField).at(0), 'Karim');
    await t.testTextInput.receiveAction(TextInputAction.next);
    await t.pumpAndSettle();
    expect(c.draftPlayers[0], 'Karim');
    expect(field(t, 1).focusNode.hasFocus, isTrue);

    await t.tap(find.byType(TextFormField).at(3));
    await t.pump();
    expect(field(t, 3).textInputAction, TextInputAction.done);
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(field(t, 3).focusNode.hasFocus, isFalse);
  });

  testWidgets('a name never takes a second line', (t) async {
    await show(t);
    for (var i = 0; i < 4; i++) {
      expect(field(t, i).maxLines, 1);
    }
  });

  testWidgets('a tap outside the box puts the keyboard away', (t) async {
    await show(t);
    await t.tap(find.byType(TextFormField).at(0));
    await t.pump();
    expect(field(t, 0).focusNode.hasFocus, isTrue);
    await t.tapAt(const Offset(640, 20));
    await t.pumpAndSettle();
    expect(field(t, 0).focusNode.hasFocus, isFalse);
  });
}
