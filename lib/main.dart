import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'controller.dart';
import 'models.dart';
import 'screens.dart';
import 'theme.dart';
import 'ui/components.dart';
import 'ui/screens/home.dart';
import 'ui/screens/length.dart';
import 'ui/round.dart';
import 'ui/screens/bid.dart';
import 'ui/screens/calls.dart';
import 'ui/screens/dash.dart';
import 'ui/screens/players.dart';
import 'ui/screens/scoreboard.dart';
import 'ui/screens/settings.dart';
import 'ui/screens/tricks.dart';
import 'ui/tokens.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Landscape only: four seats side by side need the width, and the scoresheet
  // reads like the paper one it replaces.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  final controller = GameController();
  await controller.load();
  // The table plays for an hour; the phone should not dim and lock on it.
  try {
    await WakelockPlus.toggle(enable: controller.keepAwake);
  } catch (_) {
    // Not every platform can hold the screen; play on regardless.
  }
  runApp(EstimationApp(controller: controller));
}

class EstimationApp extends StatelessWidget {
  final GameController controller;
  const EstimationApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        Haptics.on = controller.vibrate;
        return MaterialApp(
          title: 'Estimation',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          home: Directionality(
            textDirection:
                controller.arabic ? TextDirection.rtl : TextDirection.ltr,
            child: HomeShell(c: controller),
          ),
        );
      },
    );
  }
}

class HomeShell extends StatefulWidget {
  final GameController c;
  const HomeShell({super.key, required this.c});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  GameController get c => widget.c;

  @override
  Widget build(BuildContext context) {
    final s = c.s;

    // A fresh round raises the dash flag; open the window once the frame it
    // was raised in is on screen. takeDashPrompt lowers it, so the rebuilds
    // that follow cannot stack a second dialog on top.
    if (c.dashPromptPending && c.screen == Screen.bid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (c.takeDashPrompt()) DashModal.show(context, c);
      });
    }
    // The tip pointing at the round tile is for the first game only.
    if (c.screen == Screen.done && !c.seenScoreHint) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) c.markScoreHintSeen();
      });
    }
    // The round counter belongs to a game still being played. Setup has no
    // round yet, and a finished game has no next one.
    final showHeader = c.screen != Screen.setup &&
        c.screen != Screen.setupPlayers &&
        c.screen != Screen.settings &&
        c.screen != Screen.done;
    // Over or under is only live while a round is being played.
    final showOverUnder = c.screen == Screen.bid || c.screen == Screen.tricks;
    // The pull-down sheet belongs to a game that has a scoresheet at all.
    final showSheet = c.screen == Screen.bid ||
        c.screen == Screen.tricks ||
        c.screen == Screen.result ||
        c.screen == Screen.done;

    // Home carries its own language button and needs the full frame.
    if (c.screen == Screen.home) {
      return Scaffold(
        body: FeltBackground(
          felt: Felt.values[c.felt % Felt.values.length],
          child: SafeArea(child: HomeView(c: c)),
        ),
      );
    }
    // Screens already redrawn in the new style bring their own header.
    if (c.screen == Screen.setup) {
      return Scaffold(body: LengthView(c: c));
    }
    if (c.screen == Screen.setupPlayers) {
      return Scaffold(body: PlayersView(c: c));
    }
    if (c.screen == Screen.bid && phaseOf(c) == RoundPhase.bid) {
      return Scaffold(body: BidView(key: ValueKey(roundNumber(c)), c: c));
    }
    if (c.screen == Screen.bid && phaseOf(c) == RoundPhase.calls) {
      return Scaffold(body: CallsView(key: ValueKey(roundNumber(c)), c: c));
    }
    if (c.screen == Screen.tricks) {
      return Scaffold(body: TricksView(c: c));
    }
    if (c.screen == Screen.result || c.screen == Screen.done) {
      return Scaffold(body: ScoreboardView(c: c));
    }
    if (c.screen == Screen.settings) {
      return Scaffold(body: SettingsView(c: c));
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                // Landscape: let the seats use the real width of the device.
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: showHeader
                                ? Text(
                                    '${s.round} ${(c.playedCount + 1).clamp(1, c.mode.totalRounds)} '
                                    '${s.of} ${c.mode.totalRounds}',
                                    style: labelStyle(size: 11),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          if (showOverUnder) OverUnderPill(c: c),
                          _IconBtn(label: '\u2302', onTap: c.goHome),
                          const SizedBox(width: 6),
                          _IconBtn(
                            label: c.arabic ? 'EN' : '\u0639',
                            onTap: c.toggleLanguage,
                          ),
                          const SizedBox(width: 6),
                          _IconBtn(
                            label: '\u2699',
                            onTap: c.screen == Screen.settings
                                ? c.closeSettings
                                : c.openSettings,
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: _body()),
                  ],
                ),
              ),
            ),
            // The scoresheet sits above everything, folded away off the top
            // edge with only its tab showing.
            if (showSheet) ScoreDrawer(key: const ValueKey('sheet'), c: c),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    switch (c.screen) {
      case Screen.home:
        return HomeScreen(c: c);
      case Screen.setup:
        return SetupScreen(c: c);
      case Screen.setupPlayers:
        return PlayersScreen(c: c);
      case Screen.bid:
      case Screen.tricks:
        return EntryScreen(c: c);
      case Screen.result:
        return ResultScreen(c: c);
      case Screen.done:
        return DoneScreen(c: c);
      case Screen.settings:
        return SettingsScreen(c: c);
    }
  }
}

class _IconBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _IconBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 34,
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
