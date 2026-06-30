import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:kfit/providers/fitness_provider.dart';
import 'package:kfit/services/cloud_backup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// GitHub cloud backup: pure helpers (repo/account validation, path slugging,
/// content decode, error mapping, disabled gate) + the shared backup-JSON
/// build/restore round-trip used by both file and cloud paths.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CloudBackupService pure helpers', () {
    test('isValidRepo accepts owner/name, rejects junk', () {
      expect(CloudBackupService.isValidRepo('Karthik77-kk/kfit-data'), isTrue);
      expect(CloudBackupService.isValidRepo('owner/repo'), isTrue);
      expect(CloudBackupService.isValidRepo('no-slash'), isFalse);
      expect(CloudBackupService.isValidRepo('a/b/c'), isFalse);
      expect(CloudBackupService.isValidRepo(''), isFalse);
    });

    test('isValidAccount requires both parts to slugify non-empty', () {
      expect(CloudBackupService.isValidAccount('karthik', 'kfit-001'), isTrue);
      expect(CloudBackupService.isValidAccount('  ', 'x'), isFalse);
      expect(CloudBackupService.isValidAccount('a', '   '), isFalse);
      expect(CloudBackupService.isValidAccount('!!!', '@@@'), isFalse); // slug empty
    });

    test('filePathFor slugifies + namespaces under users/', () {
      expect(CloudBackupService.filePathFor('Karthik M', '007'),
          'users/karthik-m-007.json');
      expect(CloudBackupService.filePathFor('a.b_c', 'ID 9'),
          'users/a-b-c-id-9.json');
    });

    test('distinct accounts map to distinct files (isolation)', () {
      final a = CloudBackupService.filePathFor('alice', '1');
      final b = CloudBackupService.filePathFor('bob', '2');
      expect(a, isNot(b));
    });

    test('decodeContentField round-trips base64 (incl. newline chunking)', () {
      const original = '{"calorie_goal":1900,"name":"Karthik"}';
      final b64 = base64Encode(utf8.encode(original));
      // GitHub chunks base64 with newlines every 60 chars — simulate it.
      final chunked = RegExp('.{1,4}')
          .allMatches(b64)
          .map((m) => m.group(0))
          .join('\n');
      final decoded = CloudBackupService.decodeContentField(
          {'content': chunked, 'encoding': 'base64'});
      expect(decoded, original);
    });

    test('errorFor maps common statuses to readable messages', () {
      expect(CloudBackupService.errorFor(401), contains('auth'));
      expect(CloudBackupService.errorFor(404), contains('Repo'));
      expect(CloudBackupService.errorFor(403), contains('denied'));
    });
  });

  group('CloudBackupService disabled gate (no dart-define in tests)', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('enabled is false without an injected token', () {
      expect(CloudBackupService.token, '');
      expect(CloudBackupService.enabled, isFalse);
    });

    test('backup/restore throw when not configured', () async {
      expect(() => CloudBackupService.instance.backup('{}'), throwsException);
      expect(() => CloudBackupService.instance.restore('u', 'i'),
          throwsException);
    });

    test('autoBackupIfDue is a no-op when disabled', () async {
      final pushed = await CloudBackupService.instance
          .autoBackupIfDue(() async => '{}');
      expect(pushed, isFalse);
    });

    test('saveAccount persists username + id', () async {
      await CloudBackupService.instance.saveAccount('karthik', 'kfit-001');
      expect(await CloudBackupService.instance.username(), 'karthik');
      expect(await CloudBackupService.instance.userId(), 'kfit-001');
      expect(await CloudBackupService.instance.hasAccount, isTrue);
    });

    test('auto-backup toggle defaults on and persists', () async {
      expect(await CloudBackupService.instance.autoBackupEnabled(), isTrue);
      await CloudBackupService.instance.setAutoBackup(false);
      expect(await CloudBackupService.instance.autoBackupEnabled(), isFalse);
    });
  });

  group('backup JSON build/restore round-trip', () {
    test('build excludes sensitive keys; restore reapplies the rest', () async {
      SharedPreferences.setMockInitialValues({
        'calorie_goal': 1900,
        'protein_goal': 140,
        'favorite_foods': ['paneer', 'roti'], // StringList must survive
        'hf_token_ai_chat': 'SECRET',         // excluded from export
        'chat_sessions_v1': 'PRIVATE',        // excluded from export
        'cloud_last_backup_ms': 123,          // sync state — must NOT travel
        'cloud_username': 'karthik',          // sync state — must NOT travel
      });
      final source = FitnessProvider();
      await source.loadData();
      final json = await source.buildBackupJson();
      final map = jsonDecode(json) as Map<String, dynamic>;

      expect(map['calorie_goal'], 1900);
      expect(map['favorite_foods'], ['paneer', 'roti']);
      expect(map.containsKey('hf_token_ai_chat'), isFalse); // sensitive dropped
      expect(map.containsKey('chat_sessions_v1'), isFalse);
      // cloud_* sync state never travels (would plant a stale sha / wrong account)
      expect(map.keys.where((k) => k.startsWith('cloud_')), isEmpty);

      // Restore into a fresh device (empty prefs).
      SharedPreferences.setMockInitialValues({});
      final target = FitnessProvider();
      final ok = await target.importFromJsonString(json);
      expect(ok, isTrue);
      expect(target.calorieGoal, 1900);
      expect(target.proteinGoal, 140);
      expect(target.isFavoriteFood('paneer'), isTrue); // StringList restored
    });

    test('importFromJsonString returns false on malformed input', () async {
      SharedPreferences.setMockInitialValues({});
      final p = FitnessProvider();
      expect(await p.importFromJsonString('not json'), isFalse);
    });
  });
}
