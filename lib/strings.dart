/// Minimal two-language string table. `Str(true)` gives Arabic.
class Str {
  final bool ar;
  const Str(this.ar);

  String _p(String en, String a) => ar ? a : en;

  /// The wordmark is two lines: the game, then what this app does with it.
  /// The icon keeps the short line alone — iOS clips a label past about a
  /// dozen characters.
  String get appName => _p('Estimation', 'إستيميشن');
  String get appSubName => _p('Calculator', 'حاسبة');
  String get round => _p('Round', 'جولة');
  String get of => _p('of', 'من');
  String get estimate => _p('estimate', 'التقدير');
  String get tricksWon => _p('tricks won', 'اللمات');
  String get dash => _p('Dash', 'داش');
  String get dashWindow => _p('Wait for dash', 'انتظروا الداش');
  String get dashWindowHint => _p('Anyone calling dash, say it now — tap them.',
      'اللي هيقول داش يقولها دلوقتي — اضغط عليه.');
  String get dashWindowNone => _p('Nobody dashed', 'محدش داش');
  String get back => _p('Back', 'رجوع');
  String get total => _p('total', 'المجموع');
  String get direction => _p('round', 'الجولة');
  String get risk => _p('Risk', 'ريسك');

  /// The Risk as a tag, not a sentence: 1R, 2R, 3R — the level and the letter,
  /// short enough to sit in a scoresheet cell.
  String riskLabel(int level) => level <= 0 ? '' : '${level}R';

  String get over => _p('over', 'أوفر');
  String get under => _p('under', 'أندر');
  String get caller => _p('Caller', 'كولر');
  String get with_ => _p('With', 'ويذ');
  String get enterTricks => _p('Enter tricks', 'إدخال اللمات');
  String get scoreRound => _p('Score round', 'احسب');
  String get continue_ => _p('Continue', 'متابعة');
  String get allPassed => _p('All passed', 'الكل باص');
  String get undo => _p('Undo', 'تراجع');
  String get trump => _p('Trump', 'الحكم');
  String get newGame => _p('New game', 'لعبة جديدة');
  String get length => _p('Length', 'الطول');
  String get players => _p('Players', 'اللاعبون');
  String get player => _p('Player', 'لاعب');
  String get start => _p('Start', 'ابدأ');
  String get next => _p('Next', 'التالي');
  String get rounds => _p('rounds', 'جولة');
  String get normal => _p('normal', 'عادية');
  String get color => _p('color', 'ألوان');
  String get houseRule => _p('house rule', 'قاعدة بيتية');
  String get settings => _p('Settings', 'الإعدادات');
  String get home => _p('Home', 'الرئيسية');

  // Length picker
  String get chooseLength => _p('Choose length', 'اختر الطول');
  String get howManyRounds =>
      _p('How many rounds tonight?', 'كام جولة الليلة؟');
  String get selected => _p('Selected:', 'المختار:');
  String get nextPlayers => _p('Next: players', 'التالي: اللاعبون');
  String get seat => _p('Seat', 'مقعد');
  String get close => _p('Close', 'اقفل');
  String get name => _p('Name', 'الاسم');
  String get startGame => _p('Start game', 'ابدأ اللعبة');
  String get allSeatsReady =>
      _p('All four seats ready', 'المقاعد الأربعة جاهزة');

