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

  /// Nudge a player's number. First press from unset lands on 0.
  void step(int player, int delta) {
    final isBid = screen == Screen.bid;
    final list = isBid ? working.bids : working.tricks;
    final cur = list[player];
    list[player] = cur == null ? 0 : (cur + delta).clamp(0, rules.tricks);

    if (isBid) {
      working.dash[player] = false;
      // Last player to settle their estimate carries the Risk.
      working.order.remove(player);
      working.order.add(player);
    }
    notifyListeners();
    _save();
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
    working.trump = null;
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
    _beginRound();
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

  void _beginRound() {
    working = Round.empty(playerCount);
    editingIndex = null;
    screen = Screen.bid;
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
