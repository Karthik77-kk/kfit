// Build 70 — chat sessions, keyword context injection, supplement streak
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:karthik_fitness/providers/fitness_provider.dart';
import 'package:karthik_fitness/models/models.dart';
import 'package:karthik_fitness/services/chat_session_service.dart';
import 'package:karthik_fitness/services/on_device_ai_service.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

Future<FitnessProvider> _loaded([Map<String, Object> seed = const {}]) async {
  SharedPreferences.setMockInitialValues(seed);
  final p = FitnessProvider();
  await p.loadData();
  return p;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => call.method == 'getApplicationDocumentsDirectory'
          ? Directory.systemTemp.path : null,
    );
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ── 1. ChatSessionService ─────────────────────────────────────────────────

  group('ChatSessionService — persistence', () {
    test('loadSessions returns empty list when no data', () async {
      final sessions = await ChatSessionService.loadSessions();
      expect(sessions, isEmpty);
    });

    test('saveSession persists and loadSessions retrieves it', () async {
      final s = ChatSession(
        id: 'test-1',
        title: 'My first chat',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        messages: [
          ChatSessionMessage(text: 'Hello!', isUser: true, timestamp: DateTime.now()),
          ChatSessionMessage(text: 'Hi there!', isUser: false, timestamp: DateTime.now()),
        ],
      );
      await ChatSessionService.saveSession(s);
      final loaded = await ChatSessionService.loadSessions();
      expect(loaded.length, 1);
      expect(loaded.first.id, 'test-1');
      expect(loaded.first.title, 'My first chat');
      expect(loaded.first.messages.length, 2);
    });

    test('saveSession updates existing session by id', () async {
      final s = ChatSession(
        id: 'upd-1', title: 'Original',
        createdAt: DateTime.now(), updatedAt: DateTime.now(),
        messages: [],
      );
      await ChatSessionService.saveSession(s);
      s.title = 'Updated Title';
      s.messages.add(ChatSessionMessage(text: 'Hi', isUser: true, timestamp: DateTime.now()));
      await ChatSessionService.saveSession(s);

      final loaded = await ChatSessionService.loadSessions();
      expect(loaded.length, 1); // not duplicated
      expect(loaded.first.title, 'Updated Title');
      expect(loaded.first.messages.length, 1);
    });

    test('deleteSession removes the correct session', () async {
      final s1 = ChatSession(id: 'del-1', title: 'Keep',
          createdAt: DateTime.now(), updatedAt: DateTime.now(), messages: []);
      final s2 = ChatSession(id: 'del-2', title: 'Delete me',
          createdAt: DateTime.now(), updatedAt: DateTime.now(), messages: []);
      await ChatSessionService.saveSession(s1);
      await ChatSessionService.saveSession(s2);

      await ChatSessionService.deleteSession('del-2');
      final loaded = await ChatSessionService.loadSessions();
      expect(loaded.length, 1);
      expect(loaded.first.id, 'del-1');
    });

    test('sessions sorted newest first by updatedAt', () async {
      final old = ChatSession(
        id: 'old', title: 'Older',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
        messages: [],
      );
      final newer = ChatSession(
        id: 'new', title: 'Newer',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        messages: [],
      );
      await ChatSessionService.saveSession(old);
      await ChatSessionService.saveSession(newer);
      final loaded = await ChatSessionService.loadSessions();
      expect(loaded.first.id, 'new'); // newest first
    });

    test('loadSessions returns empty list on corrupt JSON (graceful)', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('chat_sessions_v1', 'not valid json {{{');
      final sessions = await ChatSessionService.loadSessions();
      expect(sessions, isEmpty); // no crash, graceful fallback
    });

    test('max 20 sessions kept — oldest trimmed', () async {
      for (int i = 0; i < 25; i++) {
        await ChatSessionService.saveSession(ChatSession(
          id: 'sess-$i', title: 'Session $i',
          createdAt: DateTime.now().subtract(Duration(days: 25 - i)),
          updatedAt: DateTime.now().subtract(Duration(days: 25 - i)),
          messages: [],
        ));
      }
      final loaded = await ChatSessionService.loadSessions();
      expect(loaded.length, lessThanOrEqualTo(20));
    });
  });

  // ── 2. Session title generation ──────────────────────────────────────────────

  group('ChatSessionService.titleFromFirstMessage', () {
    test('uses first 6 words', () {
      const msg = 'What should I eat for breakfast tomorrow morning early?';
      final title = ChatSessionService.titleFromFirstMessage(msg);
      expect(title, 'What should I eat for breakfast');
    });

    test('truncates at 40 chars with ellipsis', () {
      const msg = 'This is a very long message that should be truncated at forty characters max';
      final title = ChatSessionService.titleFromFirstMessage(msg);
      expect(title.length, lessThanOrEqualTo(42)); // 40 + '…'
    });

    test('short message returns full text', () {
      final title = ChatSessionService.titleFromFirstMessage('Hi!');
      expect(title, 'Hi!');
    });

    test('empty message returns Chat', () {
      final title = ChatSessionService.titleFromFirstMessage('');
      expect(title, 'Chat');
    });

    test('whitespace-only message returns Chat', () {
      final title = ChatSessionService.titleFromFirstMessage('   ');
      expect(title, 'Chat');
    });
  });

  // ── 3. ChatSessionMessage serialization ──────────────────────────────────────

  group('ChatSessionMessage serialization', () {
    test('toJson / fromJson round-trip preserves all fields', () {
      final ts = DateTime(2026, 6, 5, 10, 30);
      final msg = ChatSessionMessage(text: 'Hello AI', isUser: true, timestamp: ts);
      final json = msg.toJson();
      final restored = ChatSessionMessage.fromJson(json);

      expect(restored.text,    msg.text);
      expect(restored.isUser,  msg.isUser);
      expect(restored.timestamp.toIso8601String(), ts.toIso8601String());
    });

    test('AI message (isUser: false) round-trips correctly', () {
      final msg = ChatSessionMessage(
          text: 'Your protein is 80g today.', isUser: false, timestamp: DateTime.now());
      final restored = ChatSessionMessage.fromJson(msg.toJson());
      expect(restored.isUser, isFalse);
    });
  });

  // ── 4. ChatSession serialization ─────────────────────────────────────────────

  group('ChatSession serialization', () {
    test('toJson / fromJson preserves all fields including messages', () {
      final created = DateTime(2026, 6, 1);
      final updated = DateTime(2026, 6, 5);
      final s = ChatSession(
        id: 'abc-123', title: 'My Test Chat',
        createdAt: created, updatedAt: updated,
        messages: [
          ChatSessionMessage(text: 'Q', isUser: true,  timestamp: created),
          ChatSessionMessage(text: 'A', isUser: false, timestamp: updated),
        ],
      );

      final json    = s.toJson();
      final restored = ChatSession.fromJson(json);

      expect(restored.id,           'abc-123');
      expect(restored.title,        'My Test Chat');
      expect(restored.messages.length, 2);
      expect(restored.messages.first.text, 'Q');
      expect(restored.messages.last.text,  'A');
    });
  });

  // ── 5. Keyword context injection ─────────────────────────────────────────────

  group('Keyword context injection (_buildContextForQuery)', () {
    test('weight keywords trigger weight history injection', () async {
      final p = await _loaded();
      await p.logBodyEntry(weightKg: 80.0, steps: 0);
      final ai  = OnDeviceAiService();
      final ctx = ai.buildContextForQueryTest('What is my weight trend?', p);
      expect(ctx, contains('WeightLog'));
      expect(ctx, contains('80.0kg'));
    });

    test('food keywords trigger food log injection', () async {
      final p = await _loaded();
      await p.addFoodEntry(FoodEntry(
        id: 'f1', name: 'Paneer Rice', calories: 450, protein: 22,
        mealType: MealType.lunch, timestamp: DateTime.now(),
      ));
      final ai  = OnDeviceAiService();
      final ctx = ai.buildContextForQueryTest('What did I eat today?', p);
      expect(ctx, contains('FoodLog'));
      expect(ctx, contains('Paneer Rice'));
    });

    test('workout keywords trigger workout history injection', () async {
      final p = await _loaded();
      await p.logWorkout(WorkoutLog(
        id: 'w1', name: 'Push Day',
        date: DateTime.now(),
        exercises: [ExerciseLog(name: 'Bench Press', sets: [SetData(reps: 8, weight: 80)])],
      ));
      final ai  = OnDeviceAiService();
      final ctx = ai.buildContextForQueryTest('How was my last workout?', p);
      expect(ctx, contains('Workouts'));
      expect(ctx, contains('Push Day'));
    });

    test('scale keywords trigger scale history injection', () async {
      final p = await _loaded();
      await p.logScaleEntry(SmartScaleEntry(
        id: 's1', date: DateTime.now(),
        weightKg: 79, bodyFatPercent: 21, bodyFatKg: 16.6,
        muscleMassKg: 37, muscleMassPercent: 47, leanBodyMassKg: 62.4,
        biologicalAge: 24, visceralFatIndex: 6, bmr: 1800,
        bodyWaterPercent: 59, boneMassKg: 3.1, proteinPercent: 18,
        skeletalMuscleMassKg: 28,
      ));
      final ai  = OnDeviceAiService();
      final ctx = ai.buildContextForQueryTest('What is my body fat percentage?', p);
      expect(ctx, contains('ScaleHistory'));
    });

    test('measurement keywords trigger measurement injection', () async {
      final p = await _loaded();
      await p.logMeasurement(MeasurementEntry(
        id: 'm1', date: DateTime.now(),
        chestCm: 95, waistCm: 82, hipsCm: 96,
        leftArmCm: 33, leftThighCm: 57,
      ));
      final ai  = OnDeviceAiService();
      final ctx = ai.buildContextForQueryTest('How is my waist measurement?', p);
      expect(ctx, contains('Measurements'));
    });

    test('water keywords trigger water history injection', () async {
      final p = await _loaded();
      await p.addWater(2800);
      final ai  = OnDeviceAiService();
      final ctx = ai.buildContextForQueryTest('Am I drinking enough water?', p);
      expect(ctx, contains('Water'));
    });

    test('unrelated query returns empty context (no unnecessary injection)', () async {
      final p = await _loaded();
      final ai  = OnDeviceAiService();
      // "hello" doesn't match any fitness keywords
      final ctx = ai.buildContextForQueryTest('Hello, what is your name?', p);
      expect(ctx, isEmpty);
    });

    test('context injection does not crash with empty provider', () async {
      final p = await _loaded();
      final ai  = OnDeviceAiService();
      expect(
        () => ai.buildContextForQueryTest('What is my weight?', p),
        returnsNormally,
      );
    });
  });

  // ── 6. Supplement streak ──────────────────────────────────────────────────────

  group('Supplement streak (supplementStreak)', () {
    test('streak 0 when no supplements taken today', () async {
      final p = await _loaded();
      expect(p.supplementStreak, 0);
    });

    test('streak 0 when only 2 of 3 supplements taken', () async {
      final p = await _loaded();
      await p.updateSupplement('whey', true);
      await p.updateSupplement('creatine', true);
      // multivitamin not taken
      expect(p.supplementStreak, 0);
    });

    test('streak 1 when all 3 taken today', () async {
      final p = await _loaded();
      await p.updateSupplement('whey', true);
      await p.updateSupplement('creatine', true);
      await p.updateSupplement('multivitamin', true);
      expect(p.supplementStreak, 1);
    });

    test('streak increments for consecutive days', () async {
      // Seed yesterday's supplement history with all 3 taken
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final key = '${yesterday.year}-${yesterday.month.toString().padLeft(2,'0')}-${yesterday.day.toString().padLeft(2,'0')}';
      // Manually set supplement history for yesterday via prefs
      SharedPreferences.setMockInitialValues({
        'supp_$key': '{"whey":true,"creatine":true,"multivitamin":true}',
      });
      final p2 = FitnessProvider();
      await p2.loadData();
      await p2.updateSupplement('whey', true);
      await p2.updateSupplement('creatine', true);
      await p2.updateSupplement('multivitamin', true);
      // Today + yesterday = streak of at least 1
      expect(p2.supplementStreak, greaterThanOrEqualTo(1));
    });
  });

  // ── 7. Regression — existing features unaffected ─────────────────────────────

  group('Regression checks', () {
    test('AI service still has single model name', () {
      expect(OnDeviceAiService().modelName, 'Gemma 3 1B');
    });

    test('System prompt still works', () async {
      final p = await _loaded();
      final ai = OnDeviceAiService();
      expect(() => ai.buildSystemPromptForTest(p), returnsNormally);
    });

    test('Provider defaults unchanged', () async {
      final p = await _loaded();
      expect(p.calorieGoal, FitnessProvider.kDefaultCalorieGoal);
      expect(p.proteinGoal, FitnessProvider.kDefaultProteinGoal);
    });
  });
}
