// A development entrypoint, never shipped: boots the app on a chosen screen
// with a table already in progress, so each screen can be looked at without
// playing a game to reach it.
//
//   flutter build web -t tool/preview.dart --output ../preview
//   ...serve it, then open
//     ?state=bid | dash | tricks | result | last | done | home | setup | players
//     &mode=micro | mini | full          (last and done only, default mini)
//
// `last` and `done` are not staged: they play the game out through the real
// commit path, so the sheet, the multipliers and the end screen are the ones
// the app produced rather than numbers typed into this file. `last` stops on
// the final round so the walk into the end screen can be watched.
//
// The app itself is untouched — this only assembles a GameController and hands
// it to the same widget tree main.dart runs.
import 'package:flutter/material.dart';

import 'package:estimation/controller.dart';
import 'package:estimation/main.dart';
import 'package:estimation/models.dart';

/// Three rounds on the sheet: Sara out front, Omar propping it up.
List<Round> _playedRounds() => [
      Round(
        bids: [5, 4, 3, 2],
        dash: List<bool>.filled(4, false),
        order: const [0, 1, 2, 3],
        tricks: [5, 4, 2, 2],
        caller: 0,
        trump: Suit.hearts,
        scores: [25, 24, -11, 12],
      ),
      Round(
        bids: [6, 3, 4, 2],
        dash: List<bool>.filled(4, false),
        order: const [1, 0, 3, 2],
        tricks: [6, 2, 4, 1],
        caller: 0,
        trump: Suit.spades,
        scores: [26, -11, 24, -11],
      ),
      Round(
        bids: [4, 5, 6, 2],
        dash: List<bool>.filled(4, false),
        order: const [2, 3, 0, 1],
        tricks: [4, 5, 6, -1],
        caller: 2,
        trump: Suit.sun,
        scores: [14, 15, 26, -12],
      ),
    ];

/// One hand as the table would have played it. The engine does the scoring;
/// these are only the numbers that were called and taken.
class _Hand {
  final List<int?> bids;
  final List<int?> tricks;
  final int caller;

  /// Who settled when — the last seat carries the Risk.
  final List<int> order;
  const _Hand(this.bids, this.tricks, this.caller, this.order);
}

/// Five hands, cycled to fill a game of any length. Every one of them takes
/// exactly 13 tricks, and at least one seat makes its number so no hand is a
/// wipe. The fourth is a super call of 8, so a long game always shows one on
/// the sheet.
const _hands = <_Hand>[
  _Hand([5, 4, 3, 2], [5, 4, 2, 2], 0, [0, 1, 2, 3]),
  _Hand([6, 3, 4, 2], [6, 2, 4, 1], 0, [1, 0, 3, 2]),
  _Hand([4, 5, 6, 2], [3, 5, 4, 1], 2, [2, 3, 0, 1]),
  _Hand([8, 2, 1, 1], [8, 2, 1, 2], 0, [3, 0, 1, 2]),
  _Hand([3, 3, 4, 4], [3, 4, 4, 2], 2, [0, 2, 1, 3]),
];

/// Plays [upTo] rounds of [mode] through the controller's own commit path.
/// Stopping one short leaves the table on the final round; going the whole way
/// walks into the end screen the same way the game does.
void _play(GameController c, GameMode mode, int upTo) {
  c.mode = mode;
  c.screen = Screen.bid;
  for (var i = 0; i < upTo; i++) {
    final h = _hands[i % _hands.length];
    c.working = Round(
      bids: List<int?>.from(h.bids),
      dash: List<bool>.filled(4, false),
      order: List<int>.from(h.order),
      tricks: List<int?>.from(h.tricks),
      caller: h.caller,
      // The Color rounds fix their own trump; the rest just need one.
      trump: mode.fixedTrump(i) ?? kColorOrder[i % kColorOrder.length],
    );
    c.commit();
    c.continueAfterResult();
  }
}

GameMode _mode() {
  final name = Uri.base.queryParameters['mode'];
  for (final m in GameMode.values) {
    if (m.name == name) return m;
  }
  // Mini by default: short enough to read, and it has the Color rounds.
  return GameMode.mini;
}

void main() {
  // The controller saves as it goes, and the preview drives it before runApp.
  WidgetsFlutterBinding.ensureInitialized();
  final state = Uri.base.queryParameters['state'] ?? 'bid';

  final c = GameController()
    ..players = ['Karim', 'Ali', 'Sara', 'Omar']
    ..draftPlayers = ['', '', '', ''];

  switch (state) {
    case 'home':
      c.screen = Screen.home;
      c.rounds = _playedRounds();
      break;

    case 'setup':
      c.screen = Screen.setup;
      break;

    case 'players':
      c.screen = Screen.setupPlayers;
      break;

    case 'dash':
      // The dash window, mid-countdown, on a fresh round.
      c.rounds = _playedRounds();
      c.screen = Screen.bid;
      c.dashPromptPending = true;
      break;

    case 'tricks':
      c.rounds = _playedRounds();
      c.screen = Screen.tricks;
      c.working = Round(
        bids: [6, 3, 4, 2],
        dash: [false, false, false, true],
        order: const [0, 1, 2],
        tricks: [6, null, null, null],
        caller: 0,
        trump: Suit.diamonds,
      );
      break;

    case 'result':
      c.rounds = _playedRounds();
      c.screen = Screen.result;
      c.resultIndex = 2;
      break;

    // The final round, still to be played. Press through it and the end
    // screen is the next thing on the screen.
    case 'last':
      _play(c, _mode(), _mode().totalRounds - 1);
      break;

    case 'done':
      _play(c, _mode(), _mode().totalRounds);
      break;

    case 'bid':
    default:
      c.rounds = _playedRounds();
      c.screen = Screen.bid;
      c.working = Round(
        bids: [6, 3, 4, null],
        dash: List<bool>.filled(4, false),
        order: const [0, 1, 2],
        tricks: List<int?>.filled(4, null),
        caller: 0,
      );
      break;
  }

  runApp(EstimationApp(controller: c));
}
