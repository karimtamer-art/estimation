import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'rules.dart';
import 'scoring.dart';
import 'strings.dart';

enum Screen { home, setup, bid, tricks, result, done, settings, setupPlayers }

/// The estimate screen is walked in order, the way the table actually plays
/// it: hold the dash window, then press who won the bidding, then that seat
/// picks the trump and says what it will make, then everyone else estimates.
/// Each step unlocks the next, so a round can no longer reach the tricks with
/// nobody named as Caller and no trump on the table.
enum BidStep { dash, caller, trump, callerBid, table, ready }

const _kStoreKey = 'estimation_state_v1';

class GameController extends ChangeNotifier {
  Rules rules = Rules.defaults();
  bool arabic = false;

  Screen screen = Screen.home;
  Screen _previous = Screen.home;

  GameMode mode = GameMode.full;
  List<String> players = ['', '', '', ''];

  /// Names being typed on the setup screen. Kept apart from [players] so a new
  /// game starts on blank seats without touching the names of the game still
  /// sitting there to be resumed.
  List<String> draftPlayers = ['', '', '', ''];

  List<Round> rounds = [];

  /// Round currently being entered.
  late Round working = Round.empty(4);

  /// Index being edited, or null when appending a new round.
  int? editingIndex;

  int pendingMult = 1;
  int streak = 0;

  RoundResult? lastResult;
  String? lastMessage;

  /// Which round the result screen is showing (an edit may not be the last).
  int resultIndex = 0;

  /// Raised when a fresh round opens: the table gets a fixed window to declare
  /// a dash before anyone estimates. UI state, so it is never persisted — a
  /// game resumed mid-round does not reopen the window.
  bool dashPromptPending = false;

  /// True once, for the one build that should open the dash window. Lowering
  /// the flag here keeps a rebuild from stacking a second dialog.
  bool takeDashPrompt() {
    if (!dashPromptPending) return false;
    dashPromptPending = false;
    return true;
  }

  Str get s => Str(arabic);

  int get playerCount => players.length;
  int get playedCount => rounds.where((r) => !r.skipped).length;
  /// Three or more seats on the highest call, in a round the rule covers.
  /// Read live off the round being called, so the table sees the double land
  /// while they are still calling rather than when the hand is scored.
  bool get sameCallDouble => sameHighestCall(
        working,
        rules,
        isColorRound: isColorRound,
        trump: lockedTrump ?? working.trump,
      );

  int get currentMult {
    final base = pendingMult * working.houseMult;
    if (!sameCallDouble) return base;
    final m = rules.sameHighestCallMult;
    if (m < 1) return base;
    if (rules.sameHighestCallStacks) return base * m;
    return base < m ? m : base;
  }

  /// Trump is locked in color rounds unless someone super calls.
  bool get superCalled {
    for (var i = 0; i < working.bids.length; i++) {
      final b = working.bids[i];
      if (!working.dash[i] && b != null && b >= rules.superCallMin) return true;
    }
    return false;
  }

  int get _roundIndex => editingIndex ?? playedCount;
  Suit? get lockedTrump {
    final f = mode.fixedTrump(_roundIndex);
    return (f != null && !superCalled) ? f : null;
  }

  /// A trailing round with its trump fixed by [kColorOrder]. The colors run in
  /// a known order, so the table already knows what is coming and does not
  /// need the dash window held open for it.
  bool get isColorRound => mode.fixedTrump(_roundIndex) != null;

  Derived get derived => derive(working, rules);

  bool get bidsComplete {
    for (var i = 0; i < working.bids.length; i++) {
      if (!working.dash[i] && working.bids[i] == null) return false;
    }
    return true;
  }

  bool get tricksComplete => !working.tricks.contains(null);

  int get trickSum =>
      working.tricks.fold<int>(0, (a, b) => a + (b ?? 0));

  /// How far the table's estimates sit from 13. Positive is over, negative is
  /// under, zero is the illegal exact-13 table.
  int get callDiff => derived.total - rules.tricks;

  /// True once at least one seat has settled, so over/under means something.
  /// Before that the table is trivially "under" by 13 and saying so is noise.
  bool get anyBidEntered {
    for (var i = 0; i < working.bids.length; i++) {
      if (working.dash[i] || working.bids[i] != null) return true;
    }
    return false;
  }

