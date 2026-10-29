import 'package:flutter/material.dart';

import 'controller.dart';
import 'main.dart';
import 'models.dart';
import 'theme.dart';
import 'ui/pulldown.dart';
import 'ui/screens/bid.dart';
import 'ui/screens/players.dart';

/// Dev entry for checking one screen at a time without clicking through the
/// game: `?screen=setup&ar=1&felt=2`. Not part of the shipped app.
///
/// In-round screens start a real game first. `dash=0,2` dashes those seats,
/// `modal=0` keeps the dash window shut.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final q = Uri.base.queryParameters;
  final c = GameController();
  c.arabic = q['ar'] == '1';
  c.felt = int.tryParse(q['felt'] ?? '') ?? 0;
  // `sheet=1` starts the round with its scoresheet pulled down.
  ScoreboardOverlay.debugStartOpen = q['sheet'] == '1';
  // `picker=2` opens seat 2's avatar picker on the Players screen.
  final picker = int.tryParse(q['picker'] ?? '');
  PlayersView.debugOpenPicker = picker == null ? null : picker - 1;
  c.draftPlayers = ['Karim', 'Ali', 'Sara', ''];
  final name = q['screen'];
  if (name == 'bid') {
    c.draftPlayers = ['Karim', 'Omar', 'Youssef', 'Nour'];
    if (q['color'] == '1') c.mode = GameMode.mini;
    c.startGame();
    // `color=1` jumps to Mini's first Color round.
    if (q['color'] == '1') {
      c.rounds.addAll(List.generate(5, (_) => Round.empty(4)));
      c.continueAfterResult();
    }
    for (final d in (q['dash'] ?? '').split(',')) {
      final i = int.tryParse(d);
      if (i != null) c.toggleDash(i);
    }
    if (q['modal'] == '0') c.dashPromptPending = false;
    // `pick=1,6,hearts` opens the bid screen with Omar's 6 in hearts picked;
    // leave off the trump or the bid for the earlier steps.
    final pick = (q['pick'] ?? '').split(',');
    if (pick.first.isNotEmpty) {
      BidView.debugPick = (
        int.parse(pick[0]),
        pick.length > 1 ? int.tryParse(pick[1]) : null,
        pick.length > 2 ? Suit.values.byName(pick[2]) : null,
      );
    }
    // `force=1` shows the bid screen even in a Color round, which the game
    // itself never does.
    if (q['force'] == '1') {
      c.dashPromptPending = false;
      runApp(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: Directionality(
          textDirection: c.arabic ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(body: BidView(c: c)),
        ),
      ));
      return;
    }
    // `phase=calls` settles Omar's call (6 in hearts) and Karim's 3.
    if (q['phase'] == 'calls') {
      c.dashPromptPending = false;
      c.applyCall(1, Suit.hearts, 6);
      c.setValue(0, 3);
    }
        // `phase=tricks` plays the hand: `tricks=part` counts two seats,
    // `tricks=all` the whole table (Nour took one over).
    if (q['phase'] == 'tricks') {
      c.dashPromptPending = false;
      c.applyCall(1, Suit.hearts, 6);
      c.setValue(0, 3);
      c.setValue(2, 0);
      c.setValue(3, 3);
      c.toTricks();
      if (q['tricks'] != null) {
        c.madeBid(0);
        c.setValue(1, 5);
      }
      if (q['tricks'] == 'all') {
        c.setValue(2, 1);
        c.setValue(3, 4);
      }
    }
        // `scores=1` puts a played round on the sheet, for the crown and the kooz.
    if (q['scores'] == '1') {
      c.rounds.add(Round(
        bids: [3, 6, 0, 4],
        dash: [false, false, true, false],
        order: const [],
        tricks: [2, 6, 1, 4],
        scores: [-2, 52, -4, 22],
      ));
    }
  } else if (name == 'result' || name == 'done') {
    // A game played through the engine: six rounds onto the sheet (one
    // passed), or all five of Micro for `done`.
    c.draftPlayers = ['Karim', 'Omar', 'Youssef', 'Nour'];
    if (name == 'done') c.mode = GameMode.micro;
    c.startGame();
    const plays = [
      [<int?>[3, 6, 0, 1], <int?>[3, 6, 1, 3], 1, Suit.hearts, 2],
      [<int?>[2, 5, 2, 3], <int?>[2, 5, 3, 3], 1, Suit.spades, null],
      [<int?>[4, 1, 7, 2], <int?>[4, 1, 6, 2], 2, Suit.sun, null],
      null,
      [<int?>[5, 2, 2, 2], <int?>[5, 2, 2, 4], 0, Suit.diamonds, null],
      [<int?>[0, 4, 3, 5], <int?>[2, 4, 3, 4], 3, Suit.clubs, 0],
    ];
    const n = 6;
    for (var k = 0; k < n; k++) {
      final p = plays[k];
      if (p == null) {
        c.skipRound();
      } else {
        final bids = p[0] as List<int?>;
        final dash = List<bool>.filled(4, false);
        if (p[4] != null) dash[p[4] as int] = true;
        c.working = Round(
          bids: [for (var i = 0; i < 4; i++) dash[i] ? 0 : bids[i]],
          dash: dash,
          order: const [0, 1, 2, 3],
          tricks: p[1] as List<int?>,
          caller: p[2] as int,
          trump: p[3] as Suit,
        );
        c.commit();
      }
      // With `sheet=1` the table plays on into round 7, sheet pulled down.
      if (k < n - 1 || name == 'done' || q['sheet'] == '1') {
        c.continueAfterResult();
      }
    }
    c.dashPromptPending = false;
  } else if (name != null) {
    for (final sc in Screen.values) {
      if (sc.name == name) c.screen = sc;
    }
  }
  runApp(EstimationApp(controller: c));
}
