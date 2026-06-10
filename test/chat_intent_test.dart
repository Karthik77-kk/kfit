// Build 96 — ChatIntent (AI fast-path) tests.
// Greetings and factual lookups must be answered deterministically (no LLM);
// open-ended/coaching questions must defer to the model (factualAnswer == null).
import 'package:flutter_test/flutter_test.dart';
import 'package:karthik_fitness/models/models.dart';
import 'package:karthik_fitness/providers/fitness_provider.dart';
import 'package:karthik_fitness/services/chat_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';

FoodEntry _food(String id, double cal, double prot) => FoodEntry(
      id: id, name: 'Food $id', calories: cal, protein: prot,
      mealType: MealType.lunch, timestamp: DateTime.now(),
    );

Future<FitnessProvider> _seeded({bool body = true}) async {
  final p = FitnessProvider();
  await p.loadData();
  if (body) {
    await p.logBodyEntry(weightKg: 75.0);
    await p.saveHeight(170.0);
    await p.saveAge(24);
  }
  return p;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('isGreeting', () {
    test('plain greetings → true', () {
      for (final g in ['hi', 'Hello', 'hey', 'Hey there', 'thanks!',
          'thank you', 'good morning', 'namaste', 'ok', 'yo']) {
        expect(ChatIntent.isGreeting(g), isTrue, reason: g);
      }
    });

    test('empty / whitespace → false', () {
      expect(ChatIntent.isGreeting(''), isFalse);
      expect(ChatIntent.isGreeting('   '), isFalse);
    });

    test('greeting word + a real question → NOT a greeting', () {
      expect(ChatIntent.isGreeting('hi how should i train'), isFalse);
      expect(ChatIntent.isGreeting('hey what is my weight'), isFalse);
    });

    test('factual / coaching messages → false', () {
      expect(ChatIntent.isGreeting("what's my weight"), isFalse);
      expect(ChatIntent.isGreeting('why am i plateauing'), isFalse);
    });
  });

  group('greetingReply', () {
    test('is friendly and invites questions, no data dump', () async {
      final p = await _seeded();
      final reply = ChatIntent.greetingReply(p);
      expect(reply.toLowerCase(), contains('coach'));
      expect(reply, contains('weight trend'));
    });
  });

  group('factualAnswer — exact lookups', () {
    test('weight question cites the logged weight + goal', () async {
      final p = await _seeded();
      final a = ChatIntent.factualAnswer("what's my weight", p)!;
      expect(a, contains('75.0kg'));
      expect(a, contains('70.0kg')); // default goal
    });

    test('weight with NO data → helpful prompt, not a wrong number', () async {
      final p = await _seeded(body: false);
      final a = ChatIntent.factualAnswer('what is my weight', p)!;
      expect(a.toLowerCase(), contains("haven't logged"));
    });

    test("today's protein cites today's total vs goal", () async {
      final p = await _seeded();
      await p.addFoodEntry(_food('a', 600, 45));
      final a = ChatIntent.factualAnswer('how much protein today', p)!;
      expect(a, contains('protein'));
      expect(a, contains('45/'));
    });

    test('TDEE question returns a calorie figure', () async {
      final p = await _seeded();
      final a = ChatIntent.factualAnswer('what is my tdee', p)!;
      expect(a.toLowerCase(), contains('kcal'));
    });

    test('BMI question returns BMI', () async {
      final p = await _seeded();
      final a = ChatIntent.factualAnswer("what's my bmi", p)!;
      expect(a, contains('BMI'));
    });
  });

  group('factualAnswer — defers to LLM for coaching', () {
    test('open-ended / advice questions → null', () {
      for (final q in [
        'why am i not losing weight',
        'suggest a high protein meal',
        'how do i improve my bench',
        'should i eat more carbs',
        'give me a workout plan',
      ]) {
        // No provider data needed; coaching is detected before data lookup.
        expect(ChatIntent.factualAnswer(q, FitnessProvider()), isNull,
            reason: q);
      }
    });
  });

  group('factualAnswer — more topics', () {
    test('calorie target cites a kcal figure when data exists', () async {
      final p = await _seeded();
      final a = ChatIntent.factualAnswer("what's my calorie target", p)!;
      expect(a.toLowerCase(), contains('kcal'));
    });

    test('calorie target with no body data → prompts to log', () async {
      final p = await _seeded(body: false);
      final a = ChatIntent.factualAnswer('what is my deficit target', p)!;
      expect(a.toLowerCase(), contains('log your weight'));
    });

    test('steps-only today question returns step counts', () async {
      final p = await _seeded();
      final a = ChatIntent.factualAnswer('how many steps today', p)!;
      expect(a, contains('steps'));
      expect(a, isNot(contains('protein')));
    });

    test('water-only today question returns ml', () async {
      final p = await _seeded();
      final a = ChatIntent.factualAnswer('how much water today', p)!;
      expect(a.toLowerCase(), contains('water'));
    });

    test('body composition with no scale → helpful prompt', () async {
      final p = await _seeded();
      final a = ChatIntent.factualAnswer("what's my body fat", p)!;
      expect(a.toLowerCase(), contains('no smart-scale'));
    });

    test('measurements with none logged → helpful prompt', () async {
      final p = await _seeded();
      final a = ChatIntent.factualAnswer('what is my waist size', p)!;
      expect(a.toLowerCase(), contains('no body measurements'));
    });

    test('streak question lists streaks', () async {
      final p = await _seeded();
      final a = ChatIntent.factualAnswer("what's my streak", p)!;
      expect(a.toLowerCase(), contains('workout'));
    });

    test('goal-ETA with insufficient trend → asks for more history', () async {
      final p = await _seeded(); // single weight entry, no trend
      final a = ChatIntent.factualAnswer('when will i reach my goal', p)!;
      expect(a.toLowerCase(), anyOf(contains('weight history'), contains('already')));
    });
  });

  group('isGreeting — more cases', () {
    test('extra greetings → true', () {
      for (final g in ['good evening', 'thx', 'bye', 'yo', 'gn']) {
        expect(ChatIntent.isGreeting(g), isTrue, reason: g);
      }
    });
    test('greeting word + coaching word → false', () {
      expect(ChatIntent.isGreeting('hello can you help me'), isFalse);
    });
  });
}
