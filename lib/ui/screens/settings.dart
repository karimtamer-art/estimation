import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../build_info.dart';
import '../../controller.dart';
import '../../models.dart';
import '../../rules.dart';
import '../components.dart';
import '../frame.dart';
import '../tokens.dart';

/// Look & feel on the left, the engine's own rules on the right. A rule
/// change goes through [GameController.ruleChanged], which rescores the
/// whole game on the spot — so the footer says that, not "next game".
class SettingsView extends StatefulWidget {
  final GameController c;
  const SettingsView({super.key, required this.c});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  GameController get c => widget.c;

  void _rule(void Function(Rules r) set) {
    set(c.rules);
    c.ruleChanged();
  }

  Future<void> _awake(bool on) async {
    c.setKeepAwake(on);
    try {
      await WakelockPlus.toggle(enable: on);
    } catch (_) {
      // Not every platform can hold the screen; the preference still saves.
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = c.s;
    return ScreenFrame(
      c: c,
      header: TitleHeader(
        title: s.settings,
        buttons: [
          GameButton.icon(
            onTap: () {
              c.closeSettings();
              c.goHome();
            },
            semantics: s.home,
            child: const Icon(Icons.home_outlined),
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _look()),
          const SizedBox(width: 18),
          Expanded(child: _rules()),
        ],
      ),
      bottom: BottomBar(
        height: 72,
        lead: Text(
          'BUILD ${kBuildLabel.toUpperCase()} · ${s.rulesRescore}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: body(14, color: Palette.muted),
        ),
        actions: [
          GameButton(
            label: s.defaults,
            tone: ButtonTone.dark,
            width: 140,
            fontSize: 17,
            onTap: c.resetRules,
          ),
          GameButton(
            label: s.done,
            width: 180,
            fontSize: 19,
            onTap: c.closeSettings,
          ),
        ],
      ),
    );
  }

  Widget _heading(String t, {Widget? badge}) => Row(
        children: [
          Text(t.toUpperCase(),
              style: display(20, color: Palette.gold, spacing: 0.06)),
          if (badge != null) ...[const SizedBox(width: 10), badge],
        ],
      );

  Widget _look() {
    final s = c.s;
    return SectionPanel(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heading(s.lookAndFeel),
            const SizedBox(height: 16),
            _Line(
              label: s.language,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final ar in const [false, true]) ...[
                    if (ar) const SizedBox(width: 8),
                    GameButton(
                      tone: c.arabic == ar ? ButtonTone.gold : ButtonTone.dark,
                      selected: c.arabic == ar,
                      width: 120,
                      height: 46,
                      onTap: c.arabic == ar ? () {} : c.toggleLanguage,
                      child: Text(ar ? 'العربية' : 'English',
                          style: body(17,
                              weight: FontWeight.w900,
                              color: c.arabic == ar
                                  ? Palette.onGold
                                  : Palette.text)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Line(
              label: s.tableColor,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final f in Felt.values) ...[
                    if (f != Felt.values.first) const SizedBox(width: 10),
                    _Swatch(
                      felt: f,
                      on: c.felt % Felt.values.length == f.index,
                      label: f.label(c.arabic),
                      onTap: () => c.setFelt(f.index),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Line(
              label: s.vibration,
              hint: s.vibrationHint,
              trailing: GameSwitch(
                value: c.vibrate,
                semantics: s.vibration,
                onChanged: c.setVibrate,
              ),
            ),
            const SizedBox(height: 16),
            _Line(
              label: s.keepAwake,
              hint: s.keepAwakeHint,
              trailing: GameSwitch(
                value: c.keepAwake,
                semantics: s.keepAwake,
                onChanged: _awake,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rules() {
    final s = c.s;
    final r = c.rules;
    Widget num(String label, String hint, int value, void Function(int) set,
            {int min = 0}) =>
        _Line(
          label: label,
          hint: hint.isEmpty ? null : hint,
          trailing: _NumStepper(
            value: value,
            min: min,
            onChanged: (v) => _rule((_) => set(v)),
          ),
        );
    Widget flag(
            String label, String hint, bool value, void Function(bool) set) =>
        _Line(
          label: label,
          hint: hint.isEmpty ? null : hint,
          trailing: GameSwitch(
            value: value,
            semantics: label,
            onChanged: (v) => _rule((_) => set(v)),
          ),
        );
    Widget group(String t) => Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 4),
          child: Text(t.toUpperCase(),
              style: display(14, color: Palette.secondary, spacing: 0.08)),
        );
    const gap = SizedBox(height: 12);

    return SectionPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading(s.houseRules,
              badge: GameBadge(s.pocket, tone: BadgeTone.dash, size: 12)),
          const SizedBox(height: 4),
          Expanded(
            child: ListView(
              children: [
                group(s.grpScoring),
                num('Round score', 'every player who makes it', r.roundScore,
                    (v) => r.roundScore = v),
                gap,
                num('Caller or With', '', r.callerOrWith,
                    (v) => r.callerOrWith = v),
                gap,
                num('Per risk level', 'Double Risk = twice this', r.perRisk,
                    (v) => r.perRisk = v),
                gap,
                num('Sole winner / loser', '', r.soleBonus,
                    (v) => r.soleBonus = v),
                gap,
                num('Dash — over round', 'total ≥ 14', r.dashOver,
                    (v) => r.dashOver = v),
                gap,
                num('Dash — under round', 'total ≤ 12', r.dashUnder,
                    (v) => r.dashUnder = v),
                group(s.grpConfirm),
                flag(
                    'Loss uses trick difference',
                    'off = subtract full estimate',
                    r.lossTricksIsDiff,
                    (v) => r.lossTricksIsDiff = v),
                gap,
                flag(
                    'Miss also loses round score',
                    'off = a miss costs only the difference',
                    r.roundScoreOnLoss,
                    (v) => r.roundScoreOnLoss = v),
                gap,
                flag('Dash also gets round score', '', r.dashStacksRound,
                    (v) => r.dashStacksRound = v),
                gap,
                flag('Dash also gets sole bonus', '', r.dashStacksSole,
                    (v) => r.dashStacksSole = v),
                group(s.grpRules),
                num('Minimum caller estimate', '', r.minCallerBid,
                    (v) => r.minCallerBid = v),
                gap,
                num('Max dash calls per round', '', r.maxDash,
                    (v) => r.maxDash = v),
                gap,
                num(
                    'Super call minimum',
                    'unlocks trump, and scores on the square',
                    r.superCallMin,
                    (v) => r.superCallMin = v),
                gap,
                flag(
                    'Super call scores on its own formula',
                    'made +call², missed −call²/2, '
                        'off = normal caller',
                    r.superCallOwnScore,
                    (v) => r.superCallOwnScore = v),
                gap,
                num(
                    'Super call miss divisor',
                    'a missed call costs call² over this',
                    r.superCallLossDiv,
                    (v) => r.superCallLossDiv = v,
                    min: 1),
                gap,
                flag('Nobody made it → round scores 0', '', r.allMissZero,
                    (v) => r.allMissZero = v),
                gap,
                num('All passed → next round worth', 'passing again holds here',
                    r.passMult, (v) => r.passMult = v,
                    min: 1),
                gap,
                num('Nobody made it → multiply by', 'stacks: ×2, ×4, ×8',
                    r.missMultiply, (v) => r.missMultiply = v,
                    min: 1),
                gap,
                flag(
                    'Shared top call → double',
                    'three or more seats on the highest call',
                    r.sameHighestCallDouble,
                    (v) => r.sameHighestCallDouble = v),
                gap,
                num('Seats sharing the top call', '', r.sameHighestCallMin,
                    (v) => r.sameHighestCallMin = v),
                gap,
                num('Shared top call multiplier', '', r.sameHighestCallMult,
                    (v) => r.sameHighestCallMult = v,
                    min: 1),
                gap,
                flag(
                    'Shared top call: Color rounds only',
                    '',
                    r.sameHighestCallColorOnly,
                    (v) => r.sameHighestCallColorOnly = v),
                gap,
                flag(
                    'Shared top call stacks',
                    'on: ×2 over a running ×2 is ×4',
                    r.sameHighestCallStacks,
                    (v) => r.sameHighestCallStacks = v),
                gap,
                _Line(
                  label: 'Shared top call: trumps',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final su in kColorOrder) ...[
                        if (su != kColorOrder.first) const SizedBox(width: 6),
                        _SuitChip(
                          suit: su,
                          on: r.sameHighestCallSuits.contains(su),
                          onTap: () => _rule((r) {
                            // Kept in the Color order, whatever order the
                            // chips are pressed in.
                            final on = r.sameHighestCallSuits.contains(su);
                            r.sameHighestCallSuits = [
                              for (final x in kColorOrder)
                                if (x == su
                                    ? !on
                                    : r.sameHighestCallSuits.contains(x))
                                  x,
                            ];
                          }),
                        ),
                      ],
                    ],
                  ),
                ),
                gap,
                flag('Nobody calls over the bid winner (normal rounds)', '',
                    r.callsCapAtBid, (v) => r.callsCapAtBid = v),
                gap,
                flag('House: all equal → double + re-estimate (Color rounds)', '',
                    r.houseAllEqualDouble, (v) => r.houseAllEqualDouble = v),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A settings line: label (and hint) on the start side, its control on the
/// end side.
class _Line extends StatelessWidget {
  final String label;
  final String? hint;
  final Widget trailing;
  const _Line({required this.label, this.hint, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: body(18, weight: FontWeight.w900)),
              if (hint != null)
                Text(hint!, style: body(13, color: Palette.secondary)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        trailing,
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  final Felt felt;
  final bool on;
  final String label;
  final VoidCallback onTap;
  const _Swatch({
    required this.felt,
    required this.on,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = felt.tones;
    return Semantics(
      button: true,
      selected: on,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(-0.2, -0.3),
              colors: [t[0], t[2]],
            ),
            border: Border.all(color: Palette.outline, width: 2.5),
            boxShadow: on
                ? const [
                    BoxShadow(color: Color(0xFF0B1838), spreadRadius: 3),
                    BoxShadow(color: Palette.gold, spreadRadius: 6),
                  ]
                : hardShadow(3),
          ),
        ),
      ),
    );
  }
}

class _SuitChip extends StatelessWidget {
  final Suit suit;
  final bool on;
  final VoidCallback onTap;
  const _SuitChip({required this.suit, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GameButton(
      tone: on ? ButtonTone.gold : ButtonTone.silver,
      selected: on,
      width: 44,
      height: 44,
      radius: 10,
      inset: 4,
      onTap: onTap,
      child: SuitGlyph(suit,
          size: 22, color: on && suit == Suit.sun ? Palette.onGold : null),
    );
  }
}

/// − n + for a number rule. Holding a button keeps stepping, so a value like
/// 33 is a press and a hold, not thirty taps.
class _NumStepper extends StatefulWidget {
  final int value;
  final int min;
  final ValueChanged<int> onChanged;
  const _NumStepper({
    required this.value,
    required this.onChanged,
    this.min = 0,
  });

  @override
  State<_NumStepper> createState() => _NumStepperState();
}

class _NumStepperState extends State<_NumStepper> {
  static const _max = 999;

  Timer? _repeat;
  late int _v = widget.value;

  @override
  void didUpdateWidget(_NumStepper old) {
    super.didUpdateWidget(old);
    if (_repeat == null) _v = widget.value;
  }

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  void _step(int d) {
    final next = (_v + d).clamp(widget.min, _max);
    if (next == _v) return;
    setState(() => _v = next);
    widget.onChanged(next);
  }

  Widget _button(String label, int d, bool enabled) {
    return GestureDetector(
      onLongPressStart: enabled
          ? (_) => _repeat =
              Timer.periodic(const Duration(milliseconds: 90), (_) => _step(d))
          : null,
      onLongPressEnd: (_) {
        _repeat?.cancel();
        _repeat = null;
      },
      child: GameButton(
        label: label,
        tone: ButtonTone.dark,
        width: 44,
        height: 44,
        radius: 10,
        fontSize: 22,
        inset: 4,
        onTap: enabled ? () => _step(d) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _button('−', -1, _v > widget.min),
        SizedBox(
          width: 52,
          child: Text('$_v',
              textAlign: TextAlign.center, style: display(24, shadow: true)),
        ),
        _button('+', 1, _v < _max),
      ],
    );
  }
}
