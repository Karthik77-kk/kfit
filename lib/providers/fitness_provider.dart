import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:uuid/uuid.dart';
import '../models/models.dart';

class FitnessProvider extends ChangeNotifier {
  // ── Daily targets ──────────────────────────────────────────────────────────
  static const int kCalorieGoal = 1700;
  static const int kProteinGoal = 100;
  static const int kWaterGoalMl = 2500;
  static const int kStepGoal = 8000;

  // ── User profile ───────────────────────────────────────────────────────────
  double _heightCm = 170.0;
  double get heightCm => _heightCm;

  int _age = 24;
  int get age => _age;

  double _goalWeightKg = 70.0;
  double get goalWeightKg => _goalWeightKg;

  // ── State ──────────────────────────────────────────────────────────────────
  List<FoodEntry> _todayFood = [];
  int _todayWaterMl = 0;
  SupplementStatus _supplements = SupplementStatus();
  List<WorkoutLog> _workoutHistory = [];
  List<BodyEntry> _bodyHistory = [];
  bool _isLoaded = false;

  // ── Getters ────────────────────────────────────────────────────────────────
  List<FoodEntry> get todayFood => _todayFood;
  int get todayWaterMl => _todayWaterMl;
  SupplementStatus get supplements => _supplements;
  List<WorkoutLog> get workoutHistory => _workoutHistory;
  List<BodyEntry> get bodyHistory => _bodyHistory;
  bool get isLoaded => _isLoaded;

  double get todayCalories =>
      _todayFood.fold(0.0, (sum, e) => sum + e.calories);
  double get todayProtein =>
      _todayFood.fold(0.0, (sum, e) => sum + e.protein);

  double get calorieProgress =>
      (todayCalories / kCalorieGoal).clamp(0.0, 1.0);
  double get proteinProgress =>
      (todayProtein / kProteinGoal).clamp(0.0, 1.0);
  double get waterProgress =>
      (_todayWaterMl / kWaterGoalMl).clamp(0.0, 1.0);

  // ── Net calories & deficit ─────────────────────────────────────────────────
  int get netCalories => (todayCalories - todayCaloriesBurned).round();
  int get calorieDeficit => (tdee - netCalories).round();
  bool get inDeficit => netCalories < tdee;
  int get caloriesRemaining => (kCalorieGoal - todayCalories).round();

  // ── Body / weight ──────────────────────────────────────────────────────────
  BodyEntry? get latestBodyEntry =>
      _bodyHistory.isEmpty ? null : _bodyHistory.last;

  double? get latestWeightKg => latestBodyEntry?.weightKg;

  double? get bmi {
    final w = latestWeightKg;
    if (w == null || _heightCm <= 0) return null;
    final hm = _heightCm / 100.0;
    return w / (hm * hm);
  }

  String get bmiCategory {
    final b = bmi;
    if (b == null) return '—';
    if (b < 18.5) return 'Underweight';
    if (b < 25.0) return 'Normal';
    if (b < 30.0) return 'Overweight';
    return 'Obese';
  }

  Color bmiColor(BuildContext context) {
    final b = bmi;
    if (b == null) return const Color(0xFF8E8E93);
    if (b < 18.5) return const Color(0xFF40C8E0);
    if (b < 25.0) return const Color(0xFF30D158);
    if (b < 30.0) return const Color(0xFFFF9F0A);
    return const Color(0xFFFF453A);
  }

  int get todaySteps => latestBodyEntry?.steps ?? 0;
  double get stepProgress => (todaySteps / kStepGoal).clamp(0.0, 1.0);

  // ── BMR / TDEE ─────────────────────────────────────────────────────────────
  // Mifflin-St Jeor (male)
  double get bmr {
    final w = latestWeightKg ?? 80.0;
    return (10 * w) + (6.25 * _heightCm) - (5 * _age) + 5;
  }

  double get tdee {
    // 1.375 = lightly active (1-3 days/week), 1.55 = moderately active (3-5)
    final factor = weeklyWorkoutDays >= 4 ? 1.55 : 1.375;
    return bmr * factor;
  }

  double get fatLossCalorieTarget => tdee - 500;

  // ── Goal tracking ──────────────────────────────────────────────────────────
  double get kgToGoal {
    final w = latestWeightKg;
    if (w == null) return 0;
    return (w - _goalWeightKg).abs();
  }

