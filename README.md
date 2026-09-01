# Estimation Calculator

Flutter port of the Estimation (تقدير) scoresheet. Pocket/Egyptian ruleset,
offline, no backend.

## Getting it running

Only `lib/`, `test/` and `pubspec.yaml` are here — the platform folders are
generated, so scaffold them first:

```bash
cd estimation
flutter create .          # generates android/, ios/, etc. Keeps existing lib/
flutter pub get
flutter run               # device or emulator
```

`flutter create .` will not overwrite `lib/main.dart` or `pubspec.yaml`
dependencies, but check `git diff` on pubspec afterwards if you're versioning it.

## Installing on your phone

**Android (simplest):**

```bash
flutter build apk --release
# build/app/outputs/flutter-apk/app-release.apk
```

Copy that APK to the phone and install it (allow "install from unknown
sources"). For a smaller download, `--split-per-abi` gives you an
`arm64-v8a` APK that most modern phones want.

**iOS:** `flutter build ipa` needs signing. Since you already run
Codemagic and AltStore, the usual path applies — build unsigned, then
sideload the IPA through AltServer.

## Running the tests

```bash
flutter test
```

`test/scoring_test.dart` pins the engine against worked examples — the caller
scoring 26 on a made bid of 6, −22 on a miss, the risk landing on the last
estimator, the all-miss ladder going ×2 then ×3. If you change a constant and a
test goes red, that's the intended alarm.

`test/super_call_test.dart` does the same for the super call: the square at
every call from 8 to 13, the halved miss, the bonuses that still stack on it,
and — just as important — that a call of 7 or less is left exactly as it was.

## Layout

| File | What's in it |
|---|---|
| `lib/rules.dart` | Every scoring constant. Nothing else hard-codes a number. |
| `lib/scoring.dart` | Pure engine — no Flutter imports, fully unit-testable. |
| `lib/models.dart` | Suits, game modes, `Round`, `ScoreLine`. |
| `lib/controller.dart` | State, mutations, `SharedPreferences` persistence. |
| `lib/screens.dart` | Setup, entry, result, done, settings. |
| `lib/widgets.dart` | Seat column with stepper, stat bar, trump row, scoreboard. |
| `lib/strings.dart` | English/Arabic strings. |

## Scoring model

Additive. Each component is added or subtracted independently, then the round
total is multiplied by the round multiplier.

| Component | Win | Loss |
|---|---|---|
| Round score | +10 | −10 |
| Tricks | + estimate | − \|eaten − estimate\| |
| Caller / With | +10 | −10 |
| Per risk level | +10 | −10 |
| Sole winner / loser | +10 | −10 |
| Dash call | +25 over / +33 under | −25 / −33 |

**Super calls are the exception.** A call of 8 or more is scored on its own
formula, which *replaces* the round score, the tricks and the Caller bonus
rather than adding to them:

| Call | Made it | Missed |
|---|---|---|
| 8 | +64 | −32 |
| 9 | +81 | −40 |
| 10 | +100 | −50 |
| 11 | +121 | −60 |
| 12 | +144 | −72 |
| 13 | +169 | −84 |

Made is `call²`; missed is `−call² ÷ 2`, rounded down. A miss is priced off the
call alone — eating 7 on a called 8 costs the same −32 as eating nothing, so
the tricks difference never enters it. Risk, the sole winner/loser bonus and
the round multiplier still apply on top, which is why a super 8 taken alone is
74 and a super 9 taken alone is 91.

Turn the whole thing off with **Super call scores on its own formula** in
settings and an 8 goes back to scoring +28 / −20 minus the difference, the way
every other call does.

**Derived, never chosen:**

- **Caller** is the highest estimate. Anyone matching it is **With**. They score
  identically, so a tie at the top needs no tie-break.
- **Risk** goes to the last player to settle their estimate, since they're the
  one forced away from 13. Level = `|total − 13| ÷ 2`, rounded down.
- **Over/Under** from whether the table's total sits above or below 13.

**House rules kept** (the published ruleset is silent on these): Micro (5
rounds) and Mini (10), and everyone estimating the same doubling the round and
forcing a re-estimate.

## Still unconfirmed

Three values sit under "Confirm against the app" in settings because the
published table doesn't spell them out:

1. Does a loss subtract the trick *difference* or the *full estimate*?
   (Super calls sidestep this — they are priced off the call.)
2. Does a dash player also collect the ±10 round score?
3. Does a dash player also collect the sole winner/loser bonus?

The test for #1: call 6, eat 4. **−22** means difference (current default),
**−26** means full estimate.
