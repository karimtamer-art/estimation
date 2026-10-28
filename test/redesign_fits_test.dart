import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:estimation/controller.dart';
import 'package:estimation/main.dart';
import 'package:estimation/models.dart';

/// Every redesigned screen, at every size it is played on, in both
/// languages: nothing may overflow. A narrow desktop window is in the list
/// because that is where the avatar picker first broke.
const _sizes = <String, Size>{
  'pixel 7': Size(892, 412),
  'iphone 14 pro': Size(852, 393),
  'small': Size(740, 360),
  'short': Size(640, 300),
  'narrow window': Size(940, 520),
  'tablet': Size(1280, 800),
};

GameController _table(Screen screen) {
  final c = GameController()
    ..draftPlayers = ['Abdelrahman', 'Karim', 'Youssef', 'Ali'];
  if (screen == Screen.home ||
      screen == Screen.setup ||
      screen == Screen.setupPlayers ||
      screen == Screen.settings) {
    return c..screen = screen;
  }
  c.startGame();
  c.dashPromptPending = false;
  if (screen == Screen.bid) return c;
  c.applyCall(0, Suit.hearts, 5);
  c.setValue(1, 4);
  c.setValue(2, 2);
  c.setValue(3, 1);
  c.toTricks();
  if (screen == Screen.tricks) return c;
  c.madeBid(0);
  c.madeBid(1);
  c.madeBid(2);
  c.setValue(3, 2);
  c.commit();
  if (screen == Screen.done) {
    c.screen = Screen.done;
  }
  return c;
}

void main() {
  const screens = [
    Screen.home,
    Screen.setup,
    Screen.setupPlayers,
    Screen.bid,
    Screen.tricks,
    Screen.result,
    Screen.done,
    Screen.settings,
  ];
  _sizes.forEach((name, size) {
    for (final screen in screens) {
      for (final ar in [false, true]) {
        testWidgets('$name: ${screen.name}${ar ? ' (Arabic)' : ''} fits',
            (t) async {
          SharedPreferences.setMockInitialValues({});
          t.view.physicalSize = size * 2;
          t.view.devicePixelRatio = 2.0;
          addTearDown(t.view.reset);

          final c = _table(screen)..arabic = ar;
          await t.pumpWidget(EstimationApp(controller: c));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        });
      }
    }
  });

  testWidgets('the calls screen fits with the call settled', (t) async {
    for (final size in _sizes.values) {
      SharedPreferences.setMockInitialValues({});
      t.view.physicalSize = size * 2;
      t.view.devicePixelRatio = 2.0;
      final c = _table(Screen.bid)..applyCall(0, Suit.spades, 6);
      await t.pumpWidget(EstimationApp(controller: c));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: '$size');
    }
    t.view.reset();
  });
}