  bool get allEqualEstimates {
    if (!rules.houseAllEqualDouble || !bidsComplete) return false;
    final live = <int>[];
    for (var i = 0; i < working.bids.length; i++) {
      if (working.dash[i]) return false; // a dash breaks the pattern
      live.add(working.bids[i]!);
    }
    return live.length == playerCount && live.every((b) => b == live.first);
  }

  /// Where the estimate screen has got to. Read off the round itself, so it
  /// survives a reload and an edit walks straight in at the end.
  BidStep get bidStep {
    if (screen != Screen.bid) return BidStep.ready;
    if (dashPromptPending) return BidStep.dash;
    final caller = working.caller;
    if (caller == null) return BidStep.caller;
    if ((lockedTrump ?? working.trump) == null) return BidStep.trump;
    if (!working.dash[caller] && working.bids[caller] == null) {
      return BidStep.callerBid;
    }
    if (!bidsComplete) return BidStep.table;
    return BidStep.ready;
  }

  /// Whether [seat] may be given a number yet. The table is held until the
  /// Caller and the trump are settled, and then the Caller goes first — its
  /// call is the one every other estimate is measured against.
  bool canEstimate(int seat) {
    if (screen != Screen.bid) return true;
    switch (bidStep) {
      case BidStep.dash:
      case BidStep.caller:
      case BidStep.trump:
        return false;
      case BidStep.callerBid:
        return seat == working.caller;
      case BidStep.table:
      case BidStep.ready:
        return true;
    }
  }

  /// Validation message for the current entry screen, or null if it's clean.
  String? get validationError {
    if (screen == Screen.bid) {
      if (!bidsComplete) return null;
      if (allEqualEstimates) return s.errAllEqual;
      final d = derived;
      if (d.total == rules.tricks) return s.errTotal13;
      if (d.top != null && d.top! < rules.minCallerBid) {
        return '${s.errMinCaller} ${rules.minCallerBid}.';
      }
      // A round does not start until the table has said who called it and
      // under which trump. Both are pressed, never inferred.
      final chosen = working.caller;
      if (chosen == null) return s.errNoCaller;
      if ((lockedTrump ?? working.trump) == null) return s.errNoTrump;
      // Pressing Caller on a seat that someone has outbid means either the
      // press or an estimate is wrong. The pad cannot prevent it — the press
      // can come after the numbers — so say it out loud.
      if (!working.dash[chosen]) {
        final callerBid = working.bids[chosen];
        for (var i = 0; callerBid != null && i < playerCount; i++) {
          if (i == chosen || working.dash[i]) continue;
          final b = working.bids[i];
          if (b != null && b > callerBid) return s.errCallerNotTop;
        }
      }
    } else if (screen == Screen.tricks) {
      if (!tricksComplete) return null;
      if (trickSum != rules.tricks) return s.errTricksSum;
    }
    return null;
  }

  List<int> get totals => List<int>.generate(
        playerCount,
        (i) => rounds.fold<int>(0, (a, r) => a + (i < r.scores.length ? r.scores[i] : 0)),
      );

  /// Seat wearing the crown: the outright highest total. Null until a round has
  /// been scored, and null on a tie — nobody is king while it is shared.
  int? get leaderIndex => _extremeIndex(highest: true);

  /// Seat wearing the koz: the outright lowest total. Same tie rule.
  int? get laggardIndex => _extremeIndex(highest: false);

  int? _extremeIndex({required bool highest}) {
    if (playedCount == 0) return null;
    final t = totals;
    var best = t[0];
    for (final v in t) {
      if (highest ? v > best : v < best) best = v;
    }
    final holders = <int>[];
    for (var i = 0; i < t.length; i++) {
      if (t[i] == best) holders.add(i);
    }
    // A crown shared by everyone marks nothing useful.
    if (holders.length != 1) return null;
    return holders.first;
  }

  void goHome() {
    // Remember what was left running, so Home still offers to go back into it
    // even before a single round has been scored.
    _resumeTarget = _resumableFrom(screen) ?? _resumeTarget;
    screen = Screen.home;
    notifyListeners();
    _save();
  }

  /// Home -> length setup. Names come after, on their own screen, and they
  /// start blank: a new table is not last week's table.
  void toSetup() {
    draftPlayers = List<String>.filled(playerCount, '');
    screen = Screen.setup;
    notifyListeners();
    _save();
  }

