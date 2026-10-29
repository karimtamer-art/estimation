import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../build_info.dart';
import '../../controller.dart';
import '../../widgets.dart' show LogoMark;
import '../components.dart';
import '../tokens.dart';

/// The same fan, flat white, as a watermark in the far corner.
const _ghostSvg =
    '<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">'
    '<g fill="#FFFFFF">'
    '<rect x="18" y="20" width="40" height="58" rx="5" transform="rotate(-22 38 49)"/>'
    '<rect x="30" y="14" width="40" height="58" rx="5" transform="rotate(-6 50 43)"/>'
    '<rect x="42" y="16" width="40" height="58" rx="5" transform="rotate(12 62 45)"/>'
    '</g></svg>';

class HomeView extends StatelessWidget {
  final GameController c;
  const HomeView({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    final s = c.s;
    final resume = c.hasGameInProgress;
    return LayoutBuilder(builder: (context, box) {
      // Drawn for a 1280×620 table; a phone gets the same layout, smaller.
      final k = (box.maxHeight / 620).clamp(0.55, 1.25).toDouble();
      final brand = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The app icon itself, drawn: it matches the launcher icons.
          LogoMark(size: 104 * k),
          SizedBox(height: 10 * k),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              s.appName.toUpperCase(),
              style: display(92 * k, spacing: 0.01, height: 0.95)
                  .copyWith(shadows: [
                Shadow(offset: Offset(0, 5 * k), color: Palette.outline),
              ]),
            ),
          ),
          Text(
            s.appSubName.toUpperCase(),
            style:
                display(38 * k, color: Palette.gold, spacing: 0.04, height: 1.1)
                    .copyWith(shadows: [
              Shadow(offset: Offset(0, 3 * k), color: Palette.outline),
            ]),
          ),
          SizedBox(height: 18 * k),
          Row(
            children: [
              GameBadge(s.pocket, tone: BadgeTone.dash, size: 14),
              const SizedBox(width: 10),
              Flexible(
                child: Text(s.homeSub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: body((16 * k).clamp(13, 20).toDouble(),
                        color: Palette.secondary)),
              ),
            ],
          ),
          SizedBox(height: 6 * k),
          // Which build this is. Every build says 1.0.0, so this is the only
          // way to tell a fresh install from the one already on the phone.
          Text(
            'BUILD ${kBuildLabel.toUpperCase()}',
            style: body(12, color: const Color(0xFF6F7C9E))
                .copyWith(letterSpacing: 1.2),
          ),
        ],
      );
      final actions = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GameButton(
            onTap: resume ? c.resumeGame : c.toSetup,
            height: 92 * k,
            radius: 18,
            fontSize: 34 * k,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_arrow_rounded, size: 40 * k),
                SizedBox(width: 10 * k),
                Text((resume ? s.resume : s.start).toUpperCase(),
                    style:
                        display(34 * k, color: Palette.onGold, spacing: 0.06)),
              ],
            ),
          ),
          if (resume) ...[
            SizedBox(height: 18 * k),
            GameButton(
              label: s.newGameBtn,
              tone: ButtonTone.dark,
              onTap: c.toSetup,
              height: 72 * k,
              radius: 16,
              fontSize: 24 * k,
            ),
          ],
          SizedBox(height: 18 * k),
          GameButton(
            onTap: c.openSettings,
            tone: ButtonTone.dark,
            height: 72 * k,
            radius: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.settings_outlined, size: 26 * k),
                SizedBox(width: 12 * k),
                Text(s.settings.toUpperCase(),
                    style: display(24 * k, spacing: 0.06)),
              ],
            ),
          ),
        ],
      );

      return Stack(
        fit: StackFit.expand,
        children: [
          PositionedDirectional(
            end: -60 * k,
            bottom: -90 * k,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.10,
                child: SvgPicture.string(_ghostSvg,
                    width: 420 * k, height: 420 * k),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 72 * k),
            child: Row(
              children: [
                Expanded(child: brand),
                SizedBox(width: 64 * k),
                SizedBox(width: 480 * k, child: actions),
              ],
            ),
          ),
          PositionedDirectional(
            top: 20,
            end: 24,
            child: GameButton.icon(
              onTap: c.toggleLanguage,
              semantics: c.arabic ? 'English' : 'العربية',
              child: Text(c.arabic ? 'EN' : 'ع',
                  style: body(c.arabic ? 16 : 20, weight: FontWeight.w900)),
            ),
          ),
        ],
      );
    });
  }
}
