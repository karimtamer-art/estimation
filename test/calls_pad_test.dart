import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:estimation/controller.dart';
import 'package:estimation/main.dart';
import 'package:estimation/models.dart';

/// One scorekeeper enters every call on a shared pad, seat by seat, in the
/// order the table calls.
void main() {
  GameController normal() {
    final c = GameController()
      ..draftPlayers = ['Karim', 'Omar', 'Youssef', 'Nour']
      ..seenScoreHint = true;
    c.startGame();
    c.dashPromptPending = false;
    return c;
  }

  GameController color({int round = 0}) {
    final c = GameController()
      ..draftPlayers = ['Karim', 'Omar', 'Youssef', 'Nour']
      ..mode = GameMode.mini
      ..seenScoreHint = true;
    c.startGame();
    c.rounds.addAll(List.generate(5 + round, (_) => Round.empty(4)));
    c.continueAfterResult();
    c.dashPromptPending = false;
    return c;
  }

  Future<void> show(WidgetTester t, GameController c) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1280, 620) * 2;
    t.view.devicePixelRatio = 2.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(EstimationApp(controller: c));
    await t.pumpAndSettle();
  }

  Future<void> press(WidgetTester t, int v) async {
    await t.tap(find.byKey(ValueKey('pad$v')));
    await t.pumpAndSettle();
  }

  group('calling order', () {
    test('the seat after a seat is the one to its right, round the table',
        () {
      final c = normal();
      expect([for (var i = 0; i < 4; i++) c.seatAfter(i)], [1, 2, 3, 0]);
    });

    test('a normal round starts after the bid winner and leaves it out', () {
      final c = normal()..applyCall(2, Suit.spades, 5);
      expect(c.callingOrder, [3, 0, 1]);
    });

    test('a dashed seat is skipped', () {
      final c = normal()..toggleDash(0);
      c.applyCall(2, Suit.spades, 5);
      expect(c.callingOrder, [3, 1]);
    });

    test('a Color round takes every seat, from a starter that moves on', () {
      expect(color().callingOrder, [1, 2, 3, 0]);
      expect(color(round: 1).callingOrder, [2, 3, 0, 1]);
    });
  });

  group('the pad', () {
    testWidgets('each number saves the active seat and moves to the next',
        (t) async {
      final c = normal()..applyCall(0, Suit.hearts, 5);
      await show(t, c);
      expect(find.text('BID'), findsOneWidget);
      expect(find.text('1ST'), findsOneWidget);

      await press(t, 2);
      expect(c.working.bids[1], 2);
      await press(t, 4);
      expect(c.working.bids[2], 4);
      expect(find.text('PLAY THE HAND'), findsOneWidget);
      expect(c.bidsComplete, isFalse);

      // 5 + 2 + 4 = 11: a 2 for the last seat would make exactly 13.
      await press(t, 2);
      expect(c.working.bids[3], isNull);
      await press(t, 1);
      expect(c.working.bids[3], 1);
      expect(c.bidsComplete, isTrue);
      expect(c.validationError, isNull);
    });

    testWidgets('numbers over the bid winner are blocked', (t) async {
      final c = normal()..applyCall(0, Suit.hearts, 5);
      await show(t, c);
      await press(t, 6);
      expect(c.working.bids[1], isNull);
      await press(t, 5);
      expect(c.working.bids[1], 5);
    });

    testWidgets('tapping a seat that has called opens it again', (t) async {
      final c = normal()..applyCall(0, Suit.hearts, 5);
      await show(t, c);
      await press(t, 2);
      await press(t, 3);
      await t.tap(find.text('Omar'));
      await t.pumpAndSettle();
      await press(t, 1);
      expect(c.working.bids[1], 1);
      // Then the pad goes back to the seat still waiting.
      await press(t, 0);
      expect(c.working.bids[3], 0);
    });

    testWidgets('the bid winner\'s own number cannot be reopened', (t) async {
      final c = normal()..applyCall(0, Suit.hearts, 5);
      await show(t, c);
      await t.tap(find.text('Karim'));
      await t.pumpAndSettle();
      await press(t, 2);
      expect(c.working.bids[0], 5);
      expect(c.working.bids[1], 2);
    });

    testWidgets('in a Color round the highest call takes the call, first wins '
        'a tie', (t) async {
      final c = color();
      await show(t, c);
      await press(t, 3); // seat 1
      expect(c.working.caller, 1);
      await press(t, 5); // seat 2 goes over
      expect(c.working.caller, 2);
      await press(t, 5); // seat 3 matches: With, not the call
      expect(c.working.caller, 2);
    });
  });
}