  /// Length picked -> name the seats.
  void toPlayers() {
    screen = Screen.setupPlayers;
    notifyListeners();
    _save();
  }

  /// Back from names to the length picker.
  void backToSetup() {
    screen = Screen.setup;
    notifyListeners();
    _save();
  }

  /// True once a game is under way, so Home can offer to resume it.
  bool get hasGameInProgress =>
      rounds.isNotEmpty ||
      _resumeTarget != null ||
      screen == Screen.bid ||
      screen == Screen.tricks;

  /// Back into a game already in progress, at whichever half of the round was
  /// left unfinished — or at the screen it was left on, when that screen is
  /// where the game actually stands.
  void resumeGame() {
    final target = _resumeTarget;
    _resumeTarget = null;
    if (target == Screen.result || target == Screen.done) {
      screen = target!;
    } else {
      screen = bidsComplete ? Screen.tricks : Screen.bid;
    }
    notifyListeners();
    _save();
  }

  /// Where Resume goes. Set when the table steps away from a live game —
  /// pressing Home, or closing the app — and cleared once they step back in.
  Screen? _resumeTarget;

  /// Which screen a game left mid-flight should come back to, or null when
  /// [s] is not part of a game in progress.
  static Screen? _resumableFrom(Screen s) {
    switch (s) {
      case Screen.bid:
      case Screen.tricks:
        return Screen.bid; // resumeGame picks the right half of the round
      case Screen.result:
      case Screen.done:
        return s;
      default:
        return null;
    }
  }

  // ----------------------------------------------------------------- actions

  void setMode(GameMode m) {
    mode = m;
    notifyListeners();
    _save();
  }

  /// The length picker is one tap: choosing a length is also the Next button.
  void chooseMode(GameMode m) {
    mode = m;
    screen = Screen.setupPlayers;
    notifyListeners();
    _save();
  }

  void setPlayer(int i, String name) {
    draftPlayers[i] = name;
    _save();
  }

  void toggleLanguage() {
    arabic = !arabic;
    _recompute();
    notifyListeners();
    _save();
  }

  void openSettings() {
    _previous = screen;
    screen = Screen.settings;
    notifyListeners();
  }

  void closeSettings() {
    screen = _previous;
    notifyListeners();
    _save();
  }

  void resetRules() {
    rules = Rules.defaults();
    _recompute();
    notifyListeners();
    _save();
  }

  void ruleChanged() {
    _recompute();
    notifyListeners();
    _save();
  }

  /// The draft becomes the table. A seat left blank is named for its number.
  ///
  /// Pressing Start is the one unambiguous "this is a new game", so the sheet
  /// is wiped here: the rounds, the multiplier the last game was carrying, and
  /// the offer to resume it. Walking into setup and thinking better of it
  /// never gets this far, so a game can still be backed out of and resumed.
  void startGame() {
    for (var i = 0; i < players.length; i++) {
      final name = i < draftPlayers.length ? draftPlayers[i].trim() : '';
      players[i] = name.isEmpty ? 'P${i + 1}' : name;
    }
    rounds = [];
    pendingMult = 1;
    streak = 0;
    lastResult = null;
    lastMessage = null;
    resultIndex = 0;
    _resumeTarget = null;
    _beginRound();
  }

  /// The seat took exactly what it called — the ordinary end to a hand, and
  /// the one number nobody should have to hunt for on the pad. A dashed seat
  /// called nothing, so making it means taking none.
  void madeBid(int player) {
    working.tricks[player] = working.bids[player] ?? 0;
    notifyListeners();
    _save();
  }

