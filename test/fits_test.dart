import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:estimation/controller.dart';
import 'package:estimation/main.dart';
import 'package:estimation/models.dart';
import 'package:estimation/widgets.dart';

/// Landscape phones this actually runs on, in physical pixels at 2x — the app
/// is landscape-only, so the short side is the one that bites.
const _phones = <String, Size>{
  'pixel 7': Size(1784, 824), // 892 x 412
  'iphone 14 pro': Size(1704, 786), // 852 x 393
  'small': Size(1480, 720), // 740 x 360
  'short': Size(1280, 600), // 640 x 300
};

/// The sizes a phone in the wild actually reports. At these every label has
/// to read at full size; below them it may shrink a little, but it must never
/// be cut off — a button reading "Ca..." is the bug being fixed here.
const _realPhones = {'pixel 7', 'iphone 14 pro', 'small'};

GameController posed({
  required Screen screen,
  GameMode mode = GameMode.full,
  int roundsPlayed = 1,
}) {
  final c = GameController()
    // Long names, because those are the ones that break a layout.
    ..players = ['Abdelrahman', 'Karim', 'Youssef', 'Ali']
    ..mode = mode
    ..screen = screen
    ..rounds = [
      for (var i = 0; i < roundsPlayed; i++)
        Round(
          bids: <int?>[5, 4, 3, 2],
          dash: List<bool>.filled(4, false),
          order: const [0, 1, 2, 3],
          tricks: <int?>[5, 4, 3, 1],
          caller: 0,
          trump: Suit.hearts,
          scores: [25, 24, -11, -45],
        ),
    ];
  c.working = Round(
    bids: <int?>[5, 4, null, null],
    dash: List<bool>.filled(4, false),
    order: const [0, 1],
    tricks: screen == Screen.tricks ? <int?>[5, null, null, null] : List<int?>.filled(4, null),
    caller: 0,
    trump: Suit.hearts,
  );
  if (screen == Screen.tricks) c.working.bids = <int?>[5, 4, 3, 2];
  return c;
}

/// The rendered width of a tag label against the width of the button holding
/// it. Anything over 1 was being squeezed — which is what turned "Caller"
/// into "Ca..." on a phone.
double squeeze(WidgetTester t, String label) {
  final text = find.text(label).first;
  final box = find.ancestor(of: text, matching: find.byType(FittedBox)).first;
  return t.getSize(text).width / t.getSize(box).width;
}

Future<void> show(WidgetTester t, GameController c, Size size) async {
  SharedPreferences.setMockInitialValues({});
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 2.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(EstimationApp(controller: c));
  await t.pumpAndSettle();
}

void main() {
  _phones.forEach((phone, size) {
    testWidgets('$phone: the estimate screen fits with nothing cut off',
        (t) async {
      await show(t, posed(screen: Screen.bid), size);
      expect(t.takeException(), isNull);

      // The three things a seat can say all read, and on a real phone they
      // read at full size. Anything over 1.25 would be crushed past legible.
      final limit = _realPhones.contains(phone) ? 1.0 : 1.25;
      for (final label in ['Caller', 'Edit', 'Dash']) {
        expect(find.text(label), findsNWidgets(4));
        expect(squeeze(t, label), lessThanOrEqualTo(limit),
            reason: '"$label" does not fit its button on $phone');
      }
    });

    testWidgets('$phone: the tricks screen fits', (t) async {
      await show(t, posed(screen: Screen.tricks), size);
      expect(t.takeException(), isNull);
    });

    testWidgets('$phone: a color round fits', (t) async {
      await show(
        t,
        posed(screen: Screen.bid, mode: GameMode.mini, roundsPlayed: 5),
        size,
      );
      expect(t.takeException(), isNull);
      // Edit stands alone here and has the whole column.
      expect(find.text('Edit'), findsNWidgets(4));
      expect(squeeze(t, 'Edit'), lessThanOrEqualTo(1.0));
    });

    testWidgets('$phone: Arabic fits too', (t) async {
      final c = posed(screen: Screen.bid)..arabic = true;
      await show(t, c, size);
      expect(t.takeException(), isNull);
    });
  });

  testWidgets('the seats use the height instead of leaving the screen bare',
      (t) async {
    await show(t, posed(screen: Screen.bid), const Size(1784, 824));

    // 412 logical points tall. The seat cards should reach most of the way
    // down it, not stop two thirds of the way and leave a dead band.
    final card = t.getSize(find.byType(SeatColumn).first);
    expect(card.height, greaterThan(220),
        reason: 'the seats are not taking the height they are given');

    // And the panel's actions are pushed to the foot of it, so the last one
    // finishes level with the stat row under the seats instead of stacking
    // under the step strip and leaving the bottom of the screen bare.
    final lastAction = t.getRect(find.text('All passed'));
    final stats = t.getRect(find.byType(StatBar));
    expect((lastAction.bottom - stats.bottom).abs(), lessThan(30),
        reason: 'the actions are not sitting at the foot of the panel');
  });
}
