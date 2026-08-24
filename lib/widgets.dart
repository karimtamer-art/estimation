import 'dart:async';

import 'package:flutter/material.dart';

import 'controller.dart';
import 'models.dart';
import 'scoring.dart';
import 'theme.dart';

/// One player's column: name, estimate or tricks, role badges, Caller and Dash.
class SeatColumn extends StatelessWidget {
  final GameController c;
  final int index;
  final bool isBid;

  const SeatColumn({
    super.key,
    required this.c,
    required this.index,
    required this.isBid,
  });

  @override
  Widget build(BuildContext context) {
    final s = c.s;
    final d = c.derived;
    final isDash = isBid && c.working.dash[index];
    final value = isBid ? c.working.bids[index] : c.working.tricks[index];
    final unset = value == null;

    // The prominent badge: Caller / With / Dash. Once a seat has been pressed
    // as Caller that seat wears Caller and anyone matching it wears With;
    // with nobody pressed it falls back to reading it off the estimates.
    final chosenCaller = c.working.caller;
    String? badge;
    if (isDash) {
      badge = s.dash;
    } else if (isBid && d.callerOrWith[index] && d.top != null) {
      badge = chosenCaller != null
          ? (chosenCaller == index ? s.caller : s.with_)
          : (d.callerOrWith.where((x) => x).length > 1 ? s.with_ : s.caller);
    }

    final riskTag = (index == d.riskIndex && d.riskLevel > 0)
        ? s.riskLabel(d.riskLevel)
        : null;

    final totals = c.totals;
    // Crown to the outright leader, koz to the outright last place.
    final crown = c.leaderIndex == index;
    final koz = c.laggardIndex == index;

    final dashCount = c.working.dash.where((x) => x).length;
    final canDash = isDash || dashCount < c.rules.maxDash;

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Crown / koz row — fixed height so seats stay aligned when empty.
          SizedBox(
            height: 20,
            child: Text(
              crown ? '👑' : (koz ? '🤡' : ''),
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Text(
            c.players[index],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          // Running total, right under the name: what this seat is playing
          // from, readable without scrolling down to the sheet.
          Text(
            '${s.total.toUpperCase()} ${totals[index]}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: kMono,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: crown
                  ? AppColors.gold
                  : (koz ? AppColors.red : AppColors.dim),
            ),
          ),
          const SizedBox(height: 6),
          // Calling is one press: the number opens the pad and the estimate is
          // picked outright. The steppers stay on the tricks screen, where
          // counting up one at a time is how the hand actually plays out.
          if (!isBid)
            _StepButton(
              label: '+',
              enabled: !isDash,
              onTap: () => c.step(index, 1),
            ),
          _NumberTarget(
            enabled: !isDash,
            max: c.rules.tricks,
            selected: value,
            allow: (n) => c.canPick(index, n),
            framed: isBid,
            onPicked: (n) => c.setValue(index, n),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                isDash ? '\u2014' : (unset ? '\u00b7' : '$value'),
                style: numberStyle(
                  size: 52,
                  color: (unset || isDash) ? AppColors.faint : AppColors.gold,
                ),
              ),
            ),
          ),
          if (!isBid)
            _StepButton(
              label: '\u2212',
              enabled: !isDash,
              onTap: () => c.step(index, -1),
            ),
          const SizedBox(height: 7),

          // On the tricks screen, what this player actually called — big
          // enough to read across the table without leaning in.
          if (!isBid)
            Container(
              margin: const EdgeInsets.only(bottom: 5),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.raise,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: AppColors.line),
              ),
              child: Text(
                c.working.dash[index]
                    ? s.dash
                    : '${s.called} ${c.working.bids[index] ?? '-'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: kMono,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ),

          // The Caller / With / Dash badge.
          SizedBox(
            height: 24,
            child: badge == null
                ? null
                : Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      '★ ${badge.toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: AppColors.onGold,
                      ),
                    ),
                  ),
          ),

          // The Risk badge: who carries it, and whether it is a plain or a
          // double risk. Stays up through the tricks — it is still theirs.
          SizedBox(
            height: 20,
            child: riskTag == null
                ? null
                : Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.red.withOpacity(0.16),
                      border: Border.all(color: AppColors.red),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      '⚠ ${riskTag.toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: labelStyle(size: 9, color: AppColors.red),
                    ),
                  ),
          ),
          if (isBid) ...[
            const SizedBox(height: 5),
            // Who won the bidding is said out loud at the table, so it is
            // pressed here rather than guessed from the numbers.
            Row(
              children: [
                Expanded(
                  child: _TagButton(
                    label: s.caller,
                    selected: chosenCaller == index,
                    enabled: !isDash,
                    onTap: () => c.setCaller(index),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: _TagButton(
                    label: s.dash,
                    selected: isDash,
                    enabled: canDash,
                    onTap: () => c.toggleDash(index),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Tapping the big number opens a compact 0..[max] pad anchored to it,
/// so a seven is one tap instead of seven. Numbers [allow] refuses are struck
/// out in place — the pad shows why a number is gone instead of hiding it.
class _NumberTarget extends StatelessWidget {
  final Widget child;
  final bool enabled;
  final int max;
  final int? selected;
  final bool Function(int) allow;

  /// Draw a border around the number so it reads as the button it is. Used on
  /// the estimate screen, where there are no steppers to hint at it.
  final bool framed;
  final ValueChanged<int> onPicked;

  const _NumberTarget({
    required this.child,
    required this.enabled,
    required this.max,
    required this.selected,
    required this.allow,
    required this.onPicked,
    this.framed = false,
  });

  Future<void> _open(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;

    final anchor = Rect.fromPoints(
      box.localToGlobal(Offset.zero, ancestor: overlay),
      box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
    );

    final picked = await showMenu<int>(
      context: context,
      color: AppColors.raise,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.line),
      ),
      // Anchor to the tapped number; showMenu clamps to the screen edges.
      position: RelativeRect.fromRect(anchor, Offset.zero & overlay.size),
      items: [
        PopupMenuItem<int>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              // Five 30px cells + gaps — three tidy rows for 0..13.
              width: 5 * 30 + 4 * 5,
              child: Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  for (var n = 0; n <= max; n++)
                    _PadCell(
                      value: n,
                      selected: n == selected,
                      enabled: allow(n),
                      onTap: () => Navigator.pop(context, n),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    if (picked != null) onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    final body = framed
        ? Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(10),
            ),
            child: child,
          )
        : child;
    if (!enabled) return body;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _open(context),
      child: body,
    );
  }
}

class _PadCell extends StatelessWidget {
  final int value;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _PadCell({
    required this.value,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Struck through and sunk into the background: still there, plainly not
    // on offer.
    return Material(
      color: selected
          ? AppColors.gold
          : (enabled ? AppColors.surface : AppColors.bg),
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Center(
            child: Text(
              '$value',
              style: numberStyle(
                size: 15,
                color: selected
                    ? AppColors.onGold
                    : (enabled ? AppColors.text : AppColors.faint),
              ).copyWith(
                decoration: enabled ? null : TextDecoration.lineThrough,
                decorationColor: AppColors.faint,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  const _StepButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.22,
      child: Material(
        color: AppColors.raise,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: enabled ? onTap : null,
          child: Container(
            width: double.infinity,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: kMono,
                fontSize: 19,
                color: AppColors.text,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small on/off declaration under a seat: Caller, Dash. Filled when set.
class _TagButton extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  const _TagButton({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.25,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.gold : Colors.transparent,
            border: Border.all(color: AppColors.gold),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: labelStyle(
              size: 9,
              color: selected ? AppColors.onGold : AppColors.gold,
            ),
          ),
        ),
      ),
    );
  }
}

/// Live total / over-under / risk readout.
class StatBar extends StatelessWidget {
  final GameController c;
  final bool isBid;
  const StatBar({super.key, required this.c, required this.isBid});

  @override
  Widget build(BuildContext context) {
    final s = c.s;
    final d = c.derived;
    final shown = isBid ? d.total : c.trickSum;
    final ou = OverUnder.of(c);
    final hasRisk = d.riskLevel > 0 && d.riskIndex >= 0;
    final bad = isBid
        ? (c.bidsComplete && d.total == c.rules.tricks)
        : (c.tricksComplete && c.trickSum != c.rules.tricks);

    Widget cell(String label, String value, Color color, {double size = 18}) =>
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(label, style: labelStyle(size: 9)),
                const SizedBox(height: 4),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: numberStyle(size: size, color: color)),
              ],
            ),
          ),
        );

    return Row(
      children: [
        cell(s.total, '$shown', bad ? AppColors.red : AppColors.text),
        const SizedBox(width: 8),
        cell(s.direction, ou.full.toUpperCase(), ou.color, size: 16),
        const SizedBox(width: 8),
        // Risk cell: the seat carrying it up top, what they are carrying below.
        cell(
          hasRisk ? c.players[d.riskIndex].toUpperCase() : s.risk,
          hasRisk ? s.riskLabel(d.riskLevel).toUpperCase() : '—',
          hasRisk ? AppColors.red : AppColors.dim,
        ),
      ],
    );
  }
}

/// Where the table stands against 13 — over, under, and by how much. The
/// direction is live while estimating and stays pinned while the tricks come
/// in, since it is what a dash gets paid on.
class OverUnder {
  final String word;
  final String amount;
  final Color color;
  const OverUnder(this.word, this.amount, this.color);

  factory OverUnder.of(GameController c) {
    final s = c.s;
    final diff = c.callDiff;
    if (!c.anyBidEntered) {
      return const OverUnder('—', '', AppColors.dim);
    }
    if (diff == 0) {
      // Exactly 13 is not a legal table; flag it rather than pick a side.
      return OverUnder('=${c.rules.tricks}', '', AppColors.red);
    }
    return diff > 0
        ? OverUnder(s.over, '+$diff', AppColors.gold)
        : OverUnder(s.under, '-${-diff}', AppColors.green);
  }

  String get full => amount.isEmpty ? word : '$word $amount';
}

/// Compact over/under badge for the top bar, so the call is readable from
/// across the table without hunting for the stat row.
class OverUnderPill extends StatelessWidget {
  final GameController c;
  const OverUnderPill({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    final ou = OverUnder.of(c);
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ou.color.withOpacity(0.16),
        border: Border.all(color: ou.color.withOpacity(0.55)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        ou.full.toUpperCase(),
        style: TextStyle(
          fontFamily: kMono,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: ou.color,
        ),
      ),
    );
  }
}

/// Trump picker, shown only when the caller gets to choose.
class TrumpRow extends StatelessWidget {
  final GameController c;
  const TrumpRow({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final su in Suit.values) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => c.setTrump(su),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.working.trump == su
                      ? AppColors.gold
                      : AppColors.surface,
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  su.symbol,
                  style: TextStyle(
                    fontSize: 20,
                    color: c.working.trump == su
                        ? AppColors.onGold
                        : (su.isRed ? AppColors.red : AppColors.text),
                  ),
                ),
              ),
            ),
          ),
          if (su != Suit.values.last) const SizedBox(width: 7),
        ],
      ],
    );
  }
}

