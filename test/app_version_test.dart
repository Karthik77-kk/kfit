import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kfit/app_info.dart';

/// Guards against the "About screen shows a stale build" bug (it once read
/// "Build 82" while pubspec was at +106). The About screen renders
/// [kAppVersionLabel] from app_info.dart; this test fails the build whenever
/// app_info.dart drifts from pubspec.yaml so they can never disagree again.
void main() {
  test('app_info constants match pubspec.yaml version', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$',
            multiLine: true)
        .firstMatch(pubspec);
    expect(match, isNotNull, reason: 'pubspec.yaml must declare version: X.Y.Z+N');

    final pubName = match!.group(1);
    final pubBuild = int.parse(match.group(2)!);

    expect(kAppVersionName, pubName,
        reason: 'kAppVersionName ($kAppVersionName) != pubspec ($pubName)');
    expect(kAppBuild, pubBuild,
        reason: 'kAppBuild ($kAppBuild) != pubspec build ($pubBuild)');
    expect(kAppVersionLabel, 'v$pubName · Build $pubBuild');
  });
}
