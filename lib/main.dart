import 'package:flutter/material.dart';

import 'controller.dart';
import 'models.dart';
import 'screens.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

class HomeShell extends StatelessWidget {
  final GameController c;
  const HomeShell({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    final s = c.s;
    final showHeader =
        c.screen != Screen.setup && c.screen != Screen.settings;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
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
      case Screen.setup:
        return SetupScreen(c: c);
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
