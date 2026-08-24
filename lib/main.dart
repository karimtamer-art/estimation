import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'controller.dart';
import 'models.dart';
import 'screens.dart';
import 'theme.dart';
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
    if (c.dashPromptPending) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (c.takeDashPrompt()) DashWindow.show(context, c);
      });
    }
    final showHeader =
        c.screen != Screen.setup &&
            c.screen != Screen.setupPlayers &&
            c.screen != Screen.settings;
    // Over or under is only live while a round is being played.
    final showOverUnder =
        c.screen == Screen.bid || c.screen == Screen.tricks;

    // Home carries its own language button and needs the full frame.
    if (c.screen == Screen.home) {
      return Scaffold(body: SafeArea(child: HomeScreen(c: c)));
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
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
                      if (showHeader && c.currentMult > 1)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text('\u00d7${c.currentMult}',
                              style: const TextStyle(
                                  fontFamily: kMono,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onGold)),
                        ),
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