  /// "2 names empty — they'll show as Player 3, Player 4". Blank seats are
  /// named for their number when the game starts.
  String emptyNames(List<String> stand) => _p(
      '${stand.length} name${stand.length == 1 ? '' : 's'} empty — '
          '${stand.length == 1 ? 'it' : 'they'}’ll show as ${stand.join(', ')}',
      '${stand.length == 1 ? 'اسم فاضي' : 'أسماء فاضية: ${stand.length}'} — '
          '${stand.length == 1 ? 'هيظهر' : 'هيظهروا'} باسم ${stand.join('، ')}');
  String get avatarFor => _p('Avatar for seat', 'صورة المقعد');
  String pickAvatarFor(int n) =>
      _p('Pick an avatar · Seat $n', 'اختار صورة · مقعد $n');
  // Round phases and the dash table
  String get phaseBid => _p('Bid', 'المزايدة');
  String get phaseCalls => _p('Calls', 'التقديرات');
  String get phaseTricks => _p('Tricks', 'اللمات');
  String get pts => _p('pts', 'نقطة');
  String get editDash => _p('Edit dash', 'عدّل الداش');
  String get nobodyDashedYet => _p('Nobody dashed yet', 'محدش داش لسه');
  String dashedList(List<String> who) => _p(
      '${who.length} dashed: ${who.join(', ')}',
      'داش ${who.length}: ${who.join('، ')}');
  String dashLimit(int n) =>
      _p('Max $n dashes a round', 'أقصى حاجة $n داش في الجولة');
  // Bid & trump
  String get callBadge => _p('Call', 'كول');
  String get whoWonBid => _p('Who won the bid?', 'مين كسب المزايدة؟');
  String get winningBid => _p('Winning bid', 'المزايدة الكسبانة');
  /// "The caller picks trump. Strongest first: Sun, then ♠ ♥ ♦ ♣."
  String trumpOrder(String sun, String suits) => _p(
      'The caller picks trump. Strongest first: $sun, then $suits.',
      'الكولر بيختار الحكم. الأقوى الأول: $sun، وبعدين $suits.');
  String get pickWhoWon => _p('Pick who won the bid', 'اختار مين كسب المزايدة');
  String get pickWinningBid =>
      _p('Pick the winning bid', 'اختار المزايدة الكسبانة');
  String get pickTrump => _p('Pick the trump', 'اختار الحكم');
  String normalRoundMin(int n) =>
      _p('Normal round · min $n', 'جولة عادية · أقل حاجة $n');
  String get colorAnyNumber =>
      _p('Color round · any number', 'جولة ألوان · أي رقم');
  String bidsSummary(String name, int bid, String? suit) => _p(
      '$name bids $bid${suit == null ? '' : ' · $suit'}',
      '$name طلب $bid${suit == null ? '' : ' · $suit'}');
  String get continueToCalls => _p('Continue to calls', 'كمّل للتقديرات');
  // Calls
  String get calledOf => _p('/ 13 called', '/ 13 متقدّر');
  String waitingOn(List<String> who) =>
      _p('waiting on ${who.join(', ')}', 'مستنيين ${who.join('، ')}');
  String get readyWord => _p('ready', 'جاهز');
  String get lastCallRisk => _p('Last call · risk', 'آخر كول · ريسك');
  String get setInBid => _p('Set in the bid', 'اتحدد في المزايدة');
  String get dashZero => _p('Dash = 0', 'داش = 0');
  String get bidWinner => _p('Bid winner', 'كسبان المزايدة');
  String get zeroTricks => _p('Zero tricks', 'ولا لمّة');
  String get calledNote => _p('Called', 'قدّر');
  String get calling => _p('Calling…', 'بيقدّر…');
  String get cantMake13 => _p('Can’t make 13!', 'ممنوع 13!');
  String get lockIn => _p('Lock in', 'ثبّت');
  String get bidBadge => _p('Bid', 'مزايدة');
  String get waitingTurn => _p('Waiting', 'مستني');
  String get tapPlayerToEdit => _p('Tap a player to change their call',
      'دوس على لاعب عشان تغيّر تقديره');
  String turnBadge(int n) => ar
      ? const ['الأول', 'التاني', 'التالت', 'الرابع'][(n - 1).clamp(0, 3)]
      : '$n${const ['ST', 'ND', 'RD', 'TH'][(n - 1).clamp(0, 3)]}';
  String get lockedIn => _p('Locked in', 'متثبّت');
  String get playHand => _p('Play the hand', 'العبوا الإيد');
  String get exactly13 => _p('Exactly 13 — not allowed', '13 بالظبط — ممنوع');
  String underBy(int n) => _p('Under $n', 'أقل $n');
  String overBy(int n) => _p('Over $n', 'أكتر $n');
  String totalOf(int n) => _p('Total $n', 'المجموع $n');
  String get lastCallMustChange =>
      _p('last call must change', 'آخر كول لازم يتغيّر');
  String get superCallTrump =>
      _p('Super call — pick the trump', 'سوبر كول — اختار الحكم');
  // Tricks
  String get waitingDots => _p('Waiting…', 'مستني…');
  String get madeIt => _p('Made it', 'جابها');
  String get exactMark => _p('✓ Exact', '✓ مظبوط');
  String get enterTricksHere => _p('Enter tricks ↓', 'دخّل اللمّ ↓');
  String get autoBadge => _p('Auto', 'تلقائي');
  String shortBy(int n) => _p('$n short', 'ناقص $n');
  String overBy2(int n) => _p('$n over', 'زيادة $n');
  String get exact => _p('Exact', 'مظبوط');
  String get tricksOf => _p('/ 13 tricks', '/ 13 لمّة');
  String unassigned(int n) => _p('$n unassigned', '$n من غير صاحب');
  String tooMany(int n) => _p('$n too many', '$n زيادة');
  String get readyBang => _p('ready!', 'جاهز!');
  String get oneTrickFewer => _p('One trick fewer', 'لمّة أقل');
  String get oneTrickMore => _p('One trick more', 'لمّة زيادة');
  // Scoreboard
  String afterRound(int n, int of) =>
      _p('After round $n of $of', 'بعد جولة $n من $of');
  String madeOfCalls(int made, int played) =>
      _p('made $made of $played calls', 'جاب $made من $played');
  String get roundCol => _p('Round', 'جولة');
  String get trumpCol => _p('Trump', 'الحكم');
  String get totalWord => _p('Total', 'المجموع');
  String get passShort => _p('Pass', 'باص');
  String leadsBy(String name, int by, int left) => _p(
      '$name leads by $by · $left round${left == 1 ? '' : 's'} to go',
      '$name متقدّم بـ $by · فاضل $left');
  String tiedTop(List<String> who, int left) => _p(
      '${who.join(' & ')} level at the top · $left to go',
      '${who.join(' و')} متعادلين على القمة · فاضل $left');
  String get editARound => _p('Edit a round', 'عدّل جولة');
  String get doneEditing => _p('Done', 'تم');
  String get nextRound => _p('Next round ›', 'الجولة الجاية ›');
  String get finish => _p('Finish', 'النهاية');
  // Settings
  String get lookAndFeel => _p('Look & feel', 'الشكل');
  String get language => _p('Language', 'اللغة');
  String get tableColor => _p('Table color', 'لون الترابيزة');
  String get vibration => _p('Vibration', 'الاهتزاز');
  String get vibrationHint => _p('Buzz on taps', 'هزّة خفيفة مع كل ضغطة');
  String get keepAwake => _p('Keep screen on', 'الشاشة تفضل منورة');
  String get keepAwakeHint =>
      _p('Stops the phone sleeping mid-game', 'التليفون مايقفلش وسط اللعب');
  String get houseRules => _p('House rules', 'قواعد البيت');
  String get rulesRescore => _p(
      'Changing a rule rescores the whole game',
      'تغيير أي قاعدة بيعيد حساب اللعبة كلها');
  String get aboutQuarterHour => _p('~15 min', '~15 دقيقة');
  String get aboutHalfHour => _p('~30 min', '~30 دقيقة');
  String get aboutHour => _p('~1 hour', '~ساعة');
  String get done => _p('Done', 'تم');
  String get skip => _p('Skip', 'تخطي');
  String get defaults => _p('Defaults', 'الافتراضي');
  String get scoreboard => _p('Scoreboard', 'النتائج');
  String get roundShort => _p('R', 'ج');
  String get pullForScores => _p('Pull the round down for scores', 'اسحب الجولة لتحت للنتائج');
  String get pullDownSheet => _p('Pull down scoreboard', 'نزّل النتائج');
  String get pushUpSheet => _p('Push scoreboard back up', 'طلّع النتائج');
  String get scoresAfterFirst =>
      _p('Scores appear after the first round', 'النتائج بتظهر بعد أول دور');
  String get noRounds => _p('No rounds yet', 'لا جولات بعد');
  String get passedRow =>
      _p('PASSED — next round doubled', 'باس — الجولة الجاية بالضعف');
  String get tapToEdit => _p('Tap a round to edit it', 'اضغط جولة لتعديلها');
  String get gameOver => _p('Game over', 'انتهت اللعبة');
  String get winsWith => _p('wins with', 'يفوز بـ');
  String get losesWith => _p('loses with', 'يخسر بـ');
  String get tiedLast => _p('tied last at', 'آخر الترتيب عند');
  String get tieAt => _p('tie at', 'تعادل عند');
  String get points => _p('points', 'نقطة');
  String get editingRound => _p('Editing round', 'تعديل جولة');

