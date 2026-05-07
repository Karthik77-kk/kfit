import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/models.dart';

class FitnessProvider extends ChangeNotifier {
  // ── Daily targets ──────────────────────────────────────────────────────────
  static const int kCalorieGoal = 1700;
  static const int kProteinGoal = 100;
  static const int kWaterGoalMl = 2500;

  // ── State ──────────────────────────────────────────────────────────────────
  List<FoodEntry> _todayFood = [];
  int _todayWaterMl = 0;
  SupplementStatus _supplements = SupplementStatus();
  List<WorkoutLog> _workoutHistory = [];
  bool _isLoaded = false;

  // ── Getters ────────────────────────────────────────────────────────────────
  List<FoodEntry> get todayFood => _todayFood;
  int get todayWaterMl => _todayWaterMl;
  SupplementStatus get supplements => _supplements;
  List<WorkoutLog> get workoutHistory => _workoutHistory;
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

  List<FoodEntry> get breakfastEntries =>
      _todayFood.where((e) => e.mealType == MealType.breakfast).toList();
  List<FoodEntry> get lunchEntries =>
      _todayFood.where((e) => e.mealType == MealType.lunch).toList();
  List<FoodEntry> get dinnerEntries =>
      _todayFood.where((e) => e.mealType == MealType.dinner).toList();
  List<FoodEntry> get snackEntries =>
      _todayFood.where((e) => e.mealType == MealType.snack).toList();

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
        // No workout today yet – don't break streak, check yesterday
        check = check.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  // ── Persistence ────────────────────────────────────────────────────────────
  String get _todayKey {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();

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
    // Keep only last 90 days
    final cutoff = DateTime.now().subtract(const Duration(days: 90));
    _workoutHistory.removeWhere((w) => w.date.isBefore(cutoff));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'workouts',
      jsonEncode(_workoutHistory.map((w) => w.toJson()).toList()),
    );
    notifyListeners();
  }

  // Helper to create a new food entry id
  String newId() => const Uuid().v4();
}