  /// Whether [player] may be given [value] on the screen currently open.
  /// The pad greys out everything this refuses, so a number the round's rules
  /// forbid is never entered and then rejected a step later.
  /// [asCaller] weighs the number as if this seat had the call, which is how
  /// the call panel offers its numbers: the seat is not the Caller yet, but
  /// the number it is about to confirm has to survive the Caller's rules.
  bool canPick(int player, int value, {bool asCaller = false}) {
    if (value < 0 || value > rules.tricks) return false;
    final list = screen == Screen.tricks ? working.tricks : working.bids;

    // What the rest of the table has already settled, and how many have not.
    var settled = 0;
    var pending = 0;
    for (var i = 0; i < playerCount; i++) {
      if (i == player) continue;
      if (screen == Screen.bid && working.dash[i]) continue;
      final v = list[i];
      if (v == null) {
        pending++;
      } else {
        settled += v;
      }
    }

    if (screen == Screen.tricks) {
      // Thirteen tricks exist and all of them are won: never more, and the
      // last seat to fill in gets only the number that completes the table.
      if (settled + value > rules.tricks) return false;
      if (pending == 0) return settled + value == rules.tricks;
      return true;
    }

    final caller = asCaller ? player : working.caller;
    if (caller != null && caller != player) {
      // Nobody outbids the caller. Matching is fine — that is With.
      final callerBid = working.bids[caller];
      if (callerBid != null && value > callerBid) return false;
    }
    if (caller == player) {
      if (value < rules.minCallerBid) return false;
      // The call has to be the top of the table to be the call.
      for (var i = 0; i < playerCount; i++) {
        if (i == player || working.dash[i]) continue;
        final b = working.bids[i];
        if (b != null && b > value) return false;
      }
    }
    // The estimates may not land on exactly 13 — which is only knowable once
    // this seat is the last one left to settle.
    if (pending == 0 && settled + value == rules.tricks) return false;
    return true;
  }

  /// Set a player's number outright, as picked from the number pad.
  /// Same bookkeeping as [step] — dash clears and the player moves to the
  /// back of the estimate order, since they just settled.
  void setValue(int player, int value) {
    final isBid = screen == Screen.bid;
    final list = isBid ? working.bids : working.tricks;
    list[player] = value.clamp(0, rules.tricks);

    if (isBid) {
      working.dash[player] = false;
      working.order.remove(player);
      working.order.add(player);
    }
    notifyListeners();
    _save();
  }

  void toggleDash(int player) {
    final on = !working.dash[player];
    if (on && working.dash.where((d) => d).length >= rules.maxDash) return;
    // Dashing gives up on the round, so it cannot also be the call.
    if (on && working.caller == player) working.caller = null;
    working.dash[player] = on;
    working.bids[player] = on ? 0 : null;
    working.order.remove(player);
    if (!on) working.order.add(player);
    notifyListeners();
    _save();
  }

  /// The call, settled in one press of Confirm: who called it, under which
  /// trump, and for how many. A colour round hands [su] in as null, since its
  /// trump was never the caller's to pick.
  void applyCall(int player, Suit? su, int bid) {
    if (working.dash[player]) return;
    working.caller = player;
    if (su != null) working.trump = su;
    working.bids[player] = bid.clamp(0, rules.tricks);
    working.order.remove(player);
    working.order.add(player);
    notifyListeners();
    _save();
  }

  /// Hands the call back to nobody, leaving the trump where it was.
  void clearCaller() {
    working.caller = null;
    notifyListeners();
    _save();
  }

  void setTrump(Suit su) {
    working.trump = su;
    notifyListeners();
    _save();
  }

  void doubleAndRebid() {
    working.houseMult *= 2;
    working.bids = List<int?>.filled(playerCount, null);
    working.dash = List<bool>.filled(playerCount, false);
    working.order = [];
    working.caller = null;
    working.trump = null;
    // The re-estimate wipes the dashes with everything else, so the table gets
    // its window back to declare them again — in the rounds that hold one.
    dashPromptPending = !isColorRound;
    notifyListeners();
    _save();
  }

  void toTricks() {
    working.tricks = List<int?>.filled(playerCount, null);
    screen = Screen.tricks;
    notifyListeners();
    _save();
  }

  void backToBids() {
    screen = Screen.bid;
    notifyListeners();
  }

  void skipRound() {
    final r = Round.empty(playerCount)..skipped = true;
    rounds.add(r);
    _recompute();
    resultIndex = rounds.length - 1;
    lastResult = null;
    lastMessage = '${s.skipped} \u00d7$pendingMult';
    screen = Screen.result;
    notifyListeners();
    _save();
  }

  void commit() {
    working.trump = lockedTrump ?? working.trump;
    working.skipped = false;

    final target = editingIndex ?? rounds.length;
    if (editingIndex != null) {
      rounds[editingIndex!] = working.copy();
    } else {
      rounds.add(working.copy());
    }
    editingIndex = null;
    _recompute();

    final done = rounds[target];
    resultIndex = target;
    lastResult = RoundResult(done.scores, done.lines, streak > 0, derive(done, rules));
    // What the table needs told: the round that just carried, or - failing
    // that - why the round they just played was worth more than face value.
    lastMessage = streak > 0
        ? '${s.allMissed} \u00d7$pendingMult'
        : (_sameCallOn(target)
            ? '${s.sharedTopCall} \u00d7${done.mult}'
            : null);
    screen = Screen.result;
    notifyListeners();
    _save();
  }