  // The estimate screen, one step at a time.
  String get stepDash => _p('Holding the dash window', 'الداش لسه مفتوح');
  String get stepCaller => _p('Press who called', 'اضغط مين اللي كول');
  String get stepTrump => _p('The caller picks the trump', 'الكولر يختار الحكم');
  String get stepCallerBid =>
      _p('How many will the caller make?', 'الكولر هيلم كام؟');
  String get stepTable => _p('The rest of the table estimates',
      'باقي الطاولة يقدّروا');
  String get stepReady => _p('All set — enter the tricks', 'تمام — سجّلوا اللمات');
  // The call panel.
  String get theCall => _p('The call', 'الكول');
  String get howMany => _p('How many?', 'كام لمة؟');
  String get confirm => _p('Confirm', 'تأكيد');
  String get cancel => _p('Cancel', 'إلغاء');
  String get clearCall => _p('Clear the call', 'الغِ الكول');
  String get edit => _p('Edit', 'تعديل');
  String get pickTrumpFirst => _p('Pick a trump', 'اختار الحكم');

  String get errTotal13 =>
      _p('Total is exactly 13 — someone must change.',
          'المجموع ١٣ بالضبط — لازم أحد يغيّر.');
  String get errTricksSum =>
      _p('Tricks must total 13.', 'مجموع اللمات لازم ١٣.');
  /// One press for the seat that took exactly what it called.
  String get gotThem => _p('Got them', 'لمّها');