  double get weeksToGoal {
    final wc = weeklyWeightChange;
    if (wc == null || wc >= 0) return double.infinity;
    return kgToGoal / wc.abs();
  }

  // ── Weekly workout days ────────────────────────────────────────────────────
  int get weeklyWorkoutDays {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final days = <int>{};
    for (final w in _workoutHistory) {
      if (w.date.isAfter(cutoff)) {
        days.add(w.date.weekday);
      }
    }
    return days.length;
  }

  /// Returns a Mon-Sun bool list of whether workout logged that day this week
  List<bool> get weeklyWorkoutMap {
    final now = DateTime.now();
    // find Monday of this week
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return List.generate(7, (i) {
      final day = monday.add(Duration(days: i));
      return _workoutHistory.any((w) =>
          w.date.year == day.year &&
          w.date.month == day.month &&
          w.date.day == day.day);
    });
  }

  // ── Progressive overload helpers ───────────────────────────────────────────
  double? getLastExerciseWeight(String exerciseName) {
    for (final w in _workoutHistory.reversed) {
      for (final e in w.exercises) {
        if (e.name == exerciseName && e.sets.isNotEmpty) {
          final weightSets = e.sets.where((s) => s.weight > 0);
          if (weightSets.isNotEmpty) {
            return weightSets.last.weight;
          }
        }
      }
    }
    return null;
  }

  int? getLastExerciseReps(String exerciseName) {
    for (final w in _workoutHistory.reversed) {
      for (final e in w.exercises) {
        if (e.name == exerciseName && e.sets.isNotEmpty) {
          return e.sets.last.reps;
        }
      }
    }
    return null;
  }

  /// Best (heaviest) weight × reps ever for an exercise
  double? getPersonalRecord(String exerciseName) {
    double? best;
    for (final w in _workoutHistory) {
      for (final e in w.exercises) {
        if (e.name == exerciseName) {
          for (final s in e.sets) {
            final score = s.weight * s.reps;
            if (best == null || score > best) best = score;
          }
        }
      }
    }
    return best;
  }

  // ── Weight regression (linear) ─────────────────────────────────────────────
  /// Returns (slope_kg_per_day, intercept) or null if insufficient data
  ({double slope, double intercept})? get _weightRegression {
    final entries = _bodyHistory.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (entries.length < 3) return null;

    final first = entries.first.date;
    final xs = entries
        .map((e) => e.date.difference(first).inHours / 24.0)
        .toList();
    final ys = entries.map((e) => e.weightKg).toList();

    final n = xs.length;
    final xMean = xs.reduce((a, b) => a + b) / n;
    final yMean = ys.reduce((a, b) => a + b) / n;

    double num = 0, den = 0;
    for (int i = 0; i < n; i++) {
      num += (xs[i] - xMean) * (ys[i] - yMean);
      den += (xs[i] - xMean) * (xs[i] - xMean);
    }
    if (den == 0) return null;

    final slope = num / den;
    final intercept = yMean - slope * xMean;
    return (slope: slope, intercept: intercept);
  }

  double? predictedWeightInDays(int days) {
    final reg = _weightRegression;
    if (reg == null) return null;
    final latest = _bodyHistory.last;
    final first = _bodyHistory.first;
    final xNow = latest.date.difference(first.date).inHours / 24.0;
    return reg.slope * (xNow + days) + reg.intercept;
  }

  /// kg/week trend (negative = losing weight)
  double? get weeklyWeightChange {
    final reg = _weightRegression;
    if (reg == null) return null;
    return reg.slope * 7;
  }

  /// List of (date, predicted_weight) for the next [days] days
  List<(DateTime, double)> weightForecast({int days = 30}) {
    final reg = _weightRegression;
    if (reg == null || _bodyHistory.isEmpty) return [];

    final first = _bodyHistory.first;
    final latest = _bodyHistory.last;
    final xNow = latest.date.difference(first.date).inHours / 24.0;
    final now = latest.date;

    return List.generate(days + 1, (i) {
      final x = xNow + i;
      final weight = (reg.slope * x + reg.intercept).clamp(30.0, 300.0);
      return (now.add(Duration(days: i)), weight);
    });
  }

