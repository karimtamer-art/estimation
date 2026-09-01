import 'package:flutter/material.dart';

import 'build_info.dart';
import 'controller.dart';
import 'models.dart';
import 'scoring.dart';
import 'strings.dart';
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
                      const LogoMark(size: 76),
                      const SizedBox(height: 14),
                      Text(
                        s.appName,
                        style: const TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -2,
                          height: 1,
                        ),
                      ),
                      Text(
                        s.appSubName,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                          height: 1.25,
                          color: AppColors.gold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(width: 60, height: 3, color: AppColors.gold),
                      const SizedBox(height: 12),
                      Text(s.tagline, style: labelStyle(size: 11)),
                      const SizedBox(height: 6),
                      // Which build this is. Every build says 1.0.0, so this
                      // is the only way to tell a fresh install from the one
                      // already on the phone.
                      Text('build $kBuildLabel',
                          style: labelStyle(size: 9, color: AppColors.faint)),
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

/// The length picker: three coloured buttons, no scrolling. Tapping one is
/// both the choice and the Next button, so setup is a single gesture.
class SetupScreen extends StatelessWidget {
  final GameController c;
  const SetupScreen({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    final s = c.s;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.appName,
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1)),
          const SizedBox(height: 4),
          Text(s.length, style: labelStyle()),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              children: [
                for (final m in GameMode.values) ...[
                  Expanded(child: _ModeCard(c: c, mode: m)),
                  if (m != GameMode.values.last) const SizedBox(width: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One length as a glossy, saturated button. The chosen length lights up —
/// full brightness, a white rim and a glow in its own colour — so a returning
/// table can see where it left off from across the room.
class _ModeCard extends StatelessWidget {
  final GameController c;
  final GameMode mode;
  const _ModeCard({required this.c, required this.mode});

  @override
  Widget build(BuildContext context) {
    final s = c.s;
    final current = c.mode == mode;
    final radius = BorderRadius.circular(16);
    const fast = Duration(milliseconds: 170);
    return AnimatedScale(
      scale: current ? 1 : 0.965,
      duration: fast,
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        opacity: current ? 1 : 0.84,
        duration: fast,
        child: AnimatedContainer(
          duration: fast,
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [mode.faceHi, mode.faceLo],
            ),
            border: Border.all(
              color: current ? Colors.white.withOpacity(0.9) : mode.faceRim,
              width: 2,
            ),
            boxShadow: [
              // The length's own colour, thrown on the background as a glow.
              BoxShadow(
                color: mode.faceLo.withOpacity(current ? 0.55 : 0.22),
                blurRadius: current ? 24 : 10,
                spreadRadius: current ? 1 : 0,
                offset: Offset(0, current ? 8 : 4),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.38),
                blurRadius: 9,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: radius,
              splashColor: Colors.white.withOpacity(0.20),
              highlightColor: Colors.white.withOpacity(0.08),
              onTap: () => c.chooseMode(mode),
              child: ClipRRect(
                borderRadius: radius,
                child: Stack(
                  children: [
                    // A glossy upper half that breaks on a hard line halfway
                    // down, then shadow pooling at the foot: the two halves of
                    // a moulded plastic button.
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0, 0.47, 0.475, 1],
                            colors: [
                              Colors.white.withOpacity(0.34),
                              Colors.white.withOpacity(0.10),
                              Colors.white.withOpacity(0),
                              Colors.black.withOpacity(0.18),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Hairline bevel just inside the rim.
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.22),
                              width: 1.2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mode.label(c.arabic).toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color: Colors.white,
                              shadows: _facePress,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '${mode.totalRounds}',
                                style: const TextStyle(
                                  fontFamily: kMono,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                  color: Colors.white,
                                  shadows: _facePress,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(s.rounds,
                                  style: labelStyle(
                                      size: 10,
                                      color: Colors.white.withOpacity(0.78))),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _ModeLine(text: '${mode.normalRounds} ${s.normal}'),
                          if (mode.colorRounds > 0) ...[
                            const SizedBox(height: 5),
                            _ModeLine(text: '${mode.colorRounds} ${s.color}'),
                          ],
                          const Spacer(),
                          if (mode.isHouse)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.26),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.22)),
                              ),
                              child: Text(s.houseRule.toUpperCase(),
                                  style: labelStyle(
                                      size: 9,
                                      color: Colors.white.withOpacity(0.92))),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Text pressed into the button face rather than sitting on top of it.
const List<Shadow> _facePress = [
  Shadow(color: Color(0x59000000), offset: Offset(0, 2), blurRadius: 3),
];

/// A white bullet on the button face, then the breakdown it describes.
class _ModeLine extends StatelessWidget {
  final String text;
  const _ModeLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  labelStyle(size: 10, color: Colors.white.withOpacity(0.92))),
        ),
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
        Text(c.mode.label(c.arabic), style: labelStyle(color: c.mode.accent)),
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
              child:
                  PrimaryButton(s.back, secondary: true, onTap: c.backToSetup),
            ),
            const SizedBox(width: 10),
            Expanded(
                flex: 2, child: PrimaryButton(s.start, onTap: c.startGame)),
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
        Text('${s.player} ${index + 1}', style: labelStyle(size: 10)),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: c.draftPlayers[index],
          maxLength: 14,
          textAlign: TextAlign.center,
          onChanged: (v) => c.setPlayer(index, v),
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            counterText: '',
            hintText: '${s.player} ${index + 1}',
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
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < c.playerCount; i++) ...[
                      Expanded(child: SeatColumn(c: c, index: i, isBid: isBid)),
                      if (i < c.playerCount - 1) const SizedBox(width: 6),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
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
                if (isBid) ...[
                  StepStrip(c: c),
                  const SizedBox(height: 12),
                ],
                // The trump is the caller's to pick, so the suits only come
                // out once the table has said whose call it is.
                if (isBid &&
                    c.lockedTrump == null &&
                    c.working.caller != null) ...[
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
                // No sheet down here any more: it lives behind the tab at the
                // top of the screen, where it can have the whole width.
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
    final g = summarize(c.rounds, c.playerCount);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
      children: [
        Center(
          child: Text(
            s.gameResult,
            style: const TextStyle(
                fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.8),
          ),
        ),
        const SizedBox(height: 2),
        Center(child: Text(_verdict(s, g), style: labelStyle(size: 10))),
        const SizedBox(height: 12),
        // The table on the left, what the game did on the right — the same
        // split the entry screen uses, so the eye lands where it already was.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Column(
                children: [
                  for (var place = 0; place < g.ranking.length; place++) ...[
                    if (place > 0) const SizedBox(height: 6),
                    _PlaceRow(c: c, g: g, seat: g.ranking[place], place: place),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(flex: 4, child: _GameFacts(c: c, g: g)),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: PrimaryButton(s.leave, secondary: true, onTap: c.goHome),
            ),
            const SizedBox(width: 8),
            Expanded(child: PrimaryButton(s.newGame, onTap: c.newGame)),
            const SizedBox(width: 8),
            // The last round is still reachable from here: a number typed
            // wrong on the final hand would otherwise be stuck on the sheet.
            PrimaryButton(s.undo, secondary: true, onTap: c.undoLast),
          ],
        ),
      ],
    );
  }

  /// The one-line verdict under the title. A shared top has no single winner,
  /// so it is said as a tie rather than pinned on whoever sits first.
  String _verdict(Str s, GameSummary g) {
    if (g.played == 0) return s.noRoundsPlayed;
    final best = g.totals[g.ranking.first];
    final names = [
      for (var i = 0; i < g.totals.length; i++)
        if (g.totals[i] == best) c.players[i],
    ];
    final verb = names.length > 1 ? s.tieAt : s.winsWith;
    return '${names.join(' & ')} $verb $best ${s.points}';
  }
}

/// One line of the standings: where the seat finished, who it was, how its
/// rounds went, and what it ended on.
class _PlaceRow extends StatelessWidget {
  final GameController c;
  final GameSummary g;
  final int seat;
  final int place;
  const _PlaceRow({
    required this.c,
    required this.g,
    required this.seat,
    required this.place,
  });

  @override
  Widget build(BuildContext context) {
    final s = c.s;
    final isKing = seat == g.leader;
    final isKoz = seat == g.laggard;
    final total = g.totals[seat];
    final accent =
        isKing ? AppColors.gold : (isKoz ? AppColors.red : AppColors.line);

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      decoration: BoxDecoration(
        // The winner's line is lifted out of the list; everyone else sits flat.
        color: isKing ? AppColors.gold.withOpacity(0.10) : AppColors.surface,
        border: Border.all(color: accent),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Center(
              // The crown and the koz stand in for the place they earned, so
              // first and last are read as pictures, not as numbers.
              child: isKing || isKoz
                  ? Image.asset(
                      isKing ? 'assets/crown.png' : 'assets/koz.png',
                      height: 34,
                      semanticLabel: isKing ? s.king : s.koz,
                      filterQuality: FilterQuality.medium,
                    )
                  : Text(s.place(place + 1),
                      style: labelStyle(size: 11, color: AppColors.dim)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  c.players[seat],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: isKing ? AppColors.gold : AppColors.text,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${g.won[seat]}${s.roundsWon} · ${g.lost[seat]}${s.roundsLost}',
                  style: labelStyle(size: 9, color: AppColors.dim),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$total',
            style: TextStyle(
              fontFamily: kMono,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: total > 0
                  ? AppColors.green
                  : (total < 0 ? AppColors.red : AppColors.dim),
            ),
          ),
        ],
      ),
    );
  }
}

/// What the game itself did: how long it was, and the two rounds worth
/// remembering afterwards.
class _GameFacts extends StatelessWidget {
  final GameController c;
  final GameSummary g;
  const _GameFacts({required this.c, required this.g});

  @override
  Widget build(BuildContext context) {
    final s = c.s;
    final accent = c.mode.accent;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  c.mode.label(c.arabic).toUpperCase(),
                  style: labelStyle(size: 10, color: c.mode.onAccent),
                ),
              ),
              const Spacer(),
              Text('${g.played} ${s.rounds}',
                  style: labelStyle(size: 10, color: AppColors.dim)),
            ],
          ),
          const Divider(color: AppColors.line, height: 20),
          _Fact(
            label: s.biggestWin,
            name: g.bestSeat == null ? '—' : c.players[g.bestSeat!],
            value: g.bestValue,
            color: AppColors.green,
          ),
          const SizedBox(height: 10),
          _Fact(
            label: s.biggestLoss,
            name: g.worstSeat == null ? '—' : c.players[g.worstSeat!],
            value: g.worstValue,
            color: AppColors.red,
          ),
        ],
      ),
    );
  }
}

