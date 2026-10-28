import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models.dart';
import 'ui/components.dart';
import 'ui/tokens.dart';

/// A test bench for the redesign's shared pieces, kept apart from the game.
/// Run it with `flutter run -t lib/ui_gallery.dart`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Gallery(),
  ));
}

class Gallery extends StatefulWidget {
  const Gallery({super.key});

  @override
  State<Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<Gallery> {
  bool rtl = false;
  Felt felt = Felt.navy;
  bool sw = true;
  int bid = 6;
  int tricks = 9;
  int phase = 1;
  int avatar = 0;
  bool selected = false;

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 10),
        child: Text(t.toUpperCase(),
            style: display(18, color: Palette.gold, spacing: 0.06)),
      );

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: FeltBackground(
          felt: felt,
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                  horizontal: Gap.side, vertical: Gap.edge),
              children: [
                Row(
                  children: [
                    const Expanded(child: ScreenTitle('UI kit')),
                    for (final f in Felt.values) ...[
                      GestureDetector(
                        onTap: () => setState(() => felt = f),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              center: const Alignment(-0.2, -0.3),
                              colors: [f.tones[0], f.tones[2]],
                            ),
                            border:
                                Border.all(color: Palette.outline, width: 2.5),
                            boxShadow: f == felt
                                ? const [
                                    BoxShadow(
                                        color: Color(0xFF0B1838),
                                        spreadRadius: 3),
                                    BoxShadow(
                                        color: Palette.gold, spreadRadius: 6),
                                  ]
                                : hardShadow(3),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                    ],
                    GameButton(
                      label: rtl ? 'LTR' : 'RTL',
                      tone: ButtonTone.dark,
                      width: 90,
                      height: 46,
                      onTap: () => setState(() => rtl = !rtl),
                    ),
                  ],
                ),
                _label('GameButton'),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    GameButton(label: 'Start', onTap: () {}, width: 180),
                    GameButton(
                        label: 'Back',
                        tone: ButtonTone.dark,
                        onTap: () {},
                        width: 110),
                    GameButton(
                        label: 'Lock in',
                        tone: ButtonTone.green,
                        onTap: () {},
                        width: 140),
                    GameButton(
                        label: 'Dash',
                        tone: ButtonTone.silver,
                        onTap: () {},
                        width: 120),
                    GameButton(label: 'Score round', onTap: null, width: 210),
                    GameButton(
                      label: selected ? 'Selected' : 'Tap to select',
                      selected: selected,
                      onTap: () => setState(() => selected = !selected),
                      width: 190,
                    ),
                    GameButton.icon(
                        onTap: () {}, child: const Icon(Icons.home_rounded)),
                    GameButton.icon(onTap: () {}, child: const Text('ع')),
                    GameButton.icon(
                        onTap: () {},
                        child: const Icon(Icons.bar_chart_rounded)),
                  ],
                ),
                _label('Badge · Plaque'),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: const [
                    GameBadge('Call'),
                    GameBadge('Dash', tone: BadgeTone.dash),
                    GameBadge('Last call · risk',
                        tone: BadgeTone.risk, size: 13),
                    Plaque('Hearts', suit: Suit.hearts),
                    Plaque('Spades', suit: Suit.spades),
                    Plaque('Sun', suit: Suit.sun),
                    Plaque('Under 1', tone: PlaqueTone.green),
                    Plaque('Over 2', tone: PlaqueTone.orange),
                    Plaque('Exactly 13', tone: PlaqueTone.red),
                  ],
                ),
                _label('RoundTile · PhaseTrack'),
                Row(
                  children: [
                    const RoundTile(round: 2, of: 18),
                    const SizedBox(width: 40),
                    const RoundTile(round: 7, of: 18, multiplier: 2),
                    const SizedBox(width: 40),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => phase = (phase + 1) % 4),
                        child: PhaseTrack(
                          phases: const ['Dash', 'Bid', 'Calls', 'Tricks'],
                          current: phase,
                        ),
                      ),
                    ),
                  ],
                ),
                _label('AvatarTile (tap the first to cycle)'),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 44,
                  runSpacing: 30,
                  children: [
                    AvatarTile(
                      avatar: avatar,
                      total: '+42',
                      bubble: BubbleTone.leader,
                      crown: true,
                      onTap: () => setState(() => avatar = (avatar + 1) % 4),
                    ),
                    const AvatarTile(
                        avatar: 1, frame: AvatarFrame.caller, total: '+12'),
                    const AvatarTile(
                        avatar: 2, frame: AvatarFrame.made, total: '0'),
                    const AvatarTile(
                      avatar: 3,
                      total: '−18',
                      bubble: BubbleTone.last,
                      clown: true,
                    ),
                    const AvatarTile(
                        avatar: 0, size: 56, frame: AvatarFrame.dash),
                  ],
                ),
                _label('SeatPanel · Stepper · Switch'),
                SizedBox(
                  height: 170,
                  child: Row(
                    children: [
                      Expanded(
                        child: SeatPanel(
                          edge: PanelEdge.caller,
                          child: Center(
                            child: GameStepper(
                              value: '$bid',
                              onDec:
                                  bid > 4 ? () => setState(() => bid--) : null,
                              onInc:
                                  bid < 13 ? () => setState(() => bid++) : null,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: Gap.cards),
                      Expanded(
                        child: SeatPanel(
                          edge: PanelEdge.pending,
                          child: Center(
                            child: Text('Pending',
                                style: body(18, weight: FontWeight.w900)),
                          ),
                        ),
                      ),
                      const SizedBox(width: Gap.cards),
                      Expanded(
                        child: SeatPanel(
                          child: Center(
                            child: GameSwitch(
                              value: sw,
                              onChanged: (v) => setState(() => sw = v),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _label('TrickBar · BottomBar'),
                BottomBar(
                  lead: CountLead(
                    count: tricks,
                    suffix: '/ 13 tricks',
                    message: tricks == 13
                        ? 'ready!'
                        : tricks > 13
                            ? '${tricks - 13} too many'
                            : '${13 - tricks} unassigned',
                    messageColor: tricks == 13
                        ? Palette.greenText
                        : tricks > 13
                            ? Palette.redText
                            : Palette.gold,
                  ),
                  middle: TrickBar(assigned: tricks),
                  actions: [
                    GameButton(
                      label: 'Back',
                      tone: ButtonTone.dark,
                      width: 110,
                      onTap: () =>
                          setState(() => tricks = (tricks - 1).clamp(0, 15)),
                    ),
                    GameButton(
                      label: '+',
                      tone: ButtonTone.dark,
                      width: 52,
                      fontSize: 26,
                      onTap: () => setState(() => tricks++),
                    ),
                    GameButton(
                      label: 'Score round',
                      width: 210,
                      fontSize: 19,
                      onTap: tricks == 13
                          ? () => setState(() => tricks = 9)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('BACK / + step the count; SCORE ROUND only lights at 13.',
                    style: body(13, color: Palette.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
