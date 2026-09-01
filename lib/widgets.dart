import 'dart:async';

import 'package:flutter/material.dart';

import 'controller.dart';
import 'models.dart';
import 'scoring.dart';
import 'strings.dart';
import 'theme.dart';

/// The crown or the koz for one seat, wherever the standing is shown: on the
/// seats through the round, on the running sheet, on the sheet after it is
/// scored. Empty space of the same height when the seat is neither out front
/// nor dead last, so a row of seats stays aligned — and nothing at all while
/// the lead is shared, since a mark everyone wears says nothing.
class RankMark extends StatelessWidget {
  final GameController c;
  final int index;
  final double size;
  const RankMark({
    super.key,
    required this.c,
    required this.index,
    this.size = 26,
  });

  @override
  Widget build(BuildContext context) {
    final crown = c.leaderIndex == index;
    final koz = c.laggardIndex == index;
    if (!crown && !koz) return SizedBox(height: size);
    return Image.asset(
      crown ? 'assets/crown.png' : 'assets/koz.png',
      height: size,
      semanticLabel: crown ? c.s.king : c.s.koz,
      filterQuality: FilterQuality.medium,
    );
  }
}

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
    // Caller and With are worn through the tricks as well as the estimate —
    // who is playing for what does not stop mattering once the cards are out.
    var isWith = false;
    if (isDash) {
      badge = s.dash;
    } else if (d.callerOrWith[index] && d.top != null) {
      isWith = chosenCaller != null
          ? chosenCaller != index
          : d.callerOrWith.where((x) => x).length > 1;
      badge = isWith ? s.with_ : s.caller;
    }

    final riskTag = (index == d.riskIndex && d.riskLevel > 0)
        ? s.riskLabel(d.riskLevel)
        : null;

    // Both badge rows are held open across the whole table or not at all, so
    // the seats stay level — but an empty row is not held open at all, which
    // is what keeps the tricks screen on one screenful.
    final anyRisk = d.riskLevel > 0 && d.riskIndex >= 0;
    final anyBadge = c.working.dash.any((x) => x) ||
        (d.top != null && d.callerOrWith.any((x) => x));

    final totals = c.totals;
    // Crown to the outright leader, koz to the outright last place.
    final crown = c.leaderIndex == index;
    final koz = c.laggardIndex == index;

    final dashCount = c.working.dash.where((x) => x).length;
    final canDash = isDash || dashCount < c.rules.maxDash;

    // The seat the round is waiting on, so the table knows where to look.
    final awaited =
        isBid && c.bidStep == BidStep.callerBid && c.working.caller == index;

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: awaited ? Border.all(color: AppColors.gold, width: 2) : null,
        boxShadow: awaited
            ? [
                BoxShadow(
                  color: AppColors.gold.withOpacity(0.28),
                  blurRadius: 16,
                )
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Crown / koz row — fixed height so seats stay aligned when empty.
          RankMark(c: c, index: index, size: 26),
          Text(
            c.players[index],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
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
          const SizedBox(height: 4),
          // On the estimate screen the number is a read-out, not a target: it
          // is settled on the call panel, behind the buttons below.
          if (isBid)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                isDash ? '\u2014' : (unset ? '\u00b7' : '$value'),
                style: numberStyle(
                  size: 44,
                  color: (unset || isDash) ? AppColors.faint : AppColors.gold,
                ),
              ),
            )
          else
            // Counting tricks is still one press: the number opens the pad and
            // the value is picked outright, never nudged.
            _NumberTarget(
              enabled: !isDash,
              max: c.rules.tricks,
              selected: value,
              allow: (n) => c.canPick(index, n),
              onPicked: (n) => c.setValue(index, n),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  isDash ? '\u2014' : (unset ? '\u00b7' : '$value'),
                  style: numberStyle(
                    size: 44,
                    color: (unset || isDash) ? AppColors.faint : AppColors.gold,
                  ),
                ),
              ),
            ),
          // The seat that took exactly what it called: one press instead of
          // hunting for its own number on the pad.
          if (!isBid)
            _MadeButton(
              label: s.gotThem,
              selected: value != null && value == c.working.bids[index],
              // Held back when the call would put the table past thirteen —
              // the same rule that strikes the number out on the pad.
              enabled: c.canPick(index, c.working.bids[index] ?? 0),
              onTap: () => c.madeBid(index),
            ),
          const SizedBox(height: 5),

          // On the tricks screen, what this player actually called — big
          // enough to read across the table without leaning in.
          if (!isBid)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ),

          // The Caller / With / Dash badge. With is blue: the seat riding
          // along with the call reads apart from the seat that made it.
          if (anyBadge)
            SizedBox(
              height: 22,
              child: badge == null
                  ? null
                  : Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isWith ? AppColors.blue : AppColors.gold,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        '${isWith ? '◆' : '★'} ${badge.toUpperCase()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: isWith ? AppColors.onBlue : AppColors.onGold,
                        ),
                      ),
                    ),
            ),


          // The Risk badge: who carries it, and whether it is a plain or a
          // double risk. Stays up through the tricks — it is still theirs.
          // No risk anywhere on the table and the row is not held open.
          if (anyRisk)
            SizedBox(
              height: 19,
              child: riskTag == null
                  ? null
                  : Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.red,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        '⚠ ${riskTag.toUpperCase()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        // Filled like the Caller and With badges beside it —
                        // the three things a seat wears read as one set: gold
                        // for the call, blue for With, red for the Risk.
                        style: labelStyle(size: 9, color: AppColors.onRed),
                      ),
                    ),
            ),
          if (isBid) ...[
            const SizedBox(height: 5),
            // Everything a seat can say about the round: it won the bidding,
            // it is fixing its number, or it dashed — the last one still open
            // for a seat that missed the window.
            //
            // A Color round takes both of the outer two away. Nobody presses
            // the call there, because the highest estimate simply takes it,
            // and a Color round cannot be dashed at all. That leaves the seat
            // with one thing to say, so Edit says it alone.
            Row(
              children: [
                if (!c.isColorRound) ...[
                  Expanded(
                    child: _TagButton(
                      label: s.caller,
                      selected: chosenCaller == index,
                      enabled: !isDash,
                      onTap: () =>
                          CallPanel.show(context, c, index, asCaller: true),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: _TagButton(
                    label: s.edit,
                    selected: false,
                    // Nothing to fix until the call and the trump are down.
                    enabled: !isDash && c.canEstimate(index),
                    onTap: () =>
                        CallPanel.show(context, c, index, asCaller: false),
                  ),
                ),
                if (!c.isColorRound) ...[
                  const SizedBox(width: 4),
                  Expanded(
                    child: _TagButton(
                      label: s.dash,
                      selected: isDash,
                      enabled: canDash,
                      onTap: () => c.toggleDash(index),
                    ),
                  ),
                ],
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

  final ValueChanged<int> onPicked;

  const _NumberTarget({
    required this.child,
    required this.enabled,
    required this.max,
    required this.selected,
    required this.allow,
    required this.onPicked,
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
    if (!enabled) return child;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _open(context),
      child: child,
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

/// "Got them" under a seat on the tricks screen: fills in the estimate the
/// seat called, and lights up while the number still matches it.
class _MadeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  const _MadeButton({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled || selected ? 1 : 0.3,
      child: Material(
        color: selected ? AppColors.gold : AppColors.raise,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: enabled ? onTap : null,
          child: Container(
            width: double.infinity,
            height: 34,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              border:
                  Border.all(color: selected ? AppColors.gold : AppColors.line),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.onGold : AppColors.text,
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
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(label, style: labelStyle(size: 9)),
                const SizedBox(height: 3),
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
        // The sheet wears the standing too: crown over whoever is out front,
        // koz over whoever is propping it up, on every screen that shows it.
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SizedBox(width: 40, child: Text('#', style: head())),
            for (var i = 0; i < c.players.length; i++)
              Expanded(
                child: Column(
                  children: [
                    RankMark(c: c, index: i, size: 22),
                    const SizedBox(height: 3),
                    Text(c.players[i].toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: head()),
                  ],
                ),
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
                // Signed, and coloured by its sign: a seat can see whether it
                // is up or down on the game without reading the number.
                child: _TotalCell(
                  value: totals[i],
                  leading: c.rounds.isNotEmpty && totals[i] == best,
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 3, vertical: 1),
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
                        risk:
                            (!r.skipped && d.riskIndex == k && d.riskLevel > 0)
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

/// One seat's total on the foot of the sheet. The seat out front keeps a gold
/// pill around it; the number itself is green when it is up, red when down.
class _TotalCell extends StatelessWidget {
  final int value;
  final bool leading;
  const _TotalCell({required this.value, required this.leading});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: leading
          ? BoxDecoration(
              color: AppColors.gold.withOpacity(0.14),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.gold.withOpacity(0.55)),
            )
          : null,
      child: Text(
        signed(value),
        textAlign: TextAlign.center,
        style: numberStyle(size: 17, color: signColor(value)),
      ),
    );
  }
}

// -------------------------------------------------------------- bid steps

/// What the round is being played under. A Color round never asked the table
/// for a trump — it hands one over — so the app has to say which one it is
/// before a single estimate goes down. It used to say nothing at all, and the
/// table walked into a Spades round picking a caller with no idea.
class TrumpBanner extends StatelessWidget {
  final GameController c;
  const TrumpBanner({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    final s = c.s;
    final locked = c.lockedTrump;
    final su = locked ?? c.working.trump;
    if (su == null) return const SizedBox.shrink();
    final forced = locked != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      decoration: BoxDecoration(
        // A forced trump wears the gold: it is not a choice anyone made and
        // should not read like one.
        color: forced ? AppColors.gold.withOpacity(0.12) : AppColors.surface,
        border: Border.all(color: forced ? AppColors.gold : AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            su.symbol,
            style: TextStyle(
              fontSize: 34,
              height: 1,
              color: su.isRed ? AppColors.red : AppColors.text,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  su.label(c.arabic),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  forced
                      ? '${s.colorRoundOf(c.colorRoundNumber, c.mode.colorRounds)}'
                          ' · ${s.trumpForced}'
                      : s.trump,
                  maxLines: 2,
                  style: labelStyle(
                      size: 9,
                      color: forced ? AppColors.gold : AppColors.dim),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The order the estimate screen is walked in, drawn as four beads with the
/// live one lit and the line under them saying what the table does next.
/// Nothing further down the screen opens until its bead is reached.
class StepStrip extends StatelessWidget {
  final GameController c;
  const StepStrip({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    final s = c.s;
    final step = c.bidStep;
    // The dash window is skipped in the colour rounds, where the trump is
    // already known and there is nothing to wait for.
    final beads = c.isColorRound
        // Nothing is settled before the numbers in a Color round: no window,
        // no call to press. Only a super call puts a trump back on the path.
        ? <BidStep>[
            if (c.lockedTrump == null) BidStep.trump,
            BidStep.table,
          ]
        : <BidStep>[
            BidStep.dash,
            BidStep.caller,
            if (c.lockedTrump == null) BidStep.trump,
            BidStep.callerBid,
          ];
    final at = _rank(step);
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < beads.length; i++) ...[
                _Bead(
                  index: i + 1,
                  label: _short(s, beads[i]),
                  done: _rank(beads[i]) < at,
                  live: beads[i] == step,
                ),
                if (i < beads.length - 1)
                  Expanded(
                    child: Container(
                      height: 1.4,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      color: _rank(beads[i]) < at
                          ? AppColors.gold
                          : AppColors.line,
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _prompt(s, step),
            style: TextStyle(
              fontSize: 12,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: step == BidStep.ready ? AppColors.green : AppColors.text,
            ),
          ),
        ],
      ),
    );
  }

  /// How far along a step sits, so the beads behind the live one can be
  /// filled in.
  int _rank(BidStep s) => BidStep.values.indexOf(s);

  String _short(Str s, BidStep step) => switch (step) {
        BidStep.dash => s.dash,
        BidStep.caller => s.caller,
        BidStep.trump => s.trump,
        _ => s.estimate,
      };

  String _prompt(Str s, BidStep step) => switch (step) {
        BidStep.dash => s.stepDash,
        BidStep.caller => s.stepCaller,
        BidStep.trump => s.stepTrump,
        BidStep.callerBid => s.stepCallerBid,
        BidStep.table => s.stepTable,
        BidStep.ready => s.stepReady,
      };
}

/// One step of the strip. Behind the table it is a filled tick, ahead of it a
/// plain number; the step being answered right now is the only one that
/// spells itself out, which is also the only way four of them fit the panel.
class _Bead extends StatelessWidget {
  final int index;
  final String label;
  final bool done;
  final bool live;
  const _Bead({
    required this.index,
    required this.label,
    required this.done,
    required this.live,
  });

  @override
  Widget build(BuildContext context) {
    if (live) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.gold,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label.toUpperCase(),
          style: labelStyle(size: 9, color: AppColors.onGold),
        ),
      );
    }
    return Container(
      width: 19,
      height: 19,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: done ? AppColors.gold.withOpacity(0.18) : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: done ? AppColors.gold : AppColors.line,
          width: 1.2,
        ),
      ),
      child: Text(
        done ? '✓' : '$index',
        style: TextStyle(
          fontFamily: kMono,
          fontSize: 9,
          height: 1,
          color: done ? AppColors.gold : AppColors.faint,
        ),
      ),
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

// -------------------------------------------------------------- call panel

/// The panel a seat calls through: every number the round allows laid out at
/// once, the suits under them when the trump is the caller's to pick, and one
/// Confirm that settles the lot. Nothing is entered a digit at a time and
/// nothing is committed until Confirm — the table can back out of the whole
/// press.
class CallPanel extends StatefulWidget {
  final GameController c;
  final int seat;

  /// True when this seat is claiming the call, which is what puts the suits on
  /// the panel and holds the number to the Caller's rules.
  final bool asCaller;

  const CallPanel({
    super.key,
    required this.c,
    required this.seat,
    required this.asCaller,
  });

  static Future<void> show(
    BuildContext context,
    GameController c,
    int seat, {
    required bool asCaller,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.66),
      // Pushed above the Directionality that wraps the app, so it has to be
      // told the language's direction itself.
      builder: (_) => Directionality(
        textDirection: c.arabic ? TextDirection.rtl : TextDirection.ltr,
        child: CallPanel(c: c, seat: seat, asCaller: asCaller),
      ),
    );
  }

  @override
  State<CallPanel> createState() => _CallPanelState();
}

class _CallPanelState extends State<CallPanel> {
  int? _bid;
  Suit? _suit;

  GameController get c => widget.c;

  /// When this panel has to settle a trump as well as a number.
  ///
  /// Either the seat is taking the call in a round that has no trump yet, or
  /// the number it is about to say is a super call — which is the one thing
  /// that takes a Color round's trump back off it and hands it to the caller.
  /// Read off the number on the panel, not off the round, so the suits drop
  /// down the moment 8 is pressed rather than after Confirm.
  bool get _needsSuit {
    final bid = _bid;
    if (c.isColorRound) return bid != null && bid >= c.rules.superCallMin;
    return widget.asCaller && c.lockedTrump == null;
  }

  @override
  void initState() {
    super.initState();
    // Opens on whatever the seat already has, so an edit is a correction
    // rather than a re-entry.
    _bid = c.working.dash[widget.seat] ? null : c.working.bids[widget.seat];
    _suit = c.working.trump;
  }

  bool get _ready => _bid != null && (!_needsSuit || _suit != null);

  void _confirm() {
    if (!_ready) return;
    if (widget.asCaller) {
      c.applyCall(widget.seat, _needsSuit ? _suit : null, _bid!);
    } else {
      c.setValue(widget.seat, _bid!, trump: _needsSuit ? _suit : null);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = c.s;
    final isCaller = c.working.caller == widget.seat;
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.line),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      c.players[widget.seat],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 21, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    (widget.asCaller ? s.theCall : s.estimate).toUpperCase(),
                    style: labelStyle(
                        size: 10,
                        color:
                            widget.asCaller ? AppColors.gold : AppColors.dim),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(s.howMany, style: labelStyle(size: 10)),
              const SizedBox(height: 10),
              // 0..13 in two rows, every number the round allows on the panel
              // at once. What it refuses is struck out where it stands.
              for (final row in const [
                [0, 1, 2, 3, 4, 5, 6],
                [7, 8, 9, 10, 11, 12, 13],
              ]) ...[
                Row(
                  children: [
                    for (final n in row) ...[
                      Expanded(
                        child: _CallNumber(
                          value: n,
                          selected: _bid == n,
                          enabled: c.canPick(widget.seat, n,
                              asCaller: widget.asCaller),
                          onTap: () => setState(() => _bid = n),
                        ),
                      ),
                      if (n != row.last) const SizedBox(width: 6),
                    ],
                  ],
                ),
                if (row.first == 0) const SizedBox(height: 6),
              ],
              if (_needsSuit) ...[
                const Divider(color: AppColors.line, height: 22),
                Row(
                  children: [
                    for (final su in Suit.values) ...[
                      Expanded(
                        child: _CallSuit(
                          suit: su,
                          selected: _suit == su,
                          onTap: () => setState(() => _suit = su),
                        ),
                      ),
                      if (su != Suit.values.last) const SizedBox(width: 6),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  _PanelText(
                    label: s.cancel,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  // The call can be handed back from the same panel that
                  // took it, so a wrong press is one step to undo.
                  if (isCaller) ...[
                    const SizedBox(width: 4),
                    _PanelText(
                      label: s.clearCall,
                      danger: true,
                      onTap: () {
                        c.clearCaller();
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                  const Spacer(),
                  if (!_ready)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Text(
                        _bid == null ? s.howMany : s.pickTrumpFirst,
                        style: labelStyle(size: 9, color: AppColors.faint),
                      ),
                    ),
                  _ConfirmButton(
                    label: s.confirm,
                    enabled: _ready,
                    onTap: _confirm,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One number on the panel. Struck through and sunk into the background when
/// the round will not take it, the same way the old pad refused a number.
class _CallNumber extends StatelessWidget {
  final int value;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  const _CallNumber({
    required this.value,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.gold
          : (enabled ? AppColors.raise : AppColors.bg),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: enabled ? onTap : null,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: selected ? AppColors.gold : AppColors.line,
            ),
          ),
          child: Text(
            '$value',
            style: TextStyle(
              fontFamily: kMono,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              decoration: enabled ? null : TextDecoration.lineThrough,
              color: selected
                  ? AppColors.onGold
                  : (enabled ? AppColors.text : AppColors.faint),
            ),
          ),
        ),
      ),
    );
  }
}

/// One suit on the panel, in the colour it is played in.
class _CallSuit extends StatelessWidget {
  final Suit suit;
  final bool selected;
  final VoidCallback onTap;
  const _CallSuit({
    required this.suit,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.gold : AppColors.raise,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: selected ? AppColors.gold : AppColors.line, width: 1.4),
          ),
          child: Text(
            suit.symbol,
            style: TextStyle(
              fontSize: 22,
              color: selected
                  ? AppColors.onGold
                  : (suit.isRed ? AppColors.red : AppColors.text),
            ),
          ),
        ),
      ),
    );
  }
}

/// The quiet half of the panel's footer: Cancel, and handing back the call.
class _PanelText extends StatelessWidget {
  final String label;
  final bool danger;
  final VoidCallback onTap;
  const _PanelText(
      {required this.label, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: danger ? AppColors.red : AppColors.dim,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: const Size(0, 40),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: danger ? AppColors.red : AppColors.dim,
        ),
      ),
    );
  }
}

/// Confirm: the only way anything on the panel reaches the round.
class _ConfirmButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  const _ConfirmButton(
      {required this.label, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: Material(
        color: AppColors.gold,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? onTap : null,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 34),
            alignment: Alignment.center,
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
                color: AppColors.onGold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ score drawer

/// The sheet that lives off the top of the screen with only a little tab
/// hanging into view. Tap the tab, or pull it down, and the whole game — the
/// graph and the running sheet — comes down over whatever is underneath.
class ScoreDrawer extends StatefulWidget {
  final GameController c;
  const ScoreDrawer({super.key, required this.c});

  @override
  State<ScoreDrawer> createState() => _ScoreDrawerState();
}

class _ScoreDrawerState extends State<ScoreDrawer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    reverseDuration: const Duration(milliseconds: 240),
  );

  /// Height of the panel above the tab, needed to turn a drag in pixels into
  /// a fraction of the way open.
  double _panelHeight = 1;

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  void _toggle() => _a.value < 0.5 ? _a.forward() : _a.reverse();

  void _drag(DragUpdateDetails d) =>
      _a.value = (_a.value + d.primaryDelta! / _panelHeight).clamp(0.0, 1.0);

  void _dragEnd(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond.dy;
    if (v > 320) {
      _a.fling(velocity: 2);
    } else if (v < -320) {
      _a.fling(velocity: -2);
    } else if (_a.value > 0.5) {
      _a.forward();
    } else {
      _a.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return LayoutBuilder(
      builder: (context, box) {
        // Only as deep as the sheet it carries: the graph, the header and a
        // row per round, up to nearly the whole screen once a long game fills
        // it. Anything past that scrolls inside the panel.
        final wanted = 371.0 + c.rounds.length * 37.0;
        final h = wanted.clamp(240.0, box.maxHeight * 0.9);
        _panelHeight = h;
        return AnimatedBuilder(
          animation: _a,
          builder: (context, _) {
            final t = Curves.easeOutCubic.transform(_a.value);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Everything under the sheet dims as it comes down, and a tap
                // on it puts the sheet back.
                if (_a.value > 0.01)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _a.reverse,
                      child:
                          ColoredBox(color: Colors.black.withOpacity(0.6 * t)),
                    ),
                  ),
                Positioned(
                  top: -h * (1 - t),
                  left: 0,
                  right: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Nothing behind the tab is built while the sheet is
                      // shut — the sheet is a second copy of the scoresheet,
                      // and an unseen one should cost nothing.
                      SizedBox(
                        height: h,
                        child: _a.value > 0.001
                            ? _ScorePanel(c: c)
                            : const SizedBox.shrink(),
                      ),
                      // The tab rides on the bottom edge of the sheet, so it
                      // is the same handle whether the sheet is up or down.
                      Center(
                        child: GestureDetector(
                          onTap: _toggle,
                          onVerticalDragUpdate: _drag,
                          onVerticalDragEnd: _dragEnd,
                          child: ScoreTab(c: c, open: t),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// The little card hanging off the sheet: the round it is on, big enough to
/// read across a table, small enough to leave the game underneath alone.
class ScoreTab extends StatelessWidget {
  final GameController c;

  /// 0 shut, 1 all the way open — the arrow turns over as it travels.
  final double open;
  const ScoreTab({super.key, required this.c, this.open = 0});

  @override
  Widget build(BuildContext context) {
    final s = c.s;
    final done = c.playedCount >= c.mode.totalRounds;
    final n = done
        ? c.mode.totalRounds
        : (c.playedCount + 1).clamp(1, c.mode.totalRounds);
    const radius = BorderRadius.vertical(bottom: Radius.circular(9));
    final mult = c.currentMult;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _card(s, n, radius),
        // The round's multiplier rides on the corner of the tab, where the
        // table is already looking for the round number.
        if (mult > 1)
          Positioned(
            // Hung off the right edge rather than the top: at the top of the
            // screen there is nothing above the tab to hang into.
            right: -16,
            top: 5,
            child: MultBadge(mult: mult),
          ),
      ],
    );
  }

  Widget _card(Str s, int n, BorderRadius radius) {
    return Container(
      width: 62,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: const Color(0xFF120A02), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Red header strip, like the tab on a paper scorepad.
            Container(
              width: double.infinity,
              color: const Color(0xFFC0392B),
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                s.round.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: kMono,
                  fontSize: 7,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(0, 1, 0, 2),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFDF6E3), Color(0xFFD9C79A)],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$n',
                    style: const TextStyle(
                      fontFamily: kMono,
                      fontSize: 20,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1205),
                    ),
                  ),
                  // Points down when shut, up once the sheet is out.
                  Transform.rotate(
                    angle: 3.14159 * open,
                    child: const Text(
                      '▾',
                      style: TextStyle(
                          fontSize: 9, height: 1, color: Color(0xFF7A6A44)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The round multiplier, worn on the corner of the round tab. It only exists
/// while a round is worth more than face value, and it breathes while it is
/// there — a doubled round should be impossible to walk past.
class MultBadge extends StatefulWidget {
  final int mult;
  const MultBadge({super.key, required this.mult});

  @override
  State<MultBadge> createState() => _MultBadgeState();
}

class _MultBadgeState extends State<MultBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_pulse.value);
        return Transform.scale(
          scale: 1 + 0.07 * t,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFD766), Color(0xFFD08A12)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF3A2205), width: 1.6),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withOpacity(0.30 + 0.35 * t),
                  blurRadius: 8 + 8 * t,
                  spreadRadius: 0.5 * t,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.45),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      // The label itself never changes with the pulse, so it is built once.
      child: Text(
        '×${widget.mult}',
        style: const TextStyle(
          fontFamily: kMono,
          fontSize: 12,
          height: 1,
          fontWeight: FontWeight.w900,
          color: Color(0xFF1A1205),
          shadows: [
            Shadow(color: Color(0x55FFFFFF), offset: Offset(0, -1)),
          ],
        ),
      ),
    );
  }
}

/// What the tab pulls down: the graph over the running sheet.
class _ScorePanel extends StatelessWidget {
  final GameController c;
  const _ScorePanel({required this.c});

  @override
  Widget build(BuildContext context) {
    final s = c.s;
    final totals = c.totals;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
        border: const Border(
          bottom: BorderSide(color: AppColors.line, width: 2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.55),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 10, 0),
              child: Row(
                children: [
                  Text(s.scoreboard, style: labelStyle()),
                  const Spacer(),
                  for (var i = 0; i < c.playerCount; i++) ...[
                    _LegendChip(
                      name: c.players[i],
                      total: i < totals.length ? totals[i] : 0,
                      color: seatColor(i),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: SizedBox(height: 132, child: ScoreGraph(c: c)),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [Scoreboard(c: c)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One seat in the graph's key: its colour, its name, and where it stands —
/// green when it is up on the game, red when it is down.
class _LegendChip extends StatelessWidget {
  final String name;
  final int total;
  final Color color;
  const _LegendChip(
      {required this.name, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 64),
          child: Text(name.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: labelStyle(size: 9)),
        ),
        const SizedBox(width: 4),
        Text(
          signed(total),
          style: numberStyle(size: 12, color: signColor(total)),
        ),
      ],
    );
  }
}

/// A total with its sign on it, the way it reads on the paper sheet.
String signed(int v) => v > 0 ? '+$v' : '$v';

/// Green when a number is up, red when it is down, quiet at nothing.
Color signColor(int v) =>
    v > 0 ? AppColors.green : (v < 0 ? AppColors.red : AppColors.dim);

/// Every seat's running total, round by round, on one pair of axes: above the
/// line is a game in profit, below it is a game in the hole.
class ScoreGraph extends StatelessWidget {
  final GameController c;
  const ScoreGraph({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    if (c.rounds.isEmpty) {
      return Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: Text(c.s.noRounds, style: labelStyle(color: AppColors.faint)),
      );
    }
    // Cumulative totals, each series starting from nothing at round zero.
    final series = <List<double>>[];
    for (var i = 0; i < c.playerCount; i++) {
      var running = 0.0;
      final line = <double>[0];
      for (final r in c.rounds) {
        running += i < r.scores.length ? r.scores[i] : 0;
        line.add(running);
      }
      series.add(line);
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: CustomPaint(
          size: Size.infinite,
          painter: _ScoreGraphPainter(series: series),
        ),
      ),
    );
  }
}

class _ScoreGraphPainter extends CustomPainter {
  final List<List<double>> series;
  _ScoreGraphPainter({required this.series});

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 34.0, padR = 12.0, padT = 12.0, padB = 12.0;
    final w = size.width - padL - padR;
    final h = size.height - padT - padB;
    if (w <= 0 || h <= 0 || series.isEmpty) return;

    // Zero always sits on the axis, so up and down keep their meaning even
    // when every seat is on the same side of it.
    var lo = 0.0, hi = 0.0;
    for (final line in series) {
      for (final v in line) {
        if (v < lo) lo = v;
        if (v > hi) hi = v;
      }
    }
    if (hi - lo < 20) {
      hi += 10;
      lo -= 10;
    }
    final pad = (hi - lo) * 0.12;
    hi += pad;
    lo -= pad;

    double y(double v) => padT + h * (1 - (v - lo) / (hi - lo));
    double x(int i) =>
        padL +
        (series.first.length == 1 ? 0 : w * i / (series.first.length - 1));

    final zeroY = y(0);

    // The two halves of the game, tinted so which side of the line a seat is
    // on can be read without following the numbers.
    canvas.drawRect(
      Rect.fromLTRB(padL, padT, padL + w, zeroY),
      Paint()..color = AppColors.green.withOpacity(0.10),
    );
    canvas.drawRect(
      Rect.fromLTRB(padL, zeroY, padL + w, padT + h),
      Paint()..color = AppColors.red.withOpacity(0.11),
    );

    // The zero line itself, dashed so it reads as an axis, not a score.
    final axis = Paint()
      ..color = AppColors.faint
      ..strokeWidth = 1;
    for (var dx = padL; dx < padL + w; dx += 7) {
      canvas.drawLine(Offset(dx, zeroY),
          Offset((dx + 4).clamp(padL, padL + w), zeroY), axis);
    }

    _label(
        canvas, '+${hi.round()}', const Offset(4, padT - 5), AppColors.faint);
    _label(canvas, '0', Offset(4, zeroY - 5), AppColors.dim);
    _label(canvas, '${lo.round()}', Offset(4, padT + h - 5), AppColors.faint);

    // One round per gridline, kept faint enough to stay behind the lines.
    final grid = Paint()
      ..color = AppColors.line.withOpacity(0.5)
      ..strokeWidth = 1;
    for (var i = 1; i < series.first.length; i++) {
      canvas.drawLine(Offset(x(i), padT), Offset(x(i), padT + h), grid);
    }

    for (var sIdx = 0; sIdx < series.length; sIdx++) {
      final line = series[sIdx];
      final color = seatColor(sIdx);
      final path = Path()..moveTo(x(0), y(line[0]));
      for (var i = 1; i < line.length; i++) {
        path.lineTo(x(i), y(line[i]));
      }
      // A soft pass of the same colour under the line, so four lines crossing
      // each other still separate.
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..color = color.withOpacity(0.18),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
      // Where the seat stands right now.
      final end = Offset(x(line.length - 1), y(line.last));
      canvas.drawCircle(end, 4.5, Paint()..color = AppColors.bg);
      canvas.drawCircle(end, 3.2, Paint()..color = color);
    }
  }

  void _label(Canvas canvas, String text, Offset at, Color color) {
    TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontFamily: kMono, fontSize: 8, color: color),
      ),
      textDirection: TextDirection.ltr,
    )
      ..layout()
      ..paint(canvas, at);
  }

  @override
  bool shouldRepaint(_ScoreGraphPainter old) => true;
}
