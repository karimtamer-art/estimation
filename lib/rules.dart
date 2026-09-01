import 'models.dart';

/// Every scoring constant lives here. Nothing else in the app hard-codes a
/// number. Edit these (or the in-app settings screen) without touching logic.
///
/// Ruleset: Pocket Estimation (Egyptian). Scoring is ADDITIVE — each component
/// below is added or subtracted independently, then the whole round is
/// multiplied by the round multiplier.
class Rules {
  int tricks;
  int minCallerBid;
  int maxDash;
  int superCallMin;

  // A call at or above [superCallMin] is a Super Call. It does two unrelated
  // things: it unlocks the trump in a Color round, and — when this is on — it
  // is scored on its own formula instead of the Caller one.
  //
  //   made it  -> +call^2
  //   missed   -> -(call^2 ~/ superCallLossDiv)
  //
  // The square REPLACES the round score, the tricks and the Caller bonus; a
  // miss is priced off the call alone, never off how far the seat landed from
  // it. Risk, the sole bonus and the round multiplier still apply on top.
  bool superCallOwnScore;
  int superCallLossDiv;

  // Scoring components
  int roundScore; // every player: win +n / loss -n
  int callerOrWith; // win +n / loss -n
  int perRisk; // win +n / loss -n, per risk level
  int soleBonus; // +n only winner, -n only loser
  int dashOver; // dash call, round total >= tricks + 1
  int dashUnder; // dash call, round total <= tricks - 1

  // Ambiguous in the published table — confirm against the app
  bool lossTricksIsDiff; // true: -|eaten - estimate|, false: -(estimate)
  bool dashStacksRound; // dash also collects roundScore
  bool dashStacksSole; // dash also collects soleBonus

  bool allMissZero; // nobody made their bid -> round scores 0

  // Sa'aydeh, the two ways a round can carry into the next one.
  int passMult; // all passed -> the next round is worth this, and no more
  int missMultiply; // nobody made it -> what is on the table is multiplied

  // Three or more seats sharing the HIGHEST call doubles the round. Not the
  // total, not any three matching numbers — the top of the table, shared.
  // Egyptian table rule for the fixed-trump Color rounds. Deliberately not
  // called Tasbeet: that word is a different bidding idea.
  bool sameHighestCallDouble; // the rule on or off
  int sameHighestCallMin; // how many must share the top call
  int sameHighestCallMult; // what the round is multiplied by when they do
  bool sameHighestCallColorOnly; // Color rounds only, or the whole game
  bool sameHighestCallStacks; // multiply what is already running, or floor it
  List<Suit> sameHighestCallSuits; // which trumps it is played under

  // HOUSE rule — not in the published ruleset
  bool houseAllEqualDouble; // everyone estimated the same -> x2 + re-estimate

  Rules({
    required this.tricks,
    required this.minCallerBid,
    required this.maxDash,
    required this.superCallMin,
    required this.superCallOwnScore,
    required this.superCallLossDiv,
    required this.roundScore,
    required this.callerOrWith,
    required this.perRisk,
    required this.soleBonus,
    required this.dashOver,
    required this.dashUnder,
    required this.lossTricksIsDiff,
    required this.dashStacksRound,
    required this.dashStacksSole,
    required this.allMissZero,
    required this.passMult,
    required this.missMultiply,
    required this.sameHighestCallDouble,
    required this.sameHighestCallMin,
    required this.sameHighestCallMult,
    required this.sameHighestCallColorOnly,
    required this.sameHighestCallStacks,
    required this.sameHighestCallSuits,
    required this.houseAllEqualDouble,
  });

  factory Rules.defaults() => Rules(
        tricks: 13,
        minCallerBid: 4,
        maxDash: 2,
        superCallMin: 8,
        superCallOwnScore: true,
        superCallLossDiv: 2,
        roundScore: 10,
        callerOrWith: 10,
        perRisk: 10,
        soleBonus: 10,
        dashOver: 25,
        dashUnder: 33,
        lossTricksIsDiff: true,
        dashStacksRound: false,
        dashStacksSole: false,
        allMissZero: true,
        passMult: 2,
        missMultiply: 2,
        sameHighestCallDouble: true,
        sameHighestCallMin: 3,
        sameHighestCallMult: 2,
        sameHighestCallColorOnly: true,
        // Stacking is a decision, not an accident: on, a x2 already running
        // becomes x4. Turn it off and the round is simply worth at least the
        // doubled value instead.
        sameHighestCallStacks: true,
        sameHighestCallSuits: const [...kColorOrder],
        houseAllEqualDouble: true,
      );

