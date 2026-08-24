/// Which build this is, stamped in at compile time.
///
/// Every build carries the same version (1.0.0), so a TestFlight list and a
/// cached web app look identical from the outside. CI passes the build number
/// and the commit it built:
///
///   flutter build ipa --dart-define=BUILD_LABEL="42-70298e5"
///
/// A local `flutter run` leaves it as `dev`.
const String kBuildLabel =
    String.fromEnvironment('BUILD_LABEL', defaultValue: 'dev');
