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

  test('game over into a new game also blanks the seats', () {
    final c = GameController()
      ..draftPlayers = ['Karim', 'Ali', 'Sara', 'Omar'];
    c.startGame();

    c.newGame();
    expect(c.draftPlayers, ['', '', '', '']);
    expect(c.screen, Screen.setup);
  });
}
