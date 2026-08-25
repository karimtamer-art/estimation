import 'package:flutter_test/flutter_test.dart';

import 'package:estimation/controller.dart';

/// Names typed on the setup screen live in a draft until the game starts, so
/// that starting a new one never disturbs the game still sitting there.
void main() {
  test('a new game starts on blank seats', () {
    final c = GameController()
      ..draftPlayers = ['Karim', 'Ali', 'Sara', 'Omar'];
    c.startGame();
    expect(c.players, ['Karim', 'Ali', 'Sara', 'Omar']);

    c.toSetup(); // Home -> New game
    expect(c.draftPlayers, ['', '', '', '']);
  });

  test('and leaves the names of the game it could still resume', () {
    final c = GameController()
      ..draftPlayers = ['Karim', 'Ali', 'Sara', 'Omar'];
    c.startGame();

    c.toSetup();
    // Walked into setup and thought better of it: the table is untouched.
    expect(c.players, ['Karim', 'Ali', 'Sara', 'Omar']);
    c.resumeGame();
    expect(c.players, ['Karim', 'Ali', 'Sara', 'Omar']);
  });

  test('a seat left blank is named for its number', () {
    final c = GameController()..draftPlayers = ['Karim', '', '  ', 'Omar'];
    c.startGame();
    expect(c.players, ['Karim', 'P2', 'P3', 'Omar']);
  });

  test('a new game starts on an empty sheet, with no multiplier carried', () {
    final c = GameController()..draftPlayers = ['Karim', 'Ali', 'Sara', 'Omar'];
    c.startGame();
    // A round nobody played doubles the next one — the sa'aydeh ladder.
    c.skipRound();
    c.continueAfterResult();
    expect(c.currentMult, 2);

    // Home -> New game -> Start. The last game's sheet does not come along,
    // and neither does the multiplier it was carrying.
    c.goHome();
    c.toSetup();
    c.draftPlayers = ['Karim', 'Ali', 'Sara', 'Omar'];
    c.startGame();
    expect(c.rounds, isEmpty);
    expect(c.currentMult, 1);
    expect(c.streak, 0);

    // And the first all-passed round of the new game doubles it, not trebles.
    c.skipRound();
    expect(c.currentMult, 2);
  });

  test('game over into a new game also blanks the seats', () {
    final c = GameController()
      ..draftPlayers = ['Karim', 'Ali', 'Sara', 'Omar'];
    c.startGame();

    c.newGame();
    expect(c.draftPlayers, ['', '', '', '']);
    expect(c.screen, Screen.setup);
  });
}