  DateTime? get estimatedGoalDate {
    final reg = _weightRegression;
    if (reg == null || _bodyHistory.isEmpty) return null;
    if (reg.slope >= 0) return null; // not losing weight

    final first = _bodyHistory.first;
    final xGoal = (_goalWeightKg - reg.intercept) / reg.slope;
    final daysFromFirst = xGoal.round();
    final goalDate = first.date.add(Duration(days: daysFromFirst));

    // Sanity check: must be in future and within 2 years
    final now = DateTime.now();
    if (goalDate.isBefore(now)) return null;
    if (goalDate.isAfter(now.add(const Duration(days: 730)))) return null;
    return goalDate;
  }

  // ── Food grouped ──────────────────────────────────────────────────────────
  List<FoodEntry> get breakfastEntries =>
      _todayFood.where((e) => e.mealType == MealType.breakfast).toList();
  List<FoodEntry> get lunchEntries =>
      _todayFood.where((e) => e.mealType == MealType.lunch).toList();
  List<FoodEntry> get dinnerEntries =>
      _todayFood.where((e) => e.mealType == MealType.dinner).toList();
  List<FoodEntry> get snackEntries =>
      _todayFood.where((e) => e.mealType == MealType.snack).toList();

  // ── Workout ────────────────────────────────────────────────────────────────
  WorkoutLog? get todayWorkout {
    final now = DateTime.now();
    try {
      return _workoutHistory.lastWhere((w) =>
          w.date.year == now.year &&
          w.date.month == now.month &&
          w.date.day == now.day);
    } catch (_) {
      return null;
    }
  }

