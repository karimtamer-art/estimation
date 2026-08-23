import 'package:flutter/material.dart';

import 'controller.dart';
import 'models.dart';
import 'theme.dart';

/// One player's column: name, +, value, −, role tags, dash toggle.
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

    // The prominent badge: Caller / With / Dash. Derived, never chosen.
    String? badge;
    if (isDash) {
      badge = s.dash;
    } else if (isBid && d.callerOrWith[index] && d.top != null) {
      badge = d.callerOrWith.where((x) => x).length > 1 ? s.with_ : s.caller;
    }

    final riskTag = (isBid && index == d.riskIndex && d.riskLevel > 0)
        ? '${s.risk} \u00d7${d.riskLevel}'
        : null;

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
          const SizedBox(height: 6),
          _StepButton(
            label: '+',
            enabled: !isDash,
            onTap: () => c.step(index, 1),
          ),
          _NumberTarget(
            enabled: !isDash,
            max: c.rules.tricks,
            selected: value,
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

          SizedBox(
            height: 14,
            child: Text(
              riskTag ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: labelStyle(size: 10, color: AppColors.gold),
            ),
          ),
          if (isBid) ...[
            const SizedBox(height: 5),
            _DashButton(
              label: s.dash,
              selected: isDash,
              enabled: canDash,
              onTap: () => c.toggleDash(index),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tapping the big number opens a compact 0..[max] pad anchored to it,
/// so a seven is one tap instead of seven.
class _NumberTarget extends StatelessWidget {
  final Widget child;
  final bool enabled;
  final int max;
  final int? selected;
  final ValueChanged<int> onPicked;

  const _NumberTarget({
    required this.child,
    required this.enabled,
    required this.max,
    required this.selected,
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
      borderRadius: BorderRadius.circular(8),
      onTap: () => _open(context),
      child: child,
    );
  }
}

class _PadCell extends StatelessWidget {
  final int value;
  final bool selected;
  final VoidCallback onTap;

  const _PadCell({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.gold : AppColors.surface,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onTap,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Center(
            child: Text(
              '$value',
              style: numberStyle(
                size: 15,
                color: selected ? AppColors.onGold : AppColors.text,
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

class _DashButton extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  const _DashButton({
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
    final bad = isBid
        ? (c.bidsComplete && d.total == c.rules.tricks)
        : (c.tricksComplete && c.trickSum != c.rules.tricks);

    Widget cell(String label, String value, Color color) => Expanded(
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
                    style: numberStyle(size: 18, color: color)),
              ],
            ),
          ),
        );

    return Row(
      children: [
        cell(s.total, '$shown', bad ? AppColors.red : AppColors.text),
        const SizedBox(width: 8),
        cell(s.direction, d.over ? s.over : s.under, AppColors.text),
        const SizedBox(width: 8),
        cell(s.risk, d.riskLevel > 0 ? '\u00d7${d.riskLevel}' : '\u2014',
            d.riskLevel > 0 ? AppColors.gold : AppColors.dim),
      ],
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
                    Text(
                      _detailText(r, k),
                      style: const TextStyle(
                          fontFamily: kMono, fontSize: 9, color: AppColors.faint),
                    ),
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

  String _detailText(Round r, int k) {
    if (r.skipped) return '\u2014';
    final bid = r.dash[k] ? 'dash' : '${r.bids[k] ?? '-'}';
    return '$bid\u2192${r.tricks[k] ?? '-'}';
  }
}
