import 'package:flutter/material.dart';

import '../controller.dart';
import 'components.dart';
import 'pulldown.dart';
import 'tokens.dart';

/// Lays a screen out at least [minHeight] logical pixels tall and shrinks
/// it to fit. The mockups are drawn 620 tall; a landscape phone has about
/// 380, and squeezing a layout into that breaks it, while scaling the whole
/// thing keeps it intact. 460 keeps a 52px button near the 44px floor.
class DesignCanvas extends StatelessWidget {
  final Widget child;
  final double minHeight;
  const DesignCanvas({super.key, required this.child, this.minHeight = 460});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final h = box.maxHeight;
      if (!h.isFinite || h >= minHeight) return child;
      final s = minHeight / h;
      return FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: box.maxWidth * s,
          height: minHeight,
          child: child,
        ),
      );
    });
  }
}

/// A game screen: the felt, then header / body / bottom bar with the
/// mockups' 24px sides, 18px ends and 14px between bands.
class ScreenFrame extends StatelessWidget {
  final GameController c;
  final Widget header;
  final Widget body;
  final Widget? bottom;

  /// A round in play: the scoresheet hangs above it on the round tile.
  final bool scoreSheet;
  const ScreenFrame({
    super.key,
    required this.c,
    required this.header,
    required this.body,
    this.bottom,
    this.scoreSheet = false,
  });

  @override
  Widget build(BuildContext context) {
    final screen = Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: Gap.side, vertical: Gap.edge),
      child: Column(
        children: [
          header,
          const SizedBox(height: Gap.band),
          Expanded(child: body),
          if (bottom != null) ...[
            const SizedBox(height: Gap.band),
            bottom!,
          ],
        ],
      ),
    );
    return FeltBackground(
      felt: Felt.values[c.felt % Felt.values.length],
      child: SafeArea(
        child: DesignCanvas(
          child: scoreSheet ? ScoreboardOverlay(c: c, child: screen) : screen,
        ),
      ),
    );
  }
}

/// Title (with an optional helper line beside it) and the header buttons.
class TitleHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? badge;
  final List<Widget> buttons;
  const TitleHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.badge,
    this.buttons = const [],
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: ScreenTitle(title),
                  ),
                ),
                if (badge != null) ...[const SizedBox(width: 14), badge!],
                if (subtitle != null) ...[
                  const SizedBox(width: 14),
                  Flexible(
                    child: Text(subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: body(15, color: Palette.secondary)),
                  ),
                ],
              ],
            ),
          ),
          for (final b in buttons) ...[const SizedBox(width: 10), b],
        ],
      ),
    );
  }
}

/// The square header buttons every screen shares.
class HeaderButtons {
  static Widget home(GameController c) => GameButton.icon(
        onTap: c.goHome,
        semantics: c.s.home,
        child: const Icon(Icons.home_outlined),
      );

  static Widget language(GameController c) => GameButton.icon(
        onTap: c.toggleLanguage,
        semantics: c.arabic ? 'English' : 'العربية',
        child: Text(c.arabic ? 'EN' : 'ع',
            style: body(c.arabic ? 16 : 20, weight: FontWeight.w900)),
      );

  static Widget settings(GameController c) => GameButton.icon(
        onTap: c.openSettings,
        semantics: c.s.settings,
        child: const Icon(Icons.settings_outlined),
      );
}
