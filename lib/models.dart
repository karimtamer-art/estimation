enum Suit { sun, spades, hearts, diamonds, clubs }

extension SuitInfo on Suit {
  String get symbol => const {
        Suit.sun: '\u2600',
        Suit.spades: '\u2660',
        Suit.hearts: '\u2665',
        Suit.diamonds: '\u2666',
        Suit.clubs: '\u2663',
      }[this]!;

  String label(bool ar) => ar
      ? const {
          Suit.sun: 'صن',
          Suit.spades: 'بستوني',
          Suit.hearts: 'كوبة',
          Suit.diamonds: 'ديناري',
          Suit.clubs: 'سباتي',
        }[this]!
      : const {
          Suit.sun: 'Sun',
          Suit.spades: 'Spades',
          Suit.hearts: 'Hearts',
          Suit.diamonds: 'Diamonds',
          Suit.clubs: 'Clubs',
        }[this]!;

  bool get isRed => this == Suit.hearts || this == Suit.diamonds;
}

/// Trump order for the final "color" rounds, strongest first.
const List<Suit> kColorOrder = [
  Suit.sun,
  Suit.spades,
  Suit.hearts,
  Suit.diamonds,
  Suit.clubs,
];

enum GameMode { micro, mini, full }

extension ModeInfo on GameMode {
  /// Rounds where the caller picks trump.
  int get normalRounds => const {
        GameMode.micro: 5,
        GameMode.mini: 5,
        GameMode.full: 13,
      }[this]!;

  /// Trailing rounds with trump locked to [kColorOrder].
  int get colorRounds => const {
        GameMode.micro: 0,
        GameMode.mini: 5,
        GameMode.full: 5,
      }[this]!;

  int get totalRounds => normalRounds + colorRounds;

  /// Micro and Mini are house lengths; only Full is in the published ruleset.
  bool get isHouse => this != GameMode.full;

  String label(bool ar) => ar
      ? const {
          GameMode.micro: 'ميكرو',
          GameMode.mini: 'ميني',
          GameMode.full: 'كاملة',
        }[this]!
      : const {
          GameMode.micro: 'Micro',
          GameMode.mini: 'Mini',
          GameMode.full: 'Full',
        }[this]!;

  /// Trump for round [index], or null when the caller chooses it.
  ///
  /// [index] is allowed to sit past the last round: the app asks what the
  /// NEXT round is dealt under, and once the game is over there is no next
  /// round. Answering with a range error there blanked the end screen, so the
  /// end of the Color order is a null like any other round the caller owns.
  Suit? fixedTrump(int index) {
    if (index < normalRounds) return null;
    final i = index - normalRounds;
    return i < colorRounds ? kColorOrder[i] : null;
  }
}

/// One line of a player's score breakdown, e.g. "Caller / With  +10".
class ScoreLine {
  final String label;
  final int value;
  const ScoreLine(this.label, this.value);
}

class Round {
  List<int?> bids;
  List<bool> dash;

  /// Player indices in the order they settled their estimate. The last entry
  /// carries the Risk, because they are the one forced away from 13.
  List<int> order;

  /// The seat that won the bidding, once someone presses Caller. Null means
  /// nobody said, and the caller falls back to whoever holds the highest
  /// estimate — the rule this app used before the button existed.
  int? caller;

  List<int?> tricks;
  Suit? trump;
  int houseMult;
  bool skipped;

  // Filled in by recomputeAll().
  int mult;
  List<int> scores;
  List<List<ScoreLine>> lines;

  Round({
    required this.bids,
    required this.dash,
    required this.order,
    required this.tricks,
    this.caller,
    this.trump,
    this.houseMult = 1,
    this.skipped = false,
    this.mult = 1,
    List<int>? scores,
    List<List<ScoreLine>>? lines,
  })  : scores = scores ?? [],
        lines = lines ?? [];

  factory Round.empty(int n) => Round(
        bids: List<int?>.filled(n, null),
        dash: List<bool>.filled(n, false),
        order: <int>[],
        tricks: List<int?>.filled(n, null),
      );

  Round copy() => Round(
        bids: List<int?>.from(bids),
        dash: List<bool>.from(dash),
        order: List<int>.from(order),
        tricks: List<int?>.from(tricks),
        caller: caller,
        trump: trump,
        houseMult: houseMult,
        skipped: skipped,
        mult: mult,
        scores: List<int>.from(scores),
      );

  Map<String, dynamic> toJson() => {
        'bids': bids,
        'dash': dash,
        'order': order,
        'tricks': tricks,
        'caller': caller,
        'trump': trump?.index,
        'houseMult': houseMult,
        'skipped': skipped,
      };

  factory Round.fromJson(Map<String, dynamic> j) => Round(
        bids: (j['bids'] as List).map((e) => (e as num?)?.toInt()).toList(),
        dash: (j['dash'] as List).map((e) => e as bool).toList(),
        order: (j['order'] as List).map((e) => (e as num).toInt()).toList(),
        tricks: (j['tricks'] as List).map((e) => (e as num?)?.toInt()).toList(),
        caller: (j['caller'] as num?)?.toInt(),
        trump: j['trump'] == null ? null : Suit.values[(j['trump'] as num).toInt()],
        houseMult: (j['houseMult'] as num?)?.toInt() ?? 1,
        skipped: j['skipped'] as bool? ?? false,
      );
}
