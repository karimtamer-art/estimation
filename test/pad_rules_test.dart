import 'package:flutter_test/flutter_test.dart';

import 'package:estimation/controller.dart';
import 'package:estimation/models.dart';

/// What the number pad may offer. `canPick` is a pure read of the working
/// round, so the controller can be posed by hand — nothing here saves.
GameController posed({
  required Screen screen,
  List<int?>? bids,
  List<int?>? tricks,
  List<bool>? dash,
  int? caller,
}) {
  final c = GameController()
    ..players = ['A', 'B', 'C', 'D']
    ..screen = screen;
  c.working = Round(
    bids: bids ?? List<int?>.filled(4, null),
    dash: dash ?? List<bool>.filled(4, false),
    order: const [],
    tricks: tricks ?? List<int?>.filled(4, null),
    caller: caller,
  );
  return c;
}

List<int> offered(GameController c, int seat) =>
    [for (var n = 0; n <= c.rules.tricks; n++) if (c.canPick(seat, n)) n];

void main() {
  group('estimates', () {
    test('nobody may outbid the seat pressed as Caller', () {
      final c = posed(screen: Screen.bid, bids: [7, null, null, null], caller: 0);
      expect(offered(c, 1), [0, 1, 2, 3, 4, 5, 6, 7]);
    });

    test('matching the Caller stays open — that is With', () {
      final c = posed(screen: Screen.bid, bids: [7, null, null, null], caller: 0);
      expect(c.canPick(1, 7), isTrue);
      expect(c.canPick(1, 8), isFalse);
    });

    test('the Caller may not call under the minimum, or under the table', () {
      final c = posed(screen: Screen.bid, bids: [null, 5, null, null], caller: 0);
      // Below minCallerBid (4) is out, and so is anything seat 1 already beats.
      expect(offered(c, 0), [5, 6, 7, 8, 9, 10, 11, 12, 13]);
    });

    test('the last seat cannot land the table on exactly 13', () {
      final c = posed(screen: Screen.bid, bids: [5, 4, 2, null]);
      expect(c.canPick(3, 2), isFalse); // 5+4+2+2 = 13
      expect(c.canPick(3, 1), isTrue);
      expect(c.canPick(3, 3), isTrue);
    });

    test('exactly 13 is only barred once everyone else has settled', () {
      final c = posed(screen: Screen.bid, bids: [5, 4, null, null]);
      expect(c.canPick(2, 4), isTrue); // seat 3 is still to come
    });

    test('a dashed seat is not counted into the table total', () {
      final c = posed(
        screen: Screen.bid,
        bids: [5, 4, 0, null],
        dash: [false, false, true, false],
      );
      expect(c.canPick(3, 4), isFalse); // 5+4+4 = 13
      expect(c.canPick(3, 2), isTrue);
    });
  });

  group('tricks', () {
    test('the table can never win more than thirteen', () {
      final c = posed(screen: Screen.tricks, tricks: [6, 4, null, null]);
      expect(offered(c, 2), [0, 1, 2, 3]);
    });

    test('the last seat gets only the number that completes the thirteen', () {
      final c = posed(screen: Screen.tricks, tricks: [6, 4, 2, null]);
      expect(offered(c, 3), [1]);
    });
  });
}