  List<WorkoutLog> getRecentWorkouts({int days = 14}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _workoutHistory
        .where((w) => w.date.isAfter(cutoff))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  int get workoutStreak {
    int streak = 0;
    DateTime check = DateTime.now();
    for (int i = 0; i < 60; i++) {
      final hasWorkout = _workoutHistory.any((w) =>
          w.date.year == check.year &&
          w.date.month == check.month &&
          w.date.day == check.day);
      if (hasWorkout) {
        streak++;
        check = check.subtract(const Duration(days: 1));
      } else if (i == 0) {
        check = check.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  int get todayCaloriesBurned => todayWorkout?.caloriesBurned ?? 0;

  int get weeklyCaloriesBurned {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return _workoutHistory
        .where((w) => w.date.isAfter(cutoff))
        .fold(0, (sum, w) => sum + w.caloriesBurned);
  }

  List<BodyEntry> getRecentBodyEntries({int days = 30}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _bodyHistory
        .where((e) => e.date.isAfter(cutoff))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  double? get weightChangeKg {
    final recent = getRecentBodyEntries(days: 30);
    if (recent.length < 2) return null;
    return recent.last.weightKg - recent.first.weightKg;
  }

  // ── Persistence ────────────────────────────────────────────────────────────
  String get _todayKey {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // User profile
    _heightCm = prefs.getDouble('height_cm') ?? 170.0;
    _age = prefs.getInt('user_age') ?? 24;
    _goalWeightKg = prefs.getDouble('goal_weight_kg') ?? 70.0;

    // Food
    final foodJson = prefs.getString('food_$_todayKey');
    if (foodJson != null) {
      final list = jsonDecode(foodJson) as List;
      _todayFood = list.map((e) => FoodEntry.fromJson(e)).toList();
    }

    // Water
    _todayWaterMl = prefs.getInt('water_$_todayKey') ?? 0;

    // Supplements
    final suppJson = prefs.getString('supp_$_todayKey');
    if (suppJson != null) {
      _supplements = SupplementStatus.fromJson(jsonDecode(suppJson));
    } else {
      _supplements = SupplementStatus();
    }

    // Workouts
    final workoutJson = prefs.getString('workouts');
    if (workoutJson != null) {
      final list = jsonDecode(workoutJson) as List;
      _workoutHistory = list.map((e) => WorkoutLog.fromJson(e)).toList();
    }

    // Body history
    final bodyJson = prefs.getString('body_history');
    if (bodyJson != null) {
      final list = jsonDecode(bodyJson) as List;
      _bodyHistory = list.map((e) => BodyEntry.fromJson(e)).toList();
      _bodyHistory.sort((a, b) => a.date.compareTo(b.date));
    }

    _isLoaded = true;
    notifyListeners();
  }

  // ── Food actions ───────────────────────────────────────────────────────────
  Future<void> addFoodEntry(FoodEntry entry) async {
    _todayFood.add(entry);
    await _saveFoodEntries();
    notifyListeners();
  }

  Future<void> removeFoodEntry(String id) async {
    _todayFood.removeWhere((e) => e.id == id);
    await _saveFoodEntries();
    notifyListeners();
  }

  Future<void> _saveFoodEntries() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'food_$_todayKey',
      jsonEncode(_todayFood.map((e) => e.toJson()).toList()),
    );
  }

  // ── Water actions ──────────────────────────────────────────────────────────
  Future<void> addWater(int ml) async {
    _todayWaterMl += ml;
    await _saveWater();
    notifyListeners();
  }

  Future<void> removeWater(int ml) async {
    _todayWaterMl = (_todayWaterMl - ml).clamp(0, 99999);
    await _saveWater();
    notifyListeners();
  }

  Future<void> _saveWater() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('water_$_todayKey', _todayWaterMl);
  }

  // ── Supplement actions ─────────────────────────────────────────────────────
  Future<void> updateSupplement(String key, bool value) async {
    switch (key) {
      case 'whey':
        _supplements.whey = value;
        break;
      case 'creatine':
        _supplements.creatine = value;
        break;
      case 'multivitamin':
        _supplements.multivitamin = value;
        break;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('supp_$_todayKey', jsonEncode(_supplements.toJson()));
    notifyListeners();
  }

  // ── Workout actions ────────────────────────────────────────────────────────
  Future<void> logWorkout(WorkoutLog workout) async {
    _workoutHistory.add(workout);
    final cutoff = DateTime.now().subtract(const Duration(days: 90));
    _workoutHistory.removeWhere((w) => w.date.isBefore(cutoff));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'workouts',
      jsonEncode(_workoutHistory.map((w) => w.toJson()).toList()),
    );
    notifyListeners();
  }

  // ── Body / weight actions ──────────────────────────────────────────────────
  Future<void> logBodyEntry({required double weightKg, int steps = 0}) async {
    final now = DateTime.now();
    _bodyHistory.removeWhere((e) =>
        e.date.year == now.year &&
        e.date.month == now.month &&
        e.date.day == now.day);

    _bodyHistory.add(BodyEntry(
      id: const Uuid().v4(),
      date: now,
      weightKg: weightKg,
      steps: steps,
    ));
    _bodyHistory.sort((a, b) => a.date.compareTo(b.date));

    final cutoff = now.subtract(const Duration(days: 180));
    _bodyHistory.removeWhere((e) => e.date.isBefore(cutoff));

    await _saveBodyHistory();
    notifyListeners();
  }

  Future<void> updateTodaySteps(int steps) async {
    final now = DateTime.now();
    final todayEntry = _bodyHistory.where((e) =>
        e.date.year == now.year &&
        e.date.month == now.month &&
        e.date.day == now.day).toList();

    if (todayEntry.isNotEmpty) {
      _bodyHistory.removeWhere((e) =>
          e.date.year == now.year &&
          e.date.month == now.month &&
          e.date.day == now.day);
      _bodyHistory.add(BodyEntry(
        id: todayEntry.first.id,
        date: todayEntry.first.date,
        weightKg: todayEntry.first.weightKg,
        steps: steps,
      ));
    } else {
      _bodyHistory.add(BodyEntry(
        id: const Uuid().v4(),
        date: now,
        weightKg: latestWeightKg ?? 70.0,
        steps: steps,
      ));
    }
    _bodyHistory.sort((a, b) => a.date.compareTo(b.date));
    await _saveBodyHistory();
    notifyListeners();
  }

  Future<void> _saveBodyHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'body_history',
      jsonEncode(_bodyHistory.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> saveHeight(double cm) async {
    _heightCm = cm;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('height_cm', cm);
    notifyListeners();
  }

  Future<void> saveAge(int years) async {
    _age = years;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_age', years);
    notifyListeners();
  }

  Future<void> saveGoalWeight(double kg) async {
    _goalWeightKg = kg;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('goal_weight_kg', kg);
    notifyListeners();
  }

  // Helper
  String newId() => const Uuid().v4();
}
