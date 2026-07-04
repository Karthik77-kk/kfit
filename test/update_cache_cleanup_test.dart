import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kfit/services/update_service.dart';

void main() {
  test('cleanupCachedApks removes stale APKs and can keep the current build',
      () async {
    final tmp = await Directory.systemTemp.createTemp('kfit_apk_test');
    for (final b in [280, 290, 300]) {
      await File('${tmp.path}/kfit_$b.apk').writeAsString('x');
    }
    await File('${tmp.path}/other.txt').writeAsString('keep me');

    // Keep build 300 (the one about to install), drop the older ones.
    await UpdateService.cleanupCachedApks(keepBuild: 300, dir: tmp);
    expect(File('${tmp.path}/kfit_280.apk').existsSync(), isFalse);
    expect(File('${tmp.path}/kfit_290.apk').existsSync(), isFalse);
    expect(File('${tmp.path}/kfit_300.apk').existsSync(), isTrue);
    expect(File('${tmp.path}/other.txt').existsSync(), isTrue);

    // No keepBuild → the cold-start sweep clears every leftover APK.
    await UpdateService.cleanupCachedApks(dir: tmp);
    expect(File('${tmp.path}/kfit_300.apk').existsSync(), isFalse);
    expect(File('${tmp.path}/other.txt').existsSync(), isTrue); // non-APK untouched

    await tmp.delete(recursive: true);
  });
}
