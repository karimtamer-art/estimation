import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:estimation/controller.dart';
import 'package:estimation/main.dart';
import 'package:estimation/models.dart';
import 'package:estimation/rules.dart';

/// "All equal → double + re-estimate" is a house rule a table has to ask for.
/// When it does fire, the table is told why and what to do with the cards.
void main() {
  test('the rule is off by default', () {
    expect(Rules.defaults().houseAllEqualDouble, isFalse);
  });

  test('a table saved under the old default comes back with it off',
      () async {
    final rules = Rules.defaults().toJson()
      ..remove('houseAllEqualDoubleOptIn')
      ..['houseAllEqualDouble'] = true;
    SharedPreferences.setMockInitialValues({
      'estimation_state_v1': jsonEncode({'rules': rules}),
    });
    final c = GameController();
    await c.load();
    expect(c.rules.houseAllEqualDouble, isFalse);
  });

  test('a table that switches it on keeps it on', () {
    final r = Rules.defaults()..houseAllEqualDouble = true;
    expect(Rules.fromJson(r.toJson()).houseAllEqualDouble, isTrue);
  });

  test('off, four matching calls in a Color round are simply played', () {
    final c = GameController()
      ..draftPlayers = ['A', 'B', 'C', 'D']
      ..mode = GameMode.mini;
    c.startGame();
    c.rounds.addAll(List.generate(5, (_) => Round.empty(4)));
    c.continueAfterResult();
    expect(c.isColorRound, isTrue);
    for (var i = 0; i < 4; i++) {
      c.setValue(i, 4);
    }
    expect(c.allEqualEstimates, isFalse);
    expect(c.validationError, isNull);
  });

  test('a Color round has no minimum: four 3s are played', () {
    final c = GameController()
      ..draftPlayers = ['A', 'B', 'C', 'D']
      ..mode = GameMode.mini;
    c.startGame();
    c.rounds.addAll(List.generate(5, (_) => Round.empty(4)));
    c.continueAfterResult();
    for (var i = 0; i < 4; i++) {
      c.setValue(i, 3);
    }
    expect(c.validationError, isNull);
  });

  test('a normal round still needs its caller at 4 or more', () {
    final c = GameController()..draftPlayers = ['A', 'B', 'C', 'D'];
    c.startGame();
    c.dashPromptPending = false;
    expect(c.isColorRound, isFalse);
    expect(c.canPick(0, 3, asCaller: true), isFalse);
    expect(c.canPick(0, 4, asCaller: true), isTrue);
  });

  test('switched on, it never stops a normal round', () {
    final c = GameController()..draftPlayers = ['A', 'B', 'C', 'D'];
    c.rules.houseAllEqualDouble = true;
    c.startGame();
    c.dashPromptPending = false;
    c.applyCall(0, Suit.hearts, 4);
    for (var i = 1; i < 4; i++) {
      c.setValue(i, 4);
    }
    expect(c.isColorRound, isFalse);
    expect(c.allEqualEstimates, isFalse);
    expect(c.validationError, isNot(c.s.errAllEqual));
  });

  group('switched on', () {
    Future<GameController> colorRound(WidgetTester t) async {
      SharedPreferences.setMockInitialValues({});
      t.view.physicalSize = const Size(1280, 620) * 2;
      t.view.devicePixelRatio = 2.0;
      addTearDown(t.view.reset);
      final c = GameController()
        ..draftPlayers = ['Karim', 'Omar', 'Youssef', 'Nour']
        ..mode = GameMode.mini
        ..seenScoreHint = true;
      c.rules.houseAllEqualDouble = true;
      c.startGame();
      c.rounds.addAll(List.generate(5, (_) => Round.empty(4)));
      c.continueAfterResult();
      c.dashPromptPending = false;
      for (var i = 0; i < 3; i++) {
        c.setValue(i, 4);
      }
      await t.pumpWidget(EstimationApp(controller: c));
      await t.pumpAndSettle();
      return c;
    }

    // The last seat locks in its 4 on screen.
    Future<void> lockLast(WidgetTester t) async {
      await t.tap(find.byKey(const ValueKey('pad4')));
      await t.pumpAndSettle();
    }

    testWidgets('the last matching call explains it, and dealing doubles it',
        (t) async {
      final c = await colorRound(t);
      await lockLast(t);
      expect(c.allEqualEstimates, isTrue);
      expect(find.text('EVERYONE CALLED 4'), findsOneWidget);
      expect(find.text('Collect the cards, reshuffle and deal a new hand.'),
          findsOneWidget);

      await t.tap(find.text('DEALT AGAIN — CALL'));
      await t.pumpAndSettle();
      // Four 4s also shared the top call (×2 on their own); that goes with
      // the calls, and the dealt-again hand carries the house ×2 alone.
      expect(find.byType(Dialog), findsNothing);
      expect(c.working.houseMult, 2);
      expect(c.currentMult, 2);
      expect(c.working.bids.every((b) => b == null), isTrue);
    });

    testWidgets('back leaves the calls as they are', (t) async {
      final c = await colorRound(t);
      final before = c.currentMult;
      await lockLast(t);
      await t.tap(find.text('BACK').last);
      await t.pumpAndSettle();
      expect(find.text('EVERYONE CALLED 4'), findsNothing);
      expect(c.currentMult, before);
      expect(c.allEqualEstimates, isTrue);

      // The footer button brings the explanation back.
      await t.tap(find.text('WHY? RESHUFFLE'));
      await t.pumpAndSettle();
      expect(find.text('EVERYONE CALLED 4'), findsOneWidget);
    });
  });
}
