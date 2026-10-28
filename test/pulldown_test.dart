import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:estimation/controller.dart';
import 'package:estimation/main.dart';
import 'package:estimation/ui/components.dart';

/// The round tile in the header pulls the scoresheet down and pushes it back
/// up; each seat wears a face of its own.
void main() {
  Future<GameController> round(WidgetTester t, {bool seen = false}) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1280, 620) * 2;
    t.view.devicePixelRatio = 2.0;
    addTearDown(t.view.reset);
    final c = GameController()
      ..draftPlayers = ['Karim', 'Omar', 'Youssef', 'Nour']
      ..seenScoreHint = seen;
    c.startGame();
    c.dashPromptPending = false;
    await t.pumpWidget(EstimationApp(controller: c));
    await t.pumpAndSettle();
    return c;
  }

  // Shut, the header tile is the only one; open, the one riding the sheet is
  // drawn last.
  final tile = find.byType(RoundTile).last;
  final empty = find.text('Scores appear after the first round');
  final tip = find.text('Pull the round down for scores');

  testWidgets('the tile sits in the header, start side, with its "of N"',
      (t) async {
    await round(t);
    expect(find.byType(RoundTile), findsOneWidget);
    expect(t.getTopLeft(find.byType(RoundTile)).dx, lessThan(80));
    expect(find.text('of 18'), findsOneWidget);
  });

  testWidgets('a tap on the tile opens the sheet, another shuts it',
      (t) async {
    await round(t);
    expect(empty, findsNothing);

    await t.tap(tile);
    await t.pumpAndSettle();
    expect(empty, findsOneWidget);

    await t.tap(tile);
    await t.pumpAndSettle();
    expect(empty, findsNothing);
    // Shut, the tile is back in its slot alone.
    expect(find.byType(RoundTile), findsOneWidget);
  });

  testWidgets('a tap on the backdrop shuts it', (t) async {
    await round(t);
    await t.tap(tile);
    await t.pumpAndSettle();
    await t.tapAt(const Offset(640, 600));
    await t.pumpAndSettle();
    expect(empty, findsNothing);
  });

  testWidgets('a short drag springs back; a long one or a fling opens it',
      (t) async {
    await round(t);
    await t.drag(tile, const Offset(0, 60));
    await t.pumpAndSettle();
    expect(empty, findsNothing);

    await t.drag(tile, const Offset(0, 300));
    await t.pumpAndSettle();
    expect(empty, findsOneWidget);

    // An upward fling on the sheet puts it away.
    await t.fling(empty, const Offset(0, -120), 1500);
    await t.pumpAndSettle();
    expect(empty, findsNothing);

    await t.fling(tile, const Offset(0, 60), 1500);
    await t.pumpAndSettle();
    expect(empty, findsOneWidget);
  });

  testWidgets('back shuts the sheet before it leaves the round', (t) async {
    final c = await round(t);
    await t.tap(tile);
    await t.pumpAndSettle();
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(empty, findsNothing);
    expect(c.screen, Screen.bid);
  });

  testWidgets('the tip shows until the sheet is first opened', (t) async {
    final c = await round(t);
    expect(tip, findsOneWidget);
    await t.tap(tile);
    await t.pumpAndSettle();
    await t.tap(tile);
    await t.pumpAndSettle();
    expect(c.seenScoreHint, isTrue);
    expect(tip, findsNothing);
  });

  testWidgets('a tap on the tip puts it away', (t) async {
    final c = await round(t);
    await t.tap(tip);
    await t.pumpAndSettle();
    expect(c.seenScoreHint, isTrue);
    expect(tip, findsNothing);
    expect(empty, findsNothing);
  });

  testWidgets('a table that has seen the tip is not shown it again',
      (t) async {
    await round(t, seen: true);
    expect(tip, findsNothing);
  });

  group('avatars', () {
    test('a free face is simply taken', () {
      final c = GameController();
      expect(c.avatars, [0, 1, 2, 3]);
      c.setAvatar(0, 7);
      expect(c.avatars, [7, 1, 2, 3]);
      expect(c.avatarOwner(0), isNull);
    });

    test('a face another seat wears is swapped, never shared', () {
      final c = GameController();
      c.setAvatar(0, 2);
      expect(c.avatars, [2, 1, 0, 3]);
      expect(c.avatarsUnique, isTrue);
      expect(c.avatarOwner(2, except: 0), isNull);
    });

    test('a saved table with a shared face is mended on load', () async {
      SharedPreferences.setMockInitialValues({
        'estimation_state_v1': jsonEncode({
          'avatars': [1, 1, 3, 3],
        }),
      });
      final c = GameController();
      await c.load();
      expect(c.avatarsUnique, isTrue);
      expect(c.avatars, [1, 0, 3, 2]);
    });

    test('a game cannot start with two seats on one face', () {
      final c = GameController()
        ..draftPlayers = ['A', 'B', 'C', 'D']
        ..avatars = [0, 0, 2, 3];
      c.startGame();
      expect(c.screen, isNot(Screen.bid));
    });

    testWidgets('the picker opens from the face; worn faces cannot be picked',
        (t) async {
      SharedPreferences.setMockInitialValues({});
      t.view.physicalSize = const Size(740, 360) * 2;
      t.view.devicePixelRatio = 2.0;
      addTearDown(t.view.reset);
      final c = GameController()..screen = Screen.setupPlayers;
      await t.pumpWidget(EstimationApp(controller: c));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);

      // Each card holds one fixed face, no inline picker.
      expect(find.byType(SvgPicture), findsNWidgets(4));

      Future<void> open() async {
        await t.tap(find.byIcon(Icons.edit_rounded).first);
        await t.pumpAndSettle();
      }

      await open();
      expect(find.text('PICK AN AVATAR · SEAT 1'), findsOneWidget);
      expect(t.takeException(), isNull);
      // The other three seats' faces say whose they are.
      for (final n in [2, 3, 4]) {
        expect(find.text('SEAT $n'), findsWidgets);
      }

      // A worn face does nothing.
      await t.tap(find.text('Owl'));
      await t.pumpAndSettle();
      expect(c.avatars, [0, 1, 2, 3]);
      expect(find.text('PICK AN AVATAR · SEAT 1'), findsOneWidget);

      // The close button changes nothing.
      await t.tap(find.byIcon(Icons.close_rounded));
      await t.pumpAndSettle();
      expect(find.text('PICK AN AVATAR · SEAT 1'), findsNothing);
      expect(c.avatars, [0, 1, 2, 3]);

      // A free face is saved and the picker closes.
      await open();
      await t.tap(find.text('Camel'));
      await t.pumpAndSettle();
      expect(c.avatars, [5, 1, 2, 3]);
      expect(find.text('PICK AN AVATAR · SEAT 1'), findsNothing);
      expect(find.text('CAMEL'), findsOneWidget);
    });
  });
}
