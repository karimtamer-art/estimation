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
  List<int> ladder; // sa'aydeh: next round x2, then x3

  // HOUSE rule — not in the published ruleset
  bool houseAllEqualDouble; // everyone estimated the same -> x2 + re-estimate

  Rules({
    required this.tricks,
    required this.minCallerBid,
    required this.maxDash,
    required this.superCallMin,
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
    required this.ladder,
    required this.houseAllEqualDouble,
  });

  factory Rules.defaults() => Rules(
        tricks: 13,
        minCallerBid: 4,
        maxDash: 2,
        superCallMin: 8,
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
        ladder: const [2, 3],
        houseAllEqualDouble: true,
      );

  Map<String, dynamic> toJson() => {
        'tricks': tricks,
        'minCallerBid': minCallerBid,
        'maxDash': maxDash,
        'superCallMin': superCallMin,
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
        'ladder': ladder,
        'houseAllEqualDouble': houseAllEqualDouble,
      };

  factory Rules.fromJson(Map<String, dynamic> j) {
    final d = Rules.defaults();
    int i(String k, int f) => (j[k] as num?)?.toInt() ?? f;
    bool b(String k, bool f) => j[k] as bool? ?? f;
    return Rules(
      tricks: i('tricks', d.tricks),
      minCallerBid: i('minCallerBid', d.minCallerBid),
      maxDash: i('maxDash', d.maxDash),
      superCallMin: i('superCallMin', d.superCallMin),
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
      ladder: (j['ladder'] as List?)?.map((e) => (e as num).toInt()).toList() ??
          List<int>.from(d.ladder),
      houseAllEqualDouble: b('houseAllEqualDouble', d.houseAllEqualDouble),
    );
  }
}
