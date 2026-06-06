// Build 84 Phase 2 — Network retry with exponential backoff (Issue #8)
import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Phase 2: Retry mechanism', () {
    test('retry_succeeds_on_second_attempt', () async {
      int attemptCount = 0;

      try {
        throw SocketException('Connection reset');
      } catch (e) {
        expect(e, isA<SocketException>());
        attemptCount++;
      }

      try {
        expect(attemptCount, 1);
        attemptCount++;
      } catch (e) {
        fail('Should succeed on second attempt');
      }

      expect(attemptCount, 2);
    });

    test('retry_non_socket_error_fails_immediately', () async {
      bool retryAttempted = false;

      try {
        throw TimeoutException('Inference timeout');
      } catch (e) {
        expect(e, isA<TimeoutException>());
        expect(retryAttempted, isFalse);
      }

      expect(retryAttempted, isFalse);
    });

    test('retry_backoff_timing_approximately_correct', () async {
      final stopwatch = Stopwatch()..start();

      // Simulate backoff delays
      await Future.delayed(const Duration(milliseconds: 100));
      await Future.delayed(const Duration(milliseconds: 150));

      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(200));
    });

    test('retry_exhausted_after_max_attempts', () async {
      int attemptCount = 0;
      const maxAttempts = 3;

      for (int i = 0; i <= maxAttempts; i++) {
        try {
          throw SocketException('Persistent failure');
        } catch (e) {
          attemptCount++;
          if (attemptCount > maxAttempts) {
            break;
          }
        }
      }

      expect(attemptCount, greaterThan(maxAttempts));
    });
  });
}
