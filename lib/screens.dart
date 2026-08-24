import 'package:flutter/material.dart';

import 'controller.dart';
import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

// ------------------------------------------------------------------- shared

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool secondary;
  const PrimaryButton(this.label,
      {super.key, this.onTap, this.secondary = false});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.3,
      child: Material(
        color: secondary ? AppColors.surface : AppColors.gold,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
            alignment: Alignment.center,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: secondary ? AppColors.text : AppColors.onGold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Banner_ extends StatelessWidget {
  final String text;
  final bool warn;
  const Banner_(this.text, {super.key, this.warn = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 13),
      decoration: BoxDecoration(
        color: (warn ? AppColors.red : AppColors.gold).withOpacity(0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          height: 1.5,
          color: warn ? const Color(0xFFF0A394) : const Color(0xFFE6BD72),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------- home

/// Landing screen. Landscape: title on the left, actions stacked on the right,
/// with a small language toggle in the top corner.
class HomeScreen extends StatelessWidget {
  final GameController c;
  const HomeScreen({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    final s = c.s;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 20),
      child: Column(
        children: [
          // Small upper language button.
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _MiniBtn(
                label: c.arabic ? 'EN' : 'ع',
                onTap: c.toggleLanguage,
              ),
            ],
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Wordmark
                Expanded(
                  flex: 5,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.appName,
                        style: const TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -2,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(width: 60, height: 3, color: AppColors.gold),
                      const SizedBox(height: 12),
                      Text(s.tagline, style: labelStyle(size: 11)),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                // Actions
                Expanded(
                  flex: 4,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PrimaryButton(
                        c.hasGameInProgress ? s.resume : s.start,
                        onTap: c.hasGameInProgress ? c.resumeGame : c.toSetup,
                      ),
                      const SizedBox(height: 10),
                      if (c.hasGameInProgress) ...[
                        PrimaryButton(s.newGameBtn,
                            secondary: true, onTap: c.toSetup),
                        const SizedBox(height: 10),
                      ],
                      PrimaryButton(s.settings,
                          secondary: true, onTap: c.openSettings),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _MiniBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 30,
          child: Center(
            child: Text(label,
                style: const TextStyle(
                    fontFamily: kMono, fontSize: 12, color: AppColors.dim)),
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------- setup

class SetupScreen extends StatelessWidget {
  final GameController c;
  const SetupScreen({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    final s = c.s;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 32),
      children: [
        Text(s.appName,
            style: const TextStyle(
                fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1)),
        const SizedBox(height: 20),
        Text(s.length, style: labelStyle()),
        const SizedBox(height: 8),
        for (final m in GameMode.values) ...[
          GestureDetector(
            onTap: () => c.setMode(m),
            child: Container(
              margin: const EdgeInsets.only(bottom: 7),
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
              decoration: BoxDecoration(
                color: c.mode == m ? AppColors.raise : AppColors.surface,
                border: Border.all(
                    color: c.mode == m ? AppColors.gold : AppColors.line),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.label(c.arabic),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(
                    '${m.totalRounds} ${s.rounds} · ${m.normalRounds} ${s.normal}'
                    '${m.colorRounds > 0 ? ' + ${m.colorRounds} ${s.color}' : ''}'
                    '${m.isHouse ? ' · ${s.houseRule}' : ''}',
                    style: labelStyle(size: 10),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        PrimaryButton(s.next, onTap: c.toPlayers),
      ],
    );
  }
}

// ------------------------------------------------------------------ players

/// Second half of setup: names only, once the length is settled. Landscape
/// puts the four seats side by side, in the order they sit at the table.
class PlayersScreen extends StatelessWidget {
  final GameController c;
  const PlayersScreen({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    final s = c.s;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 32),
      children: [
        Text(s.players,
            style: const TextStyle(
                fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1)),
        const SizedBox(height: 6),
        Text(c.mode.label(c.arabic), style: labelStyle(color: AppColors.gold)),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < c.players.length; i++) ...[
              Expanded(child: _NameField(c: c, index: i)),
              if (i < c.players.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: PrimaryButton(s.back,
                  secondary: true, onTap: c.backToSetup),
            ),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: PrimaryButton(s.start, onTap: c.startGame)),
          ],
        ),
      ],
    );
  }
}

class _NameField extends StatelessWidget {
  final GameController c;
  final int index;
  const _NameField({required this.c, required this.index});

  @override
  Widget build(BuildContext context) {
    final s = c.s;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${s.players} ${index + 1}', style: labelStyle(size: 10)),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: c.players[index],
          maxLength: 14,
          textAlign: TextAlign.center,
          onChanged: (v) => c.setPlayer(index, v),
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            counterText: '',
            hintText: '${s.players} ${index + 1}',
            filled: true,
            fillColor: AppColors.surface,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.line),
            ),
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------------- entry

class EntryScreen extends StatelessWidget {
  final GameController c;
  const EntryScreen({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    final s = c.s;
    final isBid = c.screen == Screen.bid;
    final err = c.validationError;
    final complete = isBid ? c.bidsComplete : c.tricksComplete;
    final allEqual = isBid && c.allEqualEstimates;

    // Landscape: seats take the width on the left, controls sit in a fixed
    // side panel so the primary action is always on screen without scrolling.
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 12),
              children: [
                if (c.editingIndex != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('${s.editingRound} ${c.editingIndex! + 1}',
                        style: labelStyle(color: AppColors.gold)),
                  ),
                Text(isBid ? s.estimate : s.tricksWon, style: labelStyle()),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < c.playerCount; i++) ...[
                      Expanded(
                          child: SeatColumn(c: c, index: i, isBid: isBid)),
                      if (i < c.playerCount - 1) const SizedBox(width: 6),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                StatBar(c: c, isBid: isBid),
                if (err != null) Banner_(err, warn: true),
              ],
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 250,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 12),
              children: [
                if (isBid && c.lockedTrump == null) ...[
                  Text(s.trump, style: labelStyle()),
                  const SizedBox(height: 8),
                  TrumpRow(c: c),
                  const SizedBox(height: 14),
                ],
                allEqual
                    ? PrimaryButton(s.rebid, onTap: c.doubleAndRebid)
                    : PrimaryButton(
                        isBid ? s.enterTricks : s.scoreRound,
                        onTap: (complete && err == null)
                            ? (isBid ? c.toTricks : c.commit)
                            : null,
                      ),
                const SizedBox(height: 8),
                PrimaryButton(
                  isBid ? s.allPassed : s.back,
                  secondary: true,
                  onTap: isBid ? c.skipRound : c.backToBids,
                ),
                // The running sheet sits beside the seats, not under them, so
                // the table can be read before anyone commits to a number.
                Scoreboard(c: c),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------- result

/// After a round is scored: the running sheet for every round played, not a
/// breakdown of the round just finished. Continue stays pinned so a long sheet
/// never buries it.
class ResultScreen extends StatelessWidget {
  final GameController c;
  const ResultScreen({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    final s = c.s;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (c.lastMessage != null) Banner_(c.lastMessage!),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [Scoreboard(c: c)],
            ),
          ),
          PrimaryButton(s.continue_, onTap: c.continueAfterResult),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------- done

class DoneScreen extends StatelessWidget {
  final GameController c;
  const DoneScreen({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    final s = c.s;
    final totals = c.totals;
    final best = totals.reduce((a, b) => a > b ? a : b);
    final winners = <String>[];
    for (var i = 0; i < totals.length; i++) {
      if (totals[i] == best) winners.add(c.players[i]);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
      children: [
        Text(s.gameOver, style: labelStyle()),
        const SizedBox(height: 10),
        Text(winners.join(' & '),
            style: const TextStyle(
                fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -1.2)),
        const SizedBox(height: 6),
        Text('${winners.length > 1 ? s.tieAt : s.winsWith} $best ${s.points}',
            style: labelStyle(size: 13)),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(child: PrimaryButton(s.newGame, onTap: c.newGame)),
            const SizedBox(width: 8),
            PrimaryButton(s.undo, secondary: true, onTap: c.undoLast),
          ],
        ),
        Scoreboard(c: c),
      ],
    );
  }
}

// ----------------------------------------------------------------- settings

class SettingsScreen extends StatefulWidget {
  final GameController c;
  const SettingsScreen({super.key, required this.c});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final s = c.s;
    final r = c.rules;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
      children: [
        Text(s.settings,
            style: const TextStyle(
                fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1)),
        _group(s.grpScoring),
        _num('Round score', 'every player, win / loss', r.roundScore,
            (v) => r.roundScore = v),
        _num('Caller or With', '', r.callerOrWith, (v) => r.callerOrWith = v),
        _num('Per risk level', 'Double Risk = twice this', r.perRisk,
            (v) => r.perRisk = v),
        _num('Sole winner / loser', '', r.soleBonus, (v) => r.soleBonus = v),
        _num('Dash \u2014 over round', 'total \u2265 14', r.dashOver,
            (v) => r.dashOver = v),
        _num('Dash \u2014 under round', 'total \u2264 12', r.dashUnder,
            (v) => r.dashUnder = v),
        _group(s.grpConfirm),
        _bool('Loss uses trick difference', 'off = subtract full estimate',
            r.lossTricksIsDiff, (v) => r.lossTricksIsDiff = v),
        _bool('Dash also gets round score', '', r.dashStacksRound,
            (v) => r.dashStacksRound = v),
        _bool('Dash also gets sole bonus', '', r.dashStacksSole,
            (v) => r.dashStacksSole = v),
        _group(s.grpRules),
        _num('Minimum caller estimate', '', r.minCallerBid,
            (v) => r.minCallerBid = v),
        _num('Max dash calls per round', '', r.maxDash, (v) => r.maxDash = v),
        _num('Super call minimum', 'unlocks trump in color rounds',
            r.superCallMin, (v) => r.superCallMin = v),
        _bool('Nobody made it \u2192 round scores 0', '', r.allMissZero,
            (v) => r.allMissZero = v),
        _bool('House: all equal \u2192 double + re-estimate', '',
            r.houseAllEqualDouble, (v) => r.houseAllEqualDouble = v),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: PrimaryButton(s.done, onTap: c.closeSettings)),
            const SizedBox(width: 8),
            PrimaryButton(s.defaults,
                secondary: true,
                onTap: () {
                  c.resetRules();
                  setState(() {});
                }),
          ],
        ),
      ],
    );
  }

  Widget _group(String label) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 4),
        child: Text(label, style: labelStyle(color: AppColors.gold)),
      );

  Widget _num(String label, String hint, int value, void Function(int) set) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Expanded(child: _label(label, hint)),
          SizedBox(
            width: 78,
            child: TextFormField(
              initialValue: '$value',
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: kMono, fontSize: 15),
              onChanged: (v) {
                final n = int.tryParse(v);
                if (n != null) {
                  set(n);
                  widget.c.ruleChanged();
                }
              },
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.line),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bool(
      String label, String hint, bool value, void Function(bool) set) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Expanded(child: _label(label, hint)),
          Switch(
            value: value,
            activeColor: AppColors.gold,
            onChanged: (v) {
              setState(() => set(v));
              widget.c.ruleChanged();
            },
          ),
        ],
      ),
    );
  }

  Widget _label(String label, String hint) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, height: 1.35)),
          if (hint.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(hint, style: labelStyle(size: 10)),
            ),
        ],
      );
}
