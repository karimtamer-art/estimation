import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:estimation/controller.dart';
import 'package:estimation/main.dart';
import 'package:estimation/models.dart';
import 'package:estimation/ui/components.dart';
import 'package:estimation/widgets.dart';

GameController table({
  GameMode mode = GameMode.full,
  int roundsPlayed = 0,
  List<String>? names,
}) {
  final c = GameController()
    ..players = names ?? ['Karim', 'Akram', 'Ahmed', 'Youssef']
    ..mode = mode
    ..screen = Screen.bid
    ..rounds = List.generate(roundsPlayed, (_) => Round.empty(4));
  c.working = Round.empty(4);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('the call follows the highest estimate', () {
    test('a seat coming over the top takes the call and carries the Risk', () {
      // The table as it is actually played: Karim opens, Akram lifts it,
      // Ahmed drops out low, and Youssef comes over everyone last.
      final c = table();
      c.applyCall(0, Suit.hearts, 3); // Karim presses Caller on 3
      expect(c.working.caller, 0);

      c.setValue(1, 4); // Akram is now above him
      expect(c.working.caller, 1);

      c.setValue(2, 2); // Ahmed is under the call and changes nothing
      expect(c.working.caller, 1);

      c.setValue(3, 6); // Youssef takes it, last to settle
      expect(c.working.caller, 3);

      // Both land on Youssef: the call because it is the highest, the Risk
      // because he was the one left settling the table away from 13.
      final d = c.derived;
      expect(d.top, 6);
      expect(d.callerOrWith, [false, false, false, true]);
      expect(d.riskIndex, 3);
      expect(d.total, 15);
      expect(d.riskLevel, 1);
      // Nothing is left complaining about who holds the call.
      expect(c.validationError, isNull);
    });

    test('a seat matching the top is With, and does not take the call', () {
      final c = table();
      c.applyCall(0, Suit.spades, 5);
      c.setValue(1, 5);
      // Seat 0 said it first, so it keeps the call and seat 1 is With.
      expect(c.working.caller, 0);
      expect(c.derived.callerOrWith, [true, true, false, false]);
    });

    test('a caller that edits back down loses the call', () {
      final c = table();
      c.applyCall(0, Suit.clubs, 6);
      c.setValue(1, 4);
      expect(c.working.caller, 0);

      c.setValue(0, 2); // thinks better of it
      expect(c.working.caller, 1);
      expect(c.derived.top, 4);
    });

    test('dashing out of the call hands it to the next highest', () {
      final c = table();
      c.applyCall(0, Suit.sun, 6);
      c.setValue(1, 4);
      c.setValue(2, 3);

      c.toggleDash(0);
      expect(c.working.caller, 1);
      expect(c.derived.top, 4);
    });

    test('the trump stays where the table put it when the call moves', () {
      // The suit row is still on screen for the new caller to change; the
      // round does not throw away a trump nobody asked it to.
      final c = table();
      c.applyCall(0, Suit.diamonds, 5);
      c.setValue(1, 7);
      expect(c.working.caller, 1);
      expect(c.working.trump, Suit.diamonds);
    });
  });

  group('the color rounds say what they are', () {
    test('Mini runs sun, spades, hearts, diamonds, clubs after five rounds',
        () {
      const want = [
        Suit.sun,
        Suit.spades,
        Suit.hearts,
        Suit.diamonds,
        Suit.clubs,
      ];
      for (var i = 0; i < 5; i++) {
        final c = table(mode: GameMode.mini, roundsPlayed: 5 + i);
        expect(c.isColorRound, isTrue, reason: 'round ${6 + i}');
        expect(c.lockedTrump, want[i], reason: 'round ${6 + i}');
        expect(c.colorRoundNumber, i + 1);
      }
    });

    test('the five rounds before them are the caller\'s to pick', () {
      for (var i = 0; i < 5; i++) {
        final c = table(mode: GameMode.mini, roundsPlayed: i);
        expect(c.isColorRound, isFalse, reason: 'round ${i + 1}');
        expect(c.lockedTrump, isNull);
        expect(c.colorRoundNumber, 0);
      }
    });

    testWidgets('a color round shows its forced trump before anyone estimates',
        (t) async {
      t.view.physicalSize = const Size(1600, 720);
      t.view.devicePixelRatio = 2.0;
      addTearDown(t.view.reset);

      // Mini, six rounds in: the second color round, played under spades.
      final c = table(mode: GameMode.mini, roundsPlayed: 6);
      await t.pumpWidget(EstimationApp(controller: c));
      await t.pumpAndSettle();

      expect(c.lockedTrump, Suit.spades);
      final plaque = find.byType(Plaque).first;
      expect(find.descendant(of: plaque, matching: find.text('♠')),
          findsOneWidget);
      expect(find.descendant(of: plaque, matching: find.text('SPADES')),
          findsOneWidget);
      expect(find.text('COLOR 2 OF 5'), findsOneWidget);
      // It is up before the table has done anything at all, and the table is
      // free to estimate straight away — nothing is settled first here.
      expect(c.bidStep, BidStep.table);
      expect(c.canEstimate(0), isTrue);
    });

    testWidgets('a normal round leaves the banner off until a trump is picked',
        (t) async {
      t.view.physicalSize = const Size(1600, 720);
      t.view.devicePixelRatio = 2.0;
      addTearDown(t.view.reset);

      final c = table(mode: GameMode.mini, roundsPlayed: 2);
      await t.pumpWidget(EstimationApp(controller: c));
      await t.pumpAndSettle();

      // Nothing is forced here, so the suit row does the talking instead.
      expect(find.byType(TrumpBanner), findsNothing);
      expect(c.lockedTrump, isNull);
    });

    testWidgets('the trump is still on screen while the tricks come in',
        (t) async {
      t.view.physicalSize = const Size(1600, 720);
      t.view.devicePixelRatio = 2.0;
      addTearDown(t.view.reset);

      final c = table(mode: GameMode.mini, roundsPlayed: 2)
        ..screen = Screen.tricks;
      c.working = Round(
        bids: <int?>[5, 4, 3, 2],
        dash: List<bool>.filled(4, false),
        order: const [0, 1, 2, 3],
        tricks: List<int?>.filled(4, null),
        caller: 0,
        trump: Suit.hearts,
      );

      await t.pumpWidget(EstimationApp(controller: c));
      await t.pumpAndSettle();

      // The suit row is gone by now, so the header's plaque is where it reads.
      final plaque = find.byType(Plaque).first;
      expect(find.descendant(of: plaque, matching: find.text('♥')),
          findsOneWidget);
      expect(find.descendant(of: plaque, matching: find.text('HEARTS')),
          findsOneWidget);
    });
  });

  group('a color round is not called and cannot be dashed', () {
    test('the dash button is refused outright', () {
      final c = table(mode: GameMode.mini, roundsPlayed: 5);
      c.toggleDash(0);
      expect(c.working.dash[0], isFalse);
      expect(c.working.bids[0], isNull);
    });

    test('the dash window never opens on one', () {
      // Finish the fifth round, which is the last one the caller picks a
      // trump for. The sixth is the first colour, and it opens without a
      // window because there is nothing to declare.
      final c = table(mode: GameMode.mini, roundsPlayed: 4);
      c.working = Round(
        bids: <int?>[5, 4, 3, 2],
        dash: List<bool>.filled(4, false),
        order: const [0, 1, 2, 3],
        tricks: <int?>[5, 4, 3, 1],
        caller: 0,
        trump: Suit.hearts,
      );
      c.commit();
      c.continueAfterResult();

      expect(c.isColorRound, isTrue);
      expect(c.dashPromptPending, isFalse);
    });

    test('the highest estimate takes the call with nobody pressing it', () {
      final c = table(mode: GameMode.mini, roundsPlayed: 5);
      c.setValue(0, 3);
      c.setValue(1, 4);
      c.setValue(2, 2);
      c.setValue(3, 6);
      expect(c.working.caller, 3);
      expect(c.derived.callerOrWith, [false, false, false, true]);
      expect(c.validationError, isNull);
    });

    testWidgets('every seat calls for itself, with no call or dash to press',
        (t) async {
      t.view.physicalSize = const Size(1600, 720);
      t.view.devicePixelRatio = 2.0;
      addTearDown(t.view.reset);

      final c = table(mode: GameMode.mini, roundsPlayed: 5);
      await t.pumpWidget(EstimationApp(controller: c));
      await t.pumpAndSettle();

      // Every seat takes a turn on the pad, from this round's starter.
      for (final turn in ['1ST', '2ND', '3RD', '4TH']) {
        expect(find.text(turn), findsOneWidget);
      }
      expect(find.text('LOCK IN'), findsNothing);
      expect(find.text('CALL'), findsNothing);
      expect(find.text('DASH'), findsNothing);
      expect(find.text('EDIT DASH'), findsNothing);
    });

    testWidgets('a super call asks for the trump as it is locked in',
        (t) async {
      t.view.physicalSize = const Size(1600, 720);
      t.view.devicePixelRatio = 2.0;
      addTearDown(t.view.reset);

      // The first color round: sun, until somebody takes it off the round.
      final c = table(mode: GameMode.mini, roundsPlayed: 5);
      await t.pumpWidget(EstimationApp(controller: c));
      await t.pumpAndSettle();
      expect(c.lockedTrump, Suit.sun);

      final first = c.callingOrder.first;

      // Seven is not a super call: it lands under the round's own trump.
      await t.tap(find.byKey(const ValueKey('pad7')));
      await t.pumpAndSettle();
      expect(find.text('SUPER CALL — PICK THE TRUMP'), findsNothing);
      expect(c.working.bids[first], 7);
      expect(c.lockedTrump, Suit.sun);

      // Eight is, so the same seat changing to it is asked which suit takes
      // the round.
      await t.tap(find.text(c.players[first]));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('pad8')));
      await t.pumpAndSettle();
      expect(find.text('SUPER CALL — PICK THE TRUMP'), findsOneWidget);
      await t.tap(find.text('♥'));
      await t.pumpAndSettle();

      // The number and the trump land together, and the round is no longer
      // holding a colour of its own.
      expect(c.working.bids[first], 8);
      expect(c.working.trump, Suit.hearts);
      expect(c.superCalled, isTrue);
      expect(c.lockedTrump, isNull);
    });

    testWidgets('dropping back under eight hands the colour back', (t) async {
      t.view.physicalSize = const Size(1600, 720);
      t.view.devicePixelRatio = 2.0;
      addTearDown(t.view.reset);

      final c = table(mode: GameMode.mini, roundsPlayed: 5);
      await t.pumpWidget(EstimationApp(controller: c));
      await t.pumpAndSettle();

      c.setValue(0, 8, trump: Suit.hearts);
      expect(c.lockedTrump, isNull);

      c.setValue(0, 5);
      expect(c.superCalled, isFalse);
      expect(c.lockedTrump, Suit.sun);
    });
  });
}