  Map<String, dynamic> toJson() => {
        'tricks': tricks,
        'minCallerBid': minCallerBid,
        'maxDash': maxDash,
        'superCallMin': superCallMin,
        'superCallOwnScore': superCallOwnScore,
        'superCallLossDiv': superCallLossDiv,
        'roundScore': roundScore,
        'callerOrWith': callerOrWith,
        'perRisk': perRisk,
        'soleBonus': soleBonus,
        'dashOver': dashOver,
        'dashUnder': dashUnder,
        'lossTricksIsDiff': lossTricksIsDiff,
        'dashStacksRound': dashStacksRound,
        'dashStacksSole': dashStacksSole,
        'allMissZero': allMissZero,
        'passMult': passMult,
        'missMultiply': missMultiply,
        'sameHighestCallDouble': sameHighestCallDouble,
        'sameHighestCallMin': sameHighestCallMin,
        'sameHighestCallMult': sameHighestCallMult,
        'sameHighestCallColorOnly': sameHighestCallColorOnly,
        'sameHighestCallStacks': sameHighestCallStacks,
        'sameHighestCallSuits': [for (final su in sameHighestCallSuits) su.name],
        'houseAllEqualDouble': houseAllEqualDouble,
      };

  factory Rules.fromJson(Map<String, dynamic> j) {
    final d = Rules.defaults();
    int i(String k, int f) => (j[k] as num?)?.toInt() ?? f;
    bool b(String k, bool f) => j[k] as bool? ?? f;
    List<Suit> suits(String k, List<Suit> f) {
      final raw = j[k] as List?;
      if (raw == null) return List<Suit>.from(f);
      return [
        for (final name in raw)
          for (final su in Suit.values)
            if (su.name == name) su,
      ];
    }
    return Rules(
      tricks: i('tricks', d.tricks),
      minCallerBid: i('minCallerBid', d.minCallerBid),
      maxDash: i('maxDash', d.maxDash),
      superCallMin: i('superCallMin', d.superCallMin),
      superCallOwnScore: b('superCallOwnScore', d.superCallOwnScore),
      superCallLossDiv: i('superCallLossDiv', d.superCallLossDiv),
      roundScore: i('roundScore', d.roundScore),
      callerOrWith: i('callerOrWith', d.callerOrWith),
      perRisk: i('perRisk', d.perRisk),
      soleBonus: i('soleBonus', d.soleBonus),
      dashOver: i('dashOver', d.dashOver),
      dashUnder: i('dashUnder', d.dashUnder),
      lossTricksIsDiff: b('lossTricksIsDiff', d.lossTricksIsDiff),
      dashStacksRound: b('dashStacksRound', d.dashStacksRound),
      dashStacksSole: b('dashStacksSole', d.dashStacksSole),
      allMissZero: b('allMissZero', d.allMissZero),
      passMult: i('passMult', d.passMult),
      missMultiply: i('missMultiply', d.missMultiply),
      sameHighestCallDouble:
          b('sameHighestCallDouble', d.sameHighestCallDouble),
      sameHighestCallMin: i('sameHighestCallMin', d.sameHighestCallMin),
      sameHighestCallMult: i('sameHighestCallMult', d.sameHighestCallMult),
      sameHighestCallColorOnly:
          b('sameHighestCallColorOnly', d.sameHighestCallColorOnly),
      sameHighestCallStacks:
          b('sameHighestCallStacks', d.sameHighestCallStacks),
      sameHighestCallSuits: suits('sameHighestCallSuits',
          d.sameHighestCallSuits),
      houseAllEqualDouble: b('houseAllEqualDouble', d.houseAllEqualDouble),
    );
  }
}