  /// Whether the round at [index] doubled on the shared-top-call rule. The
  /// Color rounds are counted off the rounds actually played, so a round the
  /// table passed does not shift which trump a later round was dealt under.
  bool _sameCallOn(int index) {
    final r = rounds[index];
    if (r.skipped) return false;
    var played = 0;
    for (var i = 0; i < index; i++) {
      if (!rounds[i].skipped) played++;
    }
    return sameHighestCall(
      r,
      rules,
      isColorRound: mode.fixedTrump(played) != null,
      trump: r.trump,
    );
  }

  void continueAfterResult() {
    if (playedCount >= mode.totalRounds) {
      screen = Screen.done;
      notifyListeners();
      _save();
    } else {
      _beginRound();
    }
  }

  void undoLast() {
    if (rounds.isEmpty) return;
    rounds.removeLast();
    _recompute();
    _beginRound(prompt: false);
  }

  void editRound(int i) {
    final r = rounds[i];
    if (r.skipped) return;
    editingIndex = i;
    working = r.copy();
    screen = Screen.bid;
    notifyListeners();
  }

  void newGame() {
    draftPlayers = List<String>.filled(playerCount, '');
    _resumeTarget = null;
    rounds = [];
    editingIndex = null;
    pendingMult = 1;
    streak = 0;
    lastResult = null;
    screen = Screen.setup;
    working = Round.empty(playerCount);
    notifyListeners();
    _save();
  }

  /// [prompt] opens the dash window. Undo re-opens a round the table has
  /// already sat through, so it comes back without one.
  void _beginRound({bool prompt = true}) {
    working = Round.empty(playerCount);
    editingIndex = null;
    screen = Screen.bid;
    dashPromptPending = prompt && !isColorRound;
    _recompute();
    notifyListeners();
    _save();
  }

  void _recompute() {
    final c = recomputeAll(rounds, rules, playerCount, s, mode: mode);
    pendingMult = c.pendingMult;
    streak = c.streak;
  }

  // -------------------------------------------------------------- persistence

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kStoreKey);
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        rules = Rules.fromJson(j['rules'] as Map<String, dynamic>? ?? {});
        arabic = j['arabic'] as bool? ?? false;
        mode = GameMode.values[(j['mode'] as num?)?.toInt() ?? GameMode.full.index];
        players = (j['players'] as List?)?.map((e) => e as String).toList() ??
            ['', '', '', ''];
        draftPlayers = (j['draft'] as List?)?.map((e) => e as String).toList() ??
            List<String>.filled(players.length, '');
        rounds = (j['rounds'] as List?)
                ?.map((e) => Round.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        // The app always comes back on Home. Reopening it — or the tab —
        // should not drop the table straight into a round nobody asked for;
        // what was running waits behind Resume instead.
        //
        // It also matters for the round that was already scored: coming back
        // into its estimates would let the same round be committed twice.
        final stored =
            Screen.values[(j['screen'] as num?)?.toInt() ?? Screen.home.index];
        _resumeTarget = _resumableFrom(stored) ??
            (j['resume'] == null
                ? null
                : _resumableFrom(
                    Screen.values[(j['resume'] as num).toInt()]));
        screen = Screen.home;
        final w = j['working'];
        working = w == null
            ? Round.empty(players.length)
            : Round.fromJson(w as Map<String, dynamic>);
      }
    } catch (_) {
      // Corrupt or old payload — fall back to a clean slate.
      rules = Rules.defaults();
      rounds = [];
      screen = Screen.setup;
      working = Round.empty(4);
    }
    _recompute();
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kStoreKey,
        jsonEncode({
          'rules': rules.toJson(),
          'arabic': arabic,
          'mode': mode.index,
          'players': players,
          'draft': draftPlayers,
          'rounds': rounds.map((r) => r.toJson()).toList(),
          'working': working.toJson(),
          'screen': screen.index,
          'resume': _resumeTarget?.index,
        }),
      );
    } catch (_) {
      // Persistence is best-effort; never block play on it.
    }
  }
}
