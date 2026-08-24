// A development entrypoint, never shipped: boots the app on a chosen screen
// with a table already in progress, so each screen can be looked at without
// playing a game to reach it.
//
//   flutter build web -t tool/preview.dart --output ../preview
//   ...serve it, then open ?state=bid | tricks | result | done | setup | ...
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

void main() {
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

    case 'done':
      c.rounds = _playedRounds();
      c.screen = Screen.done;
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
