import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kfit/services/update_service.dart';

void main() {
  group('UpdateService.buildFromTag', () {
    test('parses standard v2.3.N tag', () {
      expect(UpdateService.buildFromTag('v2.3.272'), 272);
    });

    test('parses zero build', () {
      expect(UpdateService.buildFromTag('v2.3.0'), 0);
    });

    test('returns null for short tag', () {
      expect(UpdateService.buildFromTag('v2.3'), isNull);
    });

    test('returns null for empty string', () {
      expect(UpdateService.buildFromTag(''), isNull);
    });

    test('returns null for non-numeric last segment', () {
      expect(UpdateService.buildFromTag('v2.3.abc'), isNull);
    });
  });

  group('UpdateService.parseLatest', () {
    Map<String, dynamic> makeRelease({
      String tag = 'v2.3.280',
      String body = '## What\'s new\n- Feature A',
      String assetName = 'kfit.apk',
      String url = 'https://example.com/kfit.apk',
      int size = 20000000,
    }) {
      return {
        'tag_name': tag,
        'body': body,
        'assets': [
          {
            'name': assetName,
            'browser_download_url': url,
            'size': size,
          }
        ],
      };
    }

    test('parses valid release with kfit.apk asset', () {
      final info = UpdateService.parseLatest(makeRelease());
      expect(info, isNotNull);
      expect(info!.build, 280);
      expect(info.tag, 'v2.3.280');
      expect(info.versionName, '2.3.280');
      expect(info.apkUrl, 'https://example.com/kfit.apk');
      expect(info.sizeBytes, 20000000);
      expect(info.notes, contains('Feature A'));
    });

    test('returns null when kfit.apk asset is missing', () {
      final info = UpdateService.parseLatest(makeRelease(assetName: 'other.apk'));
      expect(info, isNull);
    });

    test('returns null when assets list is empty', () {
      final info = UpdateService.parseLatest({
        'tag_name': 'v2.3.280',
        'body': '',
        'assets': [],
      });
      expect(info, isNull);
    });

    test('returns null when tag is malformed', () {
      final info = UpdateService.parseLatest(makeRelease(tag: 'v2.3'));
      expect(info, isNull);
    });

    test('returns null when apkUrl is empty', () {
      final info = UpdateService.parseLatest(makeRelease(url: ''));
      expect(info, isNull);
    });

    test('handles missing body gracefully', () {
      final json = {
        'tag_name': 'v2.3.280',
        'assets': [
          {
            'name': 'kfit.apk',
            'browser_download_url': 'https://example.com/kfit.apk',
            'size': 1000,
          }
        ],
      };
      final info = UpdateService.parseLatest(json);
      expect(info, isNotNull);
      expect(info!.notes, '');
    });

    test('handles null assets gracefully', () {
      final info = UpdateService.parseLatest({
        'tag_name': 'v2.3.280',
        'body': '',
      });
      expect(info, isNull);
    });
  });

  group('UpdateService.checkForUpdate', () {
    Map<String, dynamic> makeReleaseJson(int build) => {
          'tag_name': 'v2.3.$build',
          'body': 'Release notes',
          'assets': [
            {
              'name': 'kfit.apk',
              'browser_download_url': 'https://example.com/kfit.apk',
              'size': 10000000,
            }
          ],
        };

    http.Client mockClient(int statusCode, Map<String, dynamic> body) {
      return MockClient((_) async => http.Response(
            jsonEncode(body),
            statusCode,
            headers: {'content-type': 'application/json'},
          ));
    }

    http.Client throwingClient() {
      return MockClient((_) async => throw Exception('network error'));
    }

    test('returns AppUpdateInfo when remote build is newer', () async {
      final client = mockClient(200, makeReleaseJson(300));
      final service = UpdateService(httpClient: client);
      final info = await service.checkForUpdate(272);
      expect(info, isNotNull);
      expect(info!.build, 300);
    });

    test('returns null when remote build equals current', () async {
      final client = mockClient(200, makeReleaseJson(272));
      final service = UpdateService(httpClient: client);
      final info = await service.checkForUpdate(272);
      expect(info, isNull);
    });

    test('returns null when remote build is older', () async {
      final client = mockClient(200, makeReleaseJson(100));
      final service = UpdateService(httpClient: client);
      final info = await service.checkForUpdate(272);
      expect(info, isNull);
    });

    test('returns null on HTTP 500', () async {
      final client = mockClient(500, {});
      final service = UpdateService(httpClient: client);
      final info = await service.checkForUpdate(272);
      expect(info, isNull);
    });

    test('returns null on network exception', () async {
      final service = UpdateService(httpClient: throwingClient());
      final info = await service.checkForUpdate(272);
      expect(info, isNull);
    });

    test('returns info when currentBuild is 0 (guard is in main.dart)', () async {
      final client = mockClient(200, makeReleaseJson(300));
      final service = UpdateService(httpClient: client);
      // Build 300 > 0, so this DOES return info — the guard is in main.dart
      // (it skips the call when currentBuild == 0). Service itself is neutral.
      final info = await service.checkForUpdate(0);
      expect(info, isNotNull);
    });
  });
}