/// A named round score: who took it and what it was worth.
class _Fact extends StatelessWidget {
  final String label;
  final String name;
  final int value;
  final Color color;
  const _Fact({
    required this.label,
    required this.name,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: labelStyle(size: 9)),
        const SizedBox(height: 3),
        Row(
          children: [
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              // A win is signed so the two lines cannot be misread for each
              // other at a glance; a loss already carries its minus.
              value > 0 ? '+$value' : '$value',
              style: TextStyle(
                fontFamily: kMono,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
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
        _num('Super call minimum', 'unlocks trump, and scores on the square',
            r.superCallMin, (v) => r.superCallMin = v),
        _bool('Super call scores on its own formula',
            'made +call\u00b2, missed \u2212call\u00b2/2, off = normal caller',
            r.superCallOwnScore, (v) => r.superCallOwnScore = v),
        _num('Super call miss divisor', 'a missed call costs call\u00b2 over this',
            r.superCallLossDiv, (v) => r.superCallLossDiv = v),
        _bool('Nobody made it \u2192 round scores 0', '', r.allMissZero,
            (v) => r.allMissZero = v),
        _num('All passed \u2192 next round worth',
            'passing again holds here', r.passMult,
            (v) => r.passMult = v),
        _num('Nobody made it \u2192 multiply by',
            'stacks: \u00d72, \u00d74, \u00d78', r.missMultiply,
            (v) => r.missMultiply = v),
        _bool('Shared top call \u2192 double',
            'three or more seats on the highest call',
            r.sameHighestCallDouble, (v) => r.sameHighestCallDouble = v),
        _num('Seats sharing the top call', '', r.sameHighestCallMin,
            (v) => r.sameHighestCallMin = v),
        _num('Shared top call multiplier', '', r.sameHighestCallMult,
            (v) => r.sameHighestCallMult = v),
        _bool('Shared top call: Color rounds only', '',
            r.sameHighestCallColorOnly,
            (v) => r.sameHighestCallColorOnly = v),
        _bool('Shared top call stacks',
            'on: \u00d72 over a running \u00d72 is \u00d74',
            r.sameHighestCallStacks, (v) => r.sameHighestCallStacks = v),
        _suits('Shared top call: trumps', r.sameHighestCallSuits),
        _bool('House: all equal \u2192 double + re-estimate', '',
            r.houseAllEqualDouble, (v) => r.houseAllEqualDouble = v),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: PrimaryButton(s.done, onTap: c.closeSettings)),
            const SizedBox(width: 8),
            PrimaryButton(s.defaults, secondary: true, onTap: () {
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

  /// Which trumps a rule is played under, as a row of suits to switch on and
  /// off — the Color rounds run sun, spades, hearts, diamonds, clubs.
  Widget _suits(String label, List<Suit> selected) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Expanded(child: _label(label, '')),
          for (final su in Suit.values) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () {
                selected.contains(su)
                    ? selected.remove(su)
                    : selected.add(su);
                widget.c.ruleChanged();
                setState(() {});
              },
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected.contains(su)
                      ? AppColors.gold
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.line),
                ),
                child: Text(
                  su.symbol,
                  style: TextStyle(
                    fontSize: 16,
                    color: selected.contains(su)
                        ? AppColors.onGold
                        : (su.isRed ? AppColors.red : AppColors.text),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

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

  Widget _bool(String label, String hint, bool value, void Function(bool) set) {
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
