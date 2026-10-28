import 'package:flutter/material.dart';

import '../../controller.dart';
import '../../models.dart';
import '../components.dart';
import '../frame.dart';
import '../tokens.dart';

/// Each length's card face: purple Micro, blue Mini, gold Full.
extension _ModeLook on GameMode {
  List<Color> get face => const {
        GameMode.micro: [
          Color(0xFFA98BEA),
          Color(0xFF7A55C9),
          Color(0xFF4E2F94)
        ],
        GameMode.mini: [
          Color(0xFF86B6F5),
          Color(0xFF3F78D4),
          Color(0xFF1E4A9E)
        ],
        GameMode.full: [
          Color(0xFFFFE27A),
          Color(0xFFF2B705),
          Color(0xFFC77A08)
        ],
      }[this]!;

  /// Full is gold, so it takes dark ink; the others take white.
  bool get darkInk => this == GameMode.full;
}

class LengthView extends StatelessWidget {
  final GameController c;
  const LengthView({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    final s = c.s;
    return ScreenFrame(
      c: c,
      header: TitleHeader(
        title: s.chooseLength,
        subtitle: s.howManyRounds,
        buttons: [
          HeaderButtons.home(c),
          HeaderButtons.language(c),
          HeaderButtons.settings(c),
        ],
      ),
      body: Padding(
        // Room above for the selected card to lift and wear its check.
        padding: const EdgeInsets.only(top: 22, bottom: 8),
        child: Row(
          children: [
            for (final m in GameMode.values) ...[
              if (m != GameMode.values.first) const SizedBox(width: 22),
              Expanded(child: _ModeCard(c: c, mode: m)),
            ],
          ],
        ),
      ),
      bottom: BottomBar(
        height: 72,
        lead: Text.rich(
          TextSpan(children: [
            TextSpan(
                text: '${s.selected} ',
                style: body(16,
                    weight: FontWeight.w800, color: Palette.secondary)),
            TextSpan(
              text: '${c.mode.label(c.arabic)} · '
                      '${c.mode.totalRounds} ${s.rounds}'
                  .toUpperCase(),
              style: display(20, color: Palette.gold, spacing: 0.03),
            ),
          ]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          GameButton(
            label: s.back,
            tone: ButtonTone.dark,
            width: 110,
            onTap: c.goHome,
          ),
          GameButton(
            label: s.nextPlayers,
            width: 220,
            fontSize: 19,
            onTap: c.toPlayers,
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final GameController c;
  final GameMode mode;
  const _ModeCard({required this.c, required this.mode});

  String _time() => switch (mode) {
        GameMode.micro => c.s.aboutQuarterHour,
        GameMode.mini => c.s.aboutHalfHour,
        GameMode.full => c.s.aboutHour,
      };

  @override
  Widget build(BuildContext context) {
    final s = c.s;
    final sel = c.mode == mode;
    final fg = mode.darkInk ? Palette.onGold : Palette.text;
    final small = mode.darkInk
        ? null
        : const [Shadow(offset: Offset(0, 2), color: Color(0x73000000))];
    final big = [
      Shadow(
        offset: Offset(0, mode.darkInk ? 3 : 4),
        color: mode.darkInk ? const Color(0x59FFFFFF) : const Color(0x73000000),
      ),
    ];
    final parts = [
      '${mode.normalRounds} ${s.normal}',
      if (mode.colorRounds > 0) '${mode.colorRounds} ${s.color}',
    ];

    Widget card(double numberSize) => AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, sel ? -4 : 0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: const Alignment(-0.34, -1),
              end: const Alignment(0.34, 1),
              colors: mode.face,
              stops: const [0, 0.45, 1],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Palette.outline, width: 2.5),
            boxShadow: [
              if (sel)
                const BoxShadow(color: Color(0x8CFFD23F), spreadRadius: 5),
              BoxShadow(offset: Offset(0, sel ? 8 : 6), color: Palette.outline),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(mode.label(c.arabic).toUpperCase(),
                  style: display(30, color: fg, spacing: 0.05)
                      .copyWith(shadows: small)),
              const SizedBox(height: 8),
              // The number and the split share what the card has between
              // its title and its footer, and shrink together on a short one.
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.topStart,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.topStart,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text('${mode.totalRounds}',
                                style:
                                    display(numberSize, color: fg, height: 0.9)
                                        .copyWith(shadows: big)),
                            const SizedBox(width: 10),
                            Opacity(
                              opacity: 0.85,
                              child: Text(s.rounds.toUpperCase(),
                                  style: display(22, color: fg, spacing: 0.04)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final p in parts) ...[
                              if (p != parts.first) const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 11, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0x38000000),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                      color: const Color(0x59000000),
                                      width: 1.5),
                                ),
                                child: Text(p,
                                    style: body(15,
                                        weight: FontWeight.w800, color: fg)),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Opacity(
                      opacity: 0.85,
                      child: Text(_time(), style: body(14, color: fg)),
                    ),
                  ),
                  if (mode.isHouse)
                    GameBadge(s.houseRule, tone: BadgeTone.dash, size: 13),
                ],
              ),
            ],
          ),
        );

    return Semantics(
      button: true,
      selected: sel,
      label: '${mode.label(c.arabic)}, ${mode.totalRounds} ${s.rounds}',
      child: GestureDetector(
        onTap: () => c.setMode(mode),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, box) =>
                    card((box.maxHeight * 0.26).clamp(52, 96).toDouble()),
              ),
            ),
            if (sel)
              PositionedDirectional(
                top: -20,
                end: 18,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: vgrad(Palette.goldHi, Palette.goldLo),
                    border: Border.all(color: Palette.outline, width: 2.5),
                    boxShadow: hardShadow(3),
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Palette.onGold, size: 26),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
