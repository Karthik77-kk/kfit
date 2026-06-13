/// Single source of truth for the app's user-visible version.
///
/// These MUST stay in sync with `pubspec.yaml` (`version: <name>+<build>`).
/// A test (`test/app_version_test.dart`) reads pubspec.yaml and fails the build
/// if they drift, so the "About" screen can never show a stale build number
/// again (the old hardcoded "Build 82" lagged pubspec by 20+ builds).
library;

const String kAppVersionName = '2.3.0';
const int kAppBuild = 109;

/// e.g. "v2.3.0 · Build 109"
const String kAppVersionLabel = 'v$kAppVersionName · Build $kAppBuild';
