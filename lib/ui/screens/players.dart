import 'package:flutter/material.dart';

import '../../controller.dart';
import '../../models.dart';
import '../avatars.dart';
import '../components.dart';
import '../frame.dart';
import '../tokens.dart';

/// Name the four seats and give each a face. Names are typed into the draft
/// and only become the table when START GAME is pressed.
class PlayersView extends StatefulWidget {
  final GameController c;
  const PlayersView({super.key, required this.c});

  /// For the dev preview only: open this seat's avatar picker on arrival.
  static int? debugOpenPicker;

  @override
  State<PlayersView> createState() => _PlayersViewState();
}

class _PlayersViewState extends State<PlayersView> {
  GameController get c => widget.c;

  @override
  void initState() {
    super.initState();
    final seat = PlayersView.debugOpenPicker;
    if (seat != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _AvatarPicker.show(context, c, seat);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = c.s;
    final blank = [
      for (var i = 0; i < c.draftPlayers.length; i++)
        if (c.draftPlayers[i].trim().isEmpty) '${s.player} ${i + 1}',
    ];
    return ScreenFrame(
      c: c,
      header: TitleHeader(
        title: s.players,
        badge: GameBadge(
          '${c.mode.label(c.arabic)} · ${c.mode.totalRounds} ${s.rounds}',
        ),
        buttons: [
          HeaderButtons.home(c),
          HeaderButtons.language(c),
          HeaderButtons.settings(c),
        ],
      ),
      body: Row(
        children: [
          for (var i = 0; i < c.draftPlayers.length; i++) ...[
            if (i > 0) const SizedBox(width: Gap.cards),
            Expanded(
              child: _SeatCard(
                c: c,
                seat: i,
                onName: (v) => setState(() => c.setPlayer(i, v)),
              ),
            ),
          ],
        ],
      ),
      bottom: BottomBar(
        height: 72,
        lead: Text(
          blank.isEmpty ? s.allSeatsReady : s.emptyNames(blank),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: body(16,
              weight: FontWeight.w800,
              color: blank.isEmpty ? Palette.greenText : Palette.secondary),
        ),
        actions: [
          GameButton(
            label: s.back,
            tone: ButtonTone.dark,
            width: 110,
            onTap: c.backToSetup,
          ),
          GameButton(
            onTap: c.avatarsUnique ? c.startGame : null,
            width: 240,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.play_arrow_rounded, size: 26),
                const SizedBox(width: 8),
                Text(s.startGame.toUpperCase(),
                    style: display(19, color: Palette.onGold, spacing: 0.04)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeatCard extends StatelessWidget {
  final GameController c;
  final int seat;
  final ValueChanged<String> onName;
  const _SeatCard({required this.c, required this.seat, required this.onName});

  @override
  Widget build(BuildContext context) {
    final s = c.s;
    final mine = c.avatars[seat];
    // Fixed content, the same at every size: the screen scales as a whole.
    return SeatPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Text('${s.seat} ${seat + 1}'.toUpperCase(),
                  style: display(14, color: Palette.secondary, spacing: 0.08)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  kAvatars[mine % kAvatars.length]
                      .label(c.arabic)
                      .toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: display(13, color: Palette.gold, spacing: 0.06),
                ),
              ),
            ],
          ),
          const Spacer(),
          Semantics(
            button: true,
            label: s.pickAvatarFor(seat + 1),
            child: GestureDetector(
              onTap: () => _AvatarPicker.show(context, c, seat),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ExcludeSemantics(child: AvatarTile(avatar: mine, size: 96)),
                  // The pencil says the face can be changed.
                  PositionedDirectional(
                    end: -8,
                    bottom: -8,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: vgrad(Palette.goldHi, Palette.goldLo),
                        border: Border.all(color: Palette.outline, width: 2),
                        boxShadow: hardShadow(2),
                      ),
                      child: const Icon(Icons.edit_rounded,
                          size: 16, color: Palette.onGold),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(s.name.toUpperCase(),
                style: display(13, color: Palette.secondary, spacing: 0.08)),
          ),
          const SizedBox(height: 6),
          _NameField(
            key: ValueKey('name$seat'),
            initial: c.draftPlayers[seat],
            hint: '${s.player} ${seat + 1}',
            onChanged: onName,
          ),
        ],
      ),
    );
  }
}

/// "PICK AN AVATAR · SEAT n": all nine faces, five over four. A face another
/// seat wears is greyed out and cannot be picked; picking a free one saves
/// it and closes.
class _AvatarPicker extends StatelessWidget {
  final GameController c;
  final int seat;
  const _AvatarPicker({required this.c, required this.seat});

  static Future<void> show(BuildContext context, GameController c, int seat) {
    return showDialog<void>(
      context: context,
      barrierColor: const Color(0xA8040816),
      builder: (_) => Directionality(
        textDirection: c.arabic ? TextDirection.rtl : TextDirection.ltr,
        child: _AvatarPicker(c: c, seat: seat),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = c.s;
    Widget row(int from, int to) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var k = from; k < to; k++) ...[
              if (k > from) const SizedBox(width: 14),
              _choice(context, k),
            ],
          ],
        );
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        // A short phone scales the whole modal down rather than cutting it.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 16, 16, 20),
              decoration: BoxDecoration(
                gradient:
                    vgrad(const Color(0xFF2A3657), const Color(0xFF18203A)),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Palette.outline, width: 3),
                boxShadow: hardShadow(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ScreenTitle(s.pickAvatarFor(seat + 1), size: 24),
                      const SizedBox(width: 40),
                      GameButton.icon(
                        onTap: () => Navigator.of(context).pop(),
                        semantics: s.close,
                        child: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  row(0, 5),
                  const SizedBox(height: 12),
                  row(5, kAvatars.length),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _choice(BuildContext context, int k) {
    final s = c.s;
    final on = c.avatars[seat] == k;
    final owner = c.avatarOwner(k, except: seat);
    final taken = owner != null;
    final tile = Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: on ? Palette.gold : const Color(0x59FFFFFF),
          width: on ? 4 : 2.5,
        ),
        boxShadow: [
          if (on) const BoxShadow(color: Color(0x8CFFD23F), spreadRadius: 3),
          const BoxShadow(color: Palette.outline, offset: Offset(0, 3)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(on ? 10 : 11.5),
        child: AvatarFace(index: k, size: 78),
      ),
    );
    return Semantics(
      button: true,
      selected: on,
      enabled: !taken,
      label: kAvatars[k].label(c.arabic),
      child: GestureDetector(
        onTap: taken
            ? null
            : () {
                c.setAvatar(seat, k);
                Navigator.of(context).pop();
              },
        child: SizedBox(
          width: 86,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: taken ? 0.45 : 1,
                    child: taken
                        ? ColorFiltered(
                            colorFilter: const ColorFilter.matrix([
                              0.33, 0.33, 0.33, 0, 0, //
                              0.33, 0.33, 0.33, 0, 0, //
                              0.33, 0.33, 0.33, 0, 0, //
                              0, 0, 0, 1, 0,
                            ]),
                            child: tile,
                          )
                        : tile,
                  ),
                  // Whose it is.
                  if (taken)
                    Positioned(
                      bottom: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF101830),
                          borderRadius: BorderRadius.circular(999),
                          border:
                              Border.all(color: Palette.outline, width: 1.5),
                        ),
                        child: Text(
                          '${s.seat} ${owner + 1}'.toUpperCase(),
                          style: display(11, color: Palette.secondary),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                kAvatars[k].label(c.arabic),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: body(12,
                    weight: FontWeight.w800,
                    color: on
                        ? Palette.gold
                        : taken
                            ? Palette.muted
                            : Palette.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The inset name well.
class _NameField extends StatelessWidget {
  final String initial;
  final String hint;
  final ValueChanged<String> onChanged;
  const _NameField({
    super.key,
    required this.initial,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final edge = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Palette.outline, width: 2),
    );
    return SizedBox(
      height: 54,
      child: TextFormField(
        expands: true,
        maxLines: null,
        initialValue: initial,
        maxLength: 14,
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        cursorColor: Palette.gold,
        onChanged: onChanged,
        style: body(20, weight: FontWeight.w800),
        decoration: InputDecoration(
          counterText: '',
          hintText: hint,
          hintStyle: body(20, weight: FontWeight.w800, color: Palette.muted),
          filled: true,
          fillColor: Palette.inset,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: edge,
          enabledBorder: edge,
          focusedBorder: edge.copyWith(
              borderSide: const BorderSide(color: Palette.gold, width: 2)),
        ),
      ),
    );
  }
}