  String get errNoCaller =>
      _p('Press who called.', 'اضغط مين اللي كول.');
  String get errNoTrump => _p('Pick the trump.', 'اختار الحكم.');
  String get errCallerNotTop => _p(
      'The Caller must hold the highest estimate.',
      'الكولر لازم يكون صاحب أعلى تقدير.');
  String get errMinCaller =>
      _p('Caller must estimate at least', 'الكولر لازم يقدّر على الأقل');
  String get errAllEqual => _p('Everyone called the same — house rule',
      'الكل قال نفس الرقم — قاعدة البيت');
  String get rebid => _p('Why? Reshuffle', 'ليه؟ اخلطوا');
  String allEqualTitle(int n) => _p('Everyone called $n', 'الكل قال $n');
  String get allEqualWhy => _p(
      'The house rule “All equal → double” is on, so this hand can’t be '
          'played.',
      'قاعدة البيت «الكل متساوي ← دبل» شغالة، فالإيد دي ماتتلعبش.');
  String get allEqualDeal => _p(
      'Collect the cards, reshuffle and deal a new hand.',
      'لمّوا الورق، اخلطوه ووزّعوا إيد جديدة.');
  String get allEqualCallAgain =>
      _p('Everyone calls again.', 'الكل يقدّر تاني.');
  String allEqualWorth(int m) => _p(
      'This round is now worth ×$m. If everyone calls the same number '
          'again, it doubles again.',
      'الجولة بقت ×$m. لو الكل قال نفس الرقم تاني، تتضاعف تاني.');
  String get allEqualOff => _p(
      'Don’t want this rule? Turn it off in Settings → House rules.',
      'مش عايزين القاعدة دي؟ اقفلوها من الإعدادات ← قواعد البيت.');
  String get dealtAgain => _p('Dealt again — call', 'اتوزّع — قدّروا');
  /// Said on the result screen when the round doubled because the top call
  /// was shared, so nobody has to work out where the multiplier came from.
  String get sharedTopCall =>
      _p('Top call was shared. Round', 'الكول الأعلى كان متشارك. الجولة');

