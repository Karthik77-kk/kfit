import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kfit/providers/fitness_provider.dart';
import 'package:kfit/services/gemini_text_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GeminiTextService.extractText', () {
    test('concatenates text parts from a valid response body', () {
      final body = {
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'Hello '},
                {'text': 'coach'},
              ]
            }
          }
        ]
      };
      expect(GeminiTextService.extractText(body), 'Hello coach');
    });

    test('returns null for empty candidates / malformed body', () {
      expect(GeminiTextService.extractText({'candidates': []}), isNull);
      expect(GeminiTextService.extractText({'nope': true}), isNull);
      expect(GeminiTextService.extractText('garbage'), isNull);
    });

    test('is not configured without a compiled-in key (test build)', () {
      // No --dart-define GEMINI_API_KEY in the test runner.
      expect(GeminiTextService.isConfigured, isFalse);
    });

    test('generate throws a user-safe error when unconfigured', () async {
      expect(() => GeminiTextService.generate('sys', 'hi'),
          throwsA(isA<Exception>()));
    });
  });

  group('AI coach mode (hybrid) persistence', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('defaults to local (on-device)', () async {
      final p = FitnessProvider();
      await p.loadData();
      expect(p.aiCoachMode, AiCoachMode.local);
    });

    test('saveAiCoachMode(cloud) persists across a reload', () async {
      final p = FitnessProvider();
      await p.loadData();
      await p.saveAiCoachMode(AiCoachMode.cloud);
      expect(p.aiCoachMode, AiCoachMode.cloud);

      // Fresh provider reads the same mock store.
      final p2 = FitnessProvider();
      await p2.loadData();
      expect(p2.aiCoachMode, AiCoachMode.cloud);
    });
  });

  group('Daily brief (cloud) — no-op when unconfigured', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('refreshDailyBriefIfDue returns null and does not cache without a key',
        () async {
      final p = FitnessProvider();
      await p.loadData();
      final brief = await p.refreshDailyBriefIfDue();
      expect(brief, isNull);
      expect(p.dailyBrief, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('ai_brief_date'), isFalse);
    });
  });

  group('Full history is loaded (no 60-day cap)', () {
    test('a 400-day-old food/water/supp day loads into history', () async {
      final old = DateTime.now().subtract(const Duration(days: 400));
      final k =
          '${old.year}-${old.month.toString().padLeft(2, '0')}-${old.day.toString().padLeft(2, '0')}';
      SharedPreferences.setMockInitialValues({
        'food_$k':
            '[{"id":"z","name":"Idli","calories":120,"protein":4,"mealType":0,"timestamp":"${old.toIso8601String()}","servingNote":""}]',
        'water_$k': 1500,
        'supp_$k': '{"whey":true,"creatine":true,"multivitamin":false}',
      });
      final p = FitnessProvider();
      await p.loadData();
      expect(p.foodHistory[k]?.length, 1);
      expect(p.waterHistory[k], 1500);
      expect(p.supplementHistory.containsKey(k), isTrue);
    });
  });
}
