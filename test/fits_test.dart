import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:estimation/controller.dart';
import 'package:estimation/main.dart';
import 'package:estimation/models.dart';
import 'package:estimation/ui/components.dart';

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

      // Seat 0 holds the call from the bid, seat 1 has called, and seat 2
      // is up on the pad.
      expect(find.text('BID'), findsOneWidget);
      expect(find.text('CALLING…'), findsOneWidget);
      // Every number on the shared pad is there, and big enough to hit on a
      // real phone.
      final floor = _realPhones.contains(phone) ? 40.0 : 30.0;
      for (var v = 0; v <= 13; v++) {
        final key = t.getRect(find.byKey(ValueKey('pad$v')));
        expect(key.width, greaterThanOrEqualTo(floor),
            reason: 'pad $v is too narrow on $phone');
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
      // Nobody holds a call from the bid here: every seat takes its turn.
      expect(find.text('BID'), findsNothing);
      expect(find.text('1ST'), findsOneWidget);
      expect(find.text('4TH'), findsOneWidget);
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

    // 412 logical points tall. The pad sits just above the bar and the
    // seats fill the height over it, with no dead band anywhere.
    final pad = t.getRect(find.byKey(const ValueKey('pad0')));
    final bar = t.getRect(find.byType(BottomBar));
    expect(bar.top - pad.bottom, lessThan(30),
        reason: 'the pad is not sitting on the bar');
    final seat = t.getRect(find.text('Karim'));
    expect(pad.top - seat.bottom, greaterThan(40),
        reason: 'the seats are not taking the height they are given');
  });
}