  String get allMissed =>
      _p('Nobody made it. Next round', 'لا أحد حقق. الجولة القادمة');
  String get skipped =>
      _p('Round skipped. Next round', 'جولة ملغاة. القادمة');

  // Score breakdown labels
  String get roundScore => _p('Round score', 'نقاط الجولة');
  String get tricksAmount => _p('Tricks', 'اللمات');
  String get callerWith => _p('Caller / With', 'كولر / ويذ');
  String get sole => _p('Sole winner', 'الفائز الوحيد');
  String get soleLoser => _p('Sole loser', 'الخاسر الوحيد');
  String get multiplier => _p('Multiplier', 'المضاعف');
  String get dashCall => _p('Dash call', 'داش كول');

  /// The Super Call line. It stands in place of the round score, the tricks
  /// and the Caller bonus, so it is labelled as the whole call, not a bonus.
  String get superCall => _p('Super call', 'سوبر كول');

  // Home
  String get tagline =>
      _p('Pocket / Egyptian scoresheet', 'ورقة حساب مصرية');
  String get pocket => _p('Pocket', 'بوكيت');
  String get homeSub => _p('Egyptian scoresheet', 'ورقة حساب مصرية');
  String get newGameBtn => _p('New game', 'لعبة جديدة');
  String get resume => _p('Resume game', 'أكمل اللعبة');
  String get called => _p('called', 'قدّر');
  String get king => _p('King', 'الملك');
  String get koz => _p('Koz', 'كوز');

  /// A Color round hands the trump over instead of asking for it, so the
  /// table has to be told which one it is before anybody estimates.
  String get trumpForced => _p('fixed for this round', 'محدد لهذه الجولة');
  String colorRoundOf(int n, int total) =>
      ar ? 'ألوان $n من $total' : 'Color $n of $total';

  // The end screen.
  String get gameResult => _p('Game Result', 'نتيجة اللعبة');
  String get biggestWin => _p('Biggest win', 'أكبر مكسب');
  String get biggestLoss => _p('Biggest loss', 'أكبر خسارة');
  String get roundsWon => _p('W', 'ف');
  String get roundsLost => _p('L', 'خ');
  String get leave => _p('Leave', 'خروج');
  String get noRoundsPlayed => _p('Nothing was played', 'لم تُلعب أي جولة');

  /// The place badge down the standings. Arabic takes the bare numeral: the
  /// spelled-out ordinals are far too long for a badge this size.
  String place(int n) {
    if (ar) return '$n';
    const suffix = {1: 'ST', 2: 'ND', 3: 'RD'};
    return '$n${suffix[n] ?? 'TH'}';
  }

  // Settings groups
  String get grpScoring => _p('Scoring', 'الحساب');
  String get grpConfirm => _p('Confirm against the app', 'تأكّد من التطبيق');
  String get grpRules => _p('Rules', 'القواعد');
}