/// Running scoreboard. Tap a row to edit that round.
class Scoreboard extends StatelessWidget {
  final GameController c;
  const Scoreboard({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    final s = c.s;
    final totals = c.totals;
    final best = totals.isEmpty ? 0 : totals.reduce((a, b) => a > b ? a : b);

    TextStyle head() => labelStyle(size: 9);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Text(s.scoreboard, style: labelStyle()),
        const SizedBox(height: 10),
        Row(
          children: [
            SizedBox(width: 40, child: Text('#', style: head())),
            for (final p in c.players)
              Expanded(
                child: Text(p.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: head()),
              ),
          ],
        ),
        const Divider(color: AppColors.line, height: 14),
        if (c.rounds.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(s.noRounds,
                textAlign: TextAlign.center,
                style: labelStyle(color: AppColors.faint)),
          ),
        for (var i = 0; i < c.rounds.length; i++) _row(context, i),
        const Divider(color: AppColors.line, height: 18),
        Row(
          children: [
            SizedBox(width: 40, child: Text('\u03a3', style: head())),
            for (var i = 0; i < totals.length; i++)
              Expanded(
                child: Text(
                  '${totals[i]}',
                  textAlign: TextAlign.center,
                  style: numberStyle(
                    size: 17,
                    color: (c.rounds.isNotEmpty && totals[i] == best)
                        ? AppColors.gold
                        : AppColors.text,
                  ),
                ),
              ),
          ],
        ),
        if (c.rounds.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(s.tapToEdit,
              textAlign: TextAlign.center,
              style: labelStyle(size: 9, color: AppColors.faint)),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _row(BuildContext context, int i) {
    final r = c.rounds[i];
    // Who carried the Risk that round, and how heavy it was.
    final d = derive(r, c.rules);
    return InkWell(
      onTap: () => c.editRound(i),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              child: Row(
                children: [
                  Text('${i + 1}',
                      style: labelStyle(size: 11, color: AppColors.faint)),
                  if (r.mult > 1)
                    Container(
                      margin: const EdgeInsets.only(left: 3),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text('\u00d7${r.mult}',
                          style: const TextStyle(
                              fontFamily: kMono,
                              fontSize: 8,
                              color: AppColors.onGold)),
                    ),
                ],
              ),
            ),
            for (var k = 0; k < c.playerCount; k++)
              Expanded(
                child: Column(
                  children: [
                    Text(
                      _scoreText(r, k),
                      style: TextStyle(
                        fontFamily: kMono,
                        fontSize: 12,
                        color: _scoreColor(r, k),
                      ),
                    ),
                    _detail(r, k,
                        risk: (!r.skipped && d.riskIndex == k && d.riskLevel > 0)
                            ? c.s.riskLabel(d.riskLevel)
                            : null),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _scoreText(Round r, int k) {
    if (k >= r.scores.length) return '0';
    final v = r.scores[k];
    return v > 0 ? '+$v' : '$v';
  }

  Color _scoreColor(Round r, int k) {
    if (k >= r.scores.length) return AppColors.dim;
    final v = r.scores[k];
    if (v > 0) return AppColors.green;
    if (v < 0) return AppColors.red;
    return AppColors.dim;
  }

  /// Estimate → tricks for one seat, with the Risk tag (1R / 2R) appended in
  /// red when that seat carried it.
  Widget _detail(Round r, int k, {String? risk}) {
    const base =
        TextStyle(fontFamily: kMono, fontSize: 9, color: AppColors.faint);
    if (r.skipped) return const Text('—', style: base);
    final bid = r.dash[k] ? 'dash' : '${r.bids[k] ?? '-'}';
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: '$bid→${r.tricks[k] ?? '-'}'),
          if (risk != null)
            TextSpan(
              text: ' $risk',
              style: const TextStyle(
                  color: AppColors.red, fontWeight: FontWeight.w700),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// --------------------------------------------------------------------- logo

/// The app mark, drawn rather than shipped as an asset so it stays sharp at
/// any size and follows the theme. Four cards fanned — four seats — with the
/// front one gold. Matches design/logo.svg.
class LogoMark extends StatelessWidget {
  final double size;
  const LogoMark({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _FanPainter()),
    );
  }
}

class _FanPainter extends CustomPainter {
  // Geometry in the same 512 box as design/logo.svg, so the two cannot drift.
  static const _rots = [-32.0, -10.5, 11.0, 32.5];
  static const _cardW = 164.0, _cardH = 232.0, _radius = 22.0, _stroke = 13.0;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 512;
    canvas.save();
    canvas.scale(k);
    canvas.translate(256, 350);

    final fill = Paint()..color = const Color(0xFF132229);
    final gold = Paint()..color = AppColors.gold;
    final edge = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke;

    for (var i = 0; i < _rots.length; i++) {
      final front = i == _rots.length - 1;
      canvas.save();
      canvas.rotate(_rots[i] * 3.1415926535 / 180);
      final r = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-_cardW / 2, -_cardH, _cardW, _cardH),
        const Radius.circular(_radius),
      );
      canvas.drawRRect(r, front ? gold : fill);
      canvas.drawRRect(r, edge);
      if (front) _spade(canvas);
      canvas.restore();
    }
    canvas.restore();
  }

  /// The pip on the gold face, in the card's own frame.
  void _spade(Canvas canvas) {
    canvas.save();
    canvas.translate(0, -116);
    canvas.scale(1.08);
    canvas.translate(-50, -54);
    final p = Path()
      ..moveTo(50, 12)
      ..cubicTo(31, 33, 13, 44, 13, 60)
      ..cubicTo(13, 72, 22, 80, 33, 80)
      ..cubicTo(40, 80, 46, 76, 49, 70)
      ..cubicTo(48, 82, 44, 90, 36, 95)
      ..lineTo(64, 95)
      ..cubicTo(56, 90, 52, 82, 51, 70)
      ..cubicTo(54, 76, 60, 80, 67, 80)
      ..cubicTo(78, 80, 87, 72, 87, 60)
      ..cubicTo(87, 44, 69, 33, 50, 12)
      ..close();
    canvas.drawPath(p, Paint()..color = AppColors.bg);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FanPainter oldDelegate) => false;
}

// ------------------------------------------------------------- dash window

/// How long the table has to declare a dash at the top of a round.
const int kDashWindowSeconds = 15;

/// Opens as each round starts. A dash is called out loud before anyone
/// estimates, so the round holds still for a moment and offers the four seats
/// — tap whoever says it. Closes itself when the countdown runs out.
class DashWindow extends StatefulWidget {
  final GameController c;
  const DashWindow({super.key, required this.c});

  static Future<void> show(BuildContext context, GameController c) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.62),
      // The dialog is pushed above the Directionality that wraps the app, so
      // it has to be told the language's direction itself.
      builder: (_) => Directionality(
        textDirection: c.arabic ? TextDirection.rtl : TextDirection.ltr,
        child: DashWindow(c: c),
      ),
    );
  }

  @override
  State<DashWindow> createState() => _DashWindowState();
}

class _DashWindowState extends State<DashWindow> {
  int left = kDashWindowSeconds;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      // Unmounted means the dialog is already gone — nothing left to close.
      if (!mounted) return;
      setState(() => left--);
      if (left <= 0) {
        _tick?.cancel();
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final s = c.s;
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final dashed = c.working.dash;
        final count = dashed.where((x) => x).length;
        final full = count >= c.rules.maxDash;
        final urgent = left <= 5;

        return Dialog(
          backgroundColor: AppColors.surface,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.line),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.dashWindow,
                              style: const TextStyle(
                                  fontSize: 21, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 3),
                            Text(s.dashWindowHint, style: labelStyle(size: 10)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // The clock, in the same mono as every other number.
                      Text(
                        '$left',
                        style: numberStyle(
                          size: 40,
                          color: urgent ? AppColors.red : AppColors.gold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: left / kDashWindowSeconds,
                      minHeight: 4,
                      backgroundColor: AppColors.raise,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          urgent ? AppColors.red : AppColors.gold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (var i = 0; i < c.playerCount; i++) ...[
                        Expanded(
                          child: _DashPick(
                            name: c.players[i],
                            selected: dashed[i],
                            // Only as many dashes as the rules allow. The ones
                            // already chosen stay pressable, so a seat that
                            // spoke too soon can take it back.
                            enabled: dashed[i] || !full,
                            onTap: () => c.toggleDash(i),
                          ),
                        ),
                        if (i < c.playerCount - 1) const SizedBox(width: 8),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          count == 0
                              ? s.dashWindowNone
                              : '${s.dash.toUpperCase()} ×$count',
                          style: labelStyle(
                            size: 10,
                            color: count == 0 ? AppColors.dim : AppColors.gold,
                          ),
                        ),
                      ),
                      _DialogButton(
                        label: s.done,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One seat inside the dash window: big enough to hit across the table.
class _DashPick extends StatelessWidget {
  final String name;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  const _DashPick({
    required this.name,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.3,
      child: Material(
        color: selected ? AppColors.gold : AppColors.raise,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? onTap : null,
          child: Container(
            height: 54,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: selected ? AppColors.gold : AppColors.line),
            ),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.onGold : AppColors.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DialogButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.gold,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.onGold,
            ),
          ),
        ),
      ),
    );
  }
}
