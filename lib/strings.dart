/// Minimal two-language string table. `Str(true)` gives Arabic.
class Str {
  final bool ar;
  const Str(this.ar);

  String _p(String en, String a) => ar ? a : en;

  String get appName => _p('Estimation', 'إستيميشن');
  String get round => _p('Round', 'جولة');
  String get of => _p('of', 'من');
  String get estimate => _p('estimate', 'التقدير');
  String get tricksWon => _p('tricks won', 'اللمات');
  String get dash => _p('Dash', 'داش');
  String get back => _p('Back', 'رجوع');
  String get total => _p('total', 'المجموع');
  String get direction => _p('round', 'الجولة');
  String get risk => _p('Risk', 'ريسك');
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
  String get start => _p('Start', 'ابدأ');
  String get rounds => _p('rounds', 'جولة');
  String get normal => _p('normal', 'عادية');
  String get color => _p('color', 'ألوان');
  String get houseRule => _p('house rule', 'قاعدة بيتية');
  String get settings => _p('Settings', 'الإعدادات');
  String get done => _p('Done', 'تم');
  String get defaults => _p('Defaults', 'الافتراضي');
  String get scoreboard => _p('Scoreboard', 'النتائج');
  String get noRounds => _p('No rounds yet', 'لا جولات بعد');
  String get tapToEdit => _p('Tap a round to edit it', 'اضغط جولة لتعديلها');
  String get gameOver => _p('Game over', 'انتهت اللعبة');
  String get winsWith => _p('wins with', 'يفوز بـ');
  String get tieAt => _p('tie at', 'تعادل عند');
  String get points => _p('points', 'نقطة');
  String get editingRound => _p('Editing round', 'تعديل جولة');

  String get errTotal13 =>
      _p('Total is exactly 13 — someone must change.',
          'المجموع ١٣ بالضبط — لازم أحد يغيّر.');
  String get errTricksSum =>
      _p('Tricks must total 13.', 'مجموع اللمات لازم ١٣.');
  String get errMinCaller =>
      _p('Caller must estimate at least', 'الكولر لازم يقدّر على الأقل');
  String get errAllEqual => _p(
      'Everyone estimated the same — round doubles, estimate again.',
      'الجميع قدّر نفس الرقم — الجولة تتضاعف، أعيدوا.');
  String get rebid => _p('Double & re-estimate', 'ضاعف وأعد');
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

  // Settings groups
  String get grpScoring => _p('Scoring', 'الحساب');
  String get grpConfirm => _p('Confirm against the app', 'تأكّد من التطبيق');
  String get grpRules => _p('Rules', 'القواعد');
}
