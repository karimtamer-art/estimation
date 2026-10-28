import 'package:flutter/material.dart';

import '../../controller.dart';
import '../avatars.dart';
import '../components.dart';
import '../round.dart';
import '../tokens.dart';

/// WAIT FOR DASH! — opened by itself when a round starts, and again from
/// EDIT DASH. Only DONE / SKIP closes it, so a stray tap can't wave a dash
/// away.
class DashModal extends StatelessWidget {
  final GameController c;
  const DashModal({super.key, required this.c});

  static Future<void> show(BuildContext context, GameController c) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0xA8040816),
      // The dialog is pushed above the Directionality that wraps the app, so
      // it has to be told the language's direction itself.
      builder: (_) => Directionality(
        textDirection: c.arabic ? TextDirection.rtl : TextDirection.ltr,
        child: DashModal(c: c),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final s = c.s;
        final dashed = c.working.dash;
        final who = [
          for (var i = 0; i < c.playerCount; i++)
            if (dashed[i]) c.players[i],
        ];
        final full = who.length >= c.rules.maxDash;
        final mult = c.currentMult;

        final content = Container(
          width: 900,
          padding: const EdgeInsets.fromLTRB(30, 28, 30, 24),
          decoration: BoxDecoration(
            gradient: vgrad(const Color(0xFF2A3657), const Color(0xFF18203A)),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Palette.outline, width: 3),
            boxShadow: hardShadow(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ScreenTitle('${s.dashWindow}!', size: 42),
                        const SizedBox(height: 4),
                        Text(s.dashWindowHint,
                            style: body(17, color: const Color(0xFFC5CDE0))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  GameBadge(
                    '${s.round} ${roundNumber(c)}'
                    '${mult > 1 ? ' · ×$mult' : ''}',
                    size: 14,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  for (var i = 0; i < c.playerCount; i++) ...[
                    if (i > 0) const SizedBox(width: 14),
                    Expanded(
                      child: _DashTile(
                        name: c.players[i],
                        avatar: c.avatars[i],
                        on: dashed[i],
                        label: s.dash,
                        // Only as many dashes as the rules allow. Ones already
                        // in stay pressable, so a seat that spoke too soon can
                        // take it back.
                        onTap:
                            dashed[i] || !full ? () => c.toggleDash(i) : null,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      who.isEmpty
                          ? s.nobodyDashedYet
                          : full
                              ? '${s.dashedList(who)} · ${s.dashLimit(c.rules.maxDash)}'
                              : s.dashedList(who),
                      style: body(16,
                          weight: FontWeight.w800,
                          color:
                              who.isEmpty ? Palette.secondary : Palette.text),
                    ),
                  ),
                  const SizedBox(width: 14),
                  GameButton(
                    label: who.isEmpty ? s.skip : s.done,
                    width: 180,
                    height: 56,
                    radius: 14,
                    fontSize: 22,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
          ),
        );

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child:
                    Material(type: MaterialType.transparency, child: content),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DashTile extends StatefulWidget {
  final String name;
  final int avatar;
  final bool on;
  final String label;
  final VoidCallback? onTap;
  const _DashTile({
    required this.name,
    required this.avatar,
    required this.on,
    required this.label,
    required this.onTap,
  });

  @override
  State<_DashTile> createState() => _DashTileState();
}

class _DashTileState extends State<_DashTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.on;
    final enabled = widget.onTap != null;
    final sunk = on || _down;
    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      height: 168,
      transform: Matrix4.translationValues(0, sunk ? 3 : 0, 0),
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
      decoration: BoxDecoration(
        gradient: on
            ? vgrad(Palette.silverHi, Palette.silverLo)
            : vgrad(Palette.darkHi, Palette.darkLo),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Palette.outline, width: 2.5),
        boxShadow: hardShadow(sunk ? 2 : 5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF4F6F5), width: 3),
              boxShadow: const [
                BoxShadow(color: Palette.outline, spreadRadius: 1.5),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: AvatarFace(index: widget.avatar, size: 70),
            ),
          ),
          const SizedBox(height: 10),
          Text(widget.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: body(19,
                  weight: FontWeight.w900,
                  color: on ? Palette.onGold : Palette.text)),
        ],
      ),
    );
    return Semantics(
      button: true,
      toggled: on,
      enabled: enabled,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTap: widget.onTap,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.passthrough,
            children: [
              tile,
              if (on)
                PositionedDirectional(
                  top: -12 + (sunk ? 3 : 0),
                  end: -8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: vgrad(Palette.darkHi, Palette.darkLo),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Palette.outline, width: 2),
                      boxShadow: hardShadow(3),
                    ),
                    child: Text(widget.label.toUpperCase(),
                        style: display(15, spacing: 0.06)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
