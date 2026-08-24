import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'rules.dart';
import 'scoring.dart';
import 'strings.dart';

enum Screen { home, setup, bid, tricks, result, done, settings, setupPlayers }

const _kStoreKey = 'estimation_state_v1';

class GameController extends ChangeNotifier {
  Rules rules = Rules.defaults();
  bool arabic = false;

  Screen screen = Screen.home;
  Screen _previous = Screen.home;

  GameMode mode = GameMode.full;
  List<String> players = ['', '', '', ''];
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
  int get currentMult => pendingMult * working.houseMult;

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
    screen = Screen.home;
    notifyListeners();
    _save();
  }

  /// Home -> length setup. Names come after, on their own screen.
  void toSetup() {
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
      rounds.isNotEmpty || screen == Screen.bid || screen == Screen.tricks;

  /// Back into a game already in progress, at whichever half of the round was
  /// left unfinished.
  void resumeGame() {
    screen = bidsComplete ? Screen.tricks : Screen.bid;
    notifyListeners();
    _save();
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
    players[i] = name;
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

  void startGame() {
    for (var i = 0; i < players.length; i++) {
      if (players[i].trim().isEmpty) players[i] = 'P${i + 1}';
    }
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
  bool canPick(int player, int value) {
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

    final caller = working.caller;
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

  /// Mark which seat won the bidding. Pressing the same seat again clears it,
  /// which hands the Caller back to whoever holds the highest estimate.
  void setCaller(int player) {
    if (working.dash[player]) return; // a dashed seat called nothing
    working.caller = working.caller == player ? null : player;
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
    lastMessage = streak > 0 ? '${s.allMissed} \u00d7$pendingMult' : null;
    screen = Screen.result;
    notifyListeners();
    _save();
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
    final c = recomputeAll(rounds, rules, playerCount, s);
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
        rounds = (j['rounds'] as List?)
                ?.map((e) => Round.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        screen = Screen.values[(j['screen'] as num?)?.toInt() ?? Screen.setup.index];
        if (screen == Screen.settings || screen == Screen.result) {
          screen = rounds.isEmpty ? Screen.setup : Screen.bid;
        }
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
          'rounds': rounds.map((r) => r.toJson()).toList(),
          'working': working.toJson(),
          'screen': screen.index,
        }),
      );
    } catch (_) {
      // Persistence is best-effort; never block play on it.
    }
  }
}
