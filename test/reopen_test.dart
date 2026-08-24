import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:estimation/controller.dart';
import 'package:estimation/models.dart';

/// Closing the app — or the browser tab — and opening it again should land on
/// Home, with whatever was running waiting behind Resume.
Future<GameController> reopen(GameController from) async {
  // The controller saves without being awaited; let it reach the store.
  await Future<void>.delayed(const Duration(milliseconds: 60));
  final next = GameController();
  await next.load();
  return next;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('reopening mid-round lands on Home, not in the round', () async {
    final a = GameController()
      ..draftPlayers = ['Karim', 'Ali', 'Sara', 'Omar'];
    a.startGame();
    a.setValue(0, 6);
    expect(a.screen, Screen.bid);

    final b = await reopen(a);
    expect(b.screen, Screen.home);
    // The round is still there, and the names with it.
    expect(b.hasGameInProgress, isTrue);
    expect(b.players, ['Karim', 'Ali', 'Sara', 'Omar']);
    expect(b.working.bids[0], 6);

    b.resumeGame();
    expect(b.screen, Screen.bid);
  });

  test('a round left half-counted resumes on the tricks screen', () async {
    final a = GameController()
      ..draftPlayers = ['Karim', 'Ali', 'Sara', 'Omar'];
    a.startGame();
    a.working.bids = [6, 3, 4, 2];
    a.working.caller = 0;
    a.working.trump = Suit.hearts;
    a.toTricks();

    final b = await reopen(a);
    expect(b.screen, Screen.home);
    b.resumeGame();
    expect(b.screen, Screen.tricks);
  });

  test('Home still offers Resume before a single round is scored', () async {
    final a = GameController()
      ..draftPlayers = ['Karim', 'Ali', 'Sara', 'Omar'];
    a.startGame();
    a.goHome();
    // No round on the sheet yet, but there is very much a game going.
    expect(a.rounds, isEmpty);
    expect(a.hasGameInProgress, isTrue);

    final b = await reopen(a);
    expect(b.screen, Screen.home);
    expect(b.hasGameInProgress, isTrue);
  });

  test('a game reopened after a round was scored comes back to the sheet',
      () async {
    final a = GameController()
      ..draftPlayers = ['Karim', 'Ali', 'Sara', 'Omar'];
    a.startGame();
    a.working.bids = [6, 3, 4, 2];
    a.working.caller = 0;
    a.working.trump = Suit.hearts;
    a.toTricks();
    a.working.tricks = [6, 3, 3, 1];
    a.commit();
    expect(a.screen, Screen.result);
    expect(a.rounds.length, 1);

    final b = await reopen(a);
    expect(b.screen, Screen.home);
    b.resumeGame();
    // Back to the result, where Continue opens the next round. Coming back
    // into the estimates would let the same round be scored a second time.
    expect(b.screen, Screen.result);
    b.continueAfterResult();
    expect(b.rounds.length, 1);
  });

  test('with nothing going on, Home offers a new game', () async {
    final a = GameController();
    a.goHome();

    final b = await reopen(a);
    expect(b.screen, Screen.home);
    expect(b.hasGameInProgress, isFalse);
  });
}
