import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:uuid/uuid.dart';
import 'package:pedometer/pedometer.dart';

import '../models/models.dart';

class FitnessProvider extends ChangeNotifier {
  // ── Daily targets (defaults — overridden by user settings) ────────────────
  static const int kDefaultCalorieGoal = 1700;
  static const int kDefaultProteinGoal = 100;
  static const int kDefaultWaterGoalMl = 2500;
  static const int kDefaultStepGoal = 8000;

  // Mutable goals (loaded from prefs, fallback to defaults)
  int _calorieGoal = kDefaultCalorieGoal;
  int _proteinGoal = kDefaultProteinGoal;
  int _waterGoalMl = kDefaultWaterGoalMl;
  int _stepGoal = kDefaultStepGoal;

  int get calorieGoal => _calorieGoal;
  int get proteinGoal => _proteinGoal;
  int get waterGoalMl => _waterGoalMl;
  int get stepGoal => _stepGoal;

  // Keep static consts as aliases so old static references compile
  static const int kCalorieGoal = kDefaultCalorieGoal;
  static const int kProteinGoal = kDefaultProteinGoal;
  static const int kWaterGoalMl = kDefaultWaterGoalMl;
  static const int kStepGoal = kDefaultStepGoal;

  Future<void> saveCalorieGoal(int kcal) async {
    _calorieGoal = kcal.clamp(800, 5000);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('calorie_goal', _calorieGoal);
    notifyListeners();
  }

  Future<void> saveProteinGoal(int g) async {
    _proteinGoal = g.clamp(20, 300);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('protein_goal', _proteinGoal);
    notifyListeners();
  }

  Future<void> saveWaterGoal(int ml) async {
    _waterGoalMl = ml.clamp(500, 8000);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('water_goal_ml', _waterGoalMl);
    notifyListeners();
  }

  Future<void> saveStepGoal(int steps) async {
    _stepGoal = steps.clamp(1000, 30000);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('step_goal', _stepGoal);
    notifyListeners();
  }

  // ── User profile ───────────────────────────────────────────────────────────
  double _heightCm = 160.0;
  double get heightCm => _heightCm;

  int _age = 24; // Karthik's age
  int get age => _age;

  double _goalWeightKg = 70.0;
  double get goalWeightKg => _goalWeightKg;

  String _userName = 'Karthik';
  String get userName => _userName;

  Future<void> saveUserName(String name) async {
    _userName = name.trim().isEmpty ? 'Karthik' : name.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _userName);
    notifyListeners();
  }

  // ── State ──────────────────────────────────────────────────────────────────
  List<FoodEntry> _todayFood = [];
  int _todayWaterMl = 0;
  SupplementStatus _supplements = SupplementStatus();
  List<WorkoutLog> _workoutHistory = [];
  List<BodyEntry> _bodyHistory = [];
  List<SmartScaleEntry> _scaleHistory = [];
  bool _isLoaded = false;

  // ── Historical data (last 30 days, loaded at startup) ──────────────────────
  Map<String, List<FoodEntry>> _foodHistory = {};
  Map<String, int> _waterHistory = {};
  Map<String, SupplementStatus> _supplementHistory = {};

  // ── Pedometer ──────────────────────────────────────────────────────────────
  StreamSubscription<StepCount>? _stepSubscription;
  int _livePedometerTotal = 0;   // cumulative total from sensor
  int _pedometerDayBaseline = -1; // sensor total at start of today
  String _pedometerBaselineDate = '';

  // ── Day-reset detection ────────────────────────────────────────────────────
  String _loadedForDate = '';
  Timer? _dayResetTimer;

  // ── Water reminder interval ────────────────────────────────────────────────
  int _waterReminderIntervalHours = 1;
  int get waterReminderIntervalHours => _waterReminderIntervalHours;

  Future<void> setWaterReminderInterval(int hours) async {
    _waterReminderIntervalHours = hours.clamp(1, 6);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('water_reminder_interval', _waterReminderIntervalHours);
    notifyListeners();
  }

  // ── Walk reminder interval ─────────────────────────────────────────────────
  int _walkReminderIntervalHours = 2;
  int get walkReminderIntervalHours => _walkReminderIntervalHours;

  Future<void> setWalkReminderInterval(int hours) async {
    _walkReminderIntervalHours = hours.clamp(1, 4);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('walk_reminder_interval', _walkReminderIntervalHours);
    notifyListeners();
  }

  // ── Getters ────────────────────────────────────────────────────────────────
  List<FoodEntry> get todayFood => _todayFood;
  int get todayWaterMl => _todayWaterMl;
  SupplementStatus get supplements => _supplements;
  List<WorkoutLog> get workoutHistory => _workoutHistory;
  List<BodyEntry> get bodyHistory => _bodyHistory;
  List<SmartScaleEntry> get scaleHistory => _scaleHistory;
  SmartScaleEntry? get latestScaleEntry =>
      _scaleHistory.isEmpty ? null : _scaleHistory.last;
  bool get isLoaded => _isLoaded;

  /// All food entries keyed by 'YYYY-MM-DD', including today's.
  Map<String, List<FoodEntry>> get foodHistory =>
      {..._foodHistory, _todayKey: _todayFood};

  /// Water intake (mL) keyed by 'YYYY-MM-DD', including today's.
  Map<String, int> get waterHistory =>
      {..._waterHistory, _todayKey: _todayWaterMl};

  /// Supplement status keyed by 'YYYY-MM-DD', including today's.
  Map<String, SupplementStatus> get supplementHistory =>
      {..._supplementHistory, _todayKey: _supplements};

  /// TDEE rounded to nearest kcal.
  int get tdeeKcal => (tdee ?? 0).round();

  double get todayCalories =>
      _todayFood.fold(0.0, (sum, e) => sum + e.calories);
  double get todayProtein =>
      _todayFood.fold(0.0, (sum, e) => sum + e.protein);

  /// Calories from checked supplements (whey protein = 120 kcal per scoop)
  double get supplementCalories => _supplements.whey ? 120.0 : 0.0;

  /// Protein from checked supplements (whey = 25g)
  double get supplementProtein => _supplements.whey ? 25.0 : 0.0;

  /// Total calories including supplements
  double get todayCaloriesTotal => todayCalories + supplementCalories;

  /// Total protein including supplements
  double get todayProteinTotal => todayProtein + supplementProtein;

  double get calorieProgress =>
      (todayCaloriesTotal / calorieGoal).clamp(0.0, 1.0);
  double get proteinProgress =>
      (todayProteinTotal / proteinGoal).clamp(0.0, 1.0);
  double get waterProgress =>
      (_todayWaterMl / waterGoalMl).clamp(0.0, 1.0);

  // ── Net calories & deficit ─────────────────────────────────────────────────
  /// Calories eaten minus calories burned from workout
  int get netCalories => (todayCaloriesTotal - todayCaloriesBurned).round();

  /// Positive = deficit (good for fat loss), Negative = surplus
  int get calorieDeficit => calorieGoal - netCalories;

  /// True if currently in a calorie deficit
  bool get inDeficit => netCalories < calorieGoal;

  /// Remaining calories left to eat (vs goal). Can be negative if over.
  int get caloriesRemaining => calorieGoal - todayCaloriesTotal.round();

  // ── Body / weight ──────────────────────────────────────────────────────────
  BodyEntry? get latestBodyEntry =>
      _bodyHistory.isEmpty ? null : _bodyHistory.last;

  double? get latestWeightKg =>
      latestScaleEntry?.weightKg ?? latestBodyEntry?.weightKg;

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

  /// BMR — prefer scale BMR if available (scale's measurement is more accurate)
  double? get bmr {
    final scaleBmr = latestScaleEntry?.bmr;
    if (scaleBmr != null && scaleBmr > 0) return scaleBmr;
    final w = latestWeightKg;
    if (w == null) return null;
    return 10 * w + 6.25 * _heightCm - 5 * _age + 5;
  }

  /// TDEE = BMR × activity multiplier (standard Harris-Benedict activity factors)
  double? get tdee {
    final b = bmr;
    if (b == null) return null;
    final days = weeklyWorkoutDays;
    final multiplier = days >= 6 ? 1.725   // very active
        : days >= 4 ? 1.55                 // moderately active
        : days >= 2 ? 1.375                // lightly active
        : 1.2;                             // sedentary
    return b * multiplier;
  }

  /// Suggested calorie deficit for fat loss (500 below TDEE)
  double? get fatLossCalorieTarget {
    final t = tdee;
    if (t == null) return null;
    return (t - 500).clamp(1200, 3500);
  }

  /// kg remaining to reach goal weight (negative = already below goal)
  double? get kgToGoal {
    final w = latestWeightKg;
    if (w == null) return null;
    return w - _goalWeightKg;
  }

  /// Estimated weeks to reach goal at current deficit
  double? get weeksToGoal {
    final kg = kgToGoal;
    final deficit = calorieDeficit;
    if (kg == null || kg <= 0 || deficit <= 0) return null;
    final daysPerKg = 7700 / deficit;
    return (kg * daysPerKg / 7).clamp(0, 999);
  }

  /// True when pedometer is actively delivering data
  bool get hasPedometerData =>
      _pedometerDayBaseline >= 0 && _livePedometerTotal >= _pedometerDayBaseline;

  /// Live steps if pedometer available, otherwise last manually-logged steps.
  int get todaySteps {
    if (hasPedometerData) {
      return math.max(0, _livePedometerTotal - _pedometerDayBaseline);
    }
    return latestBodyEntry?.steps ?? 0;
  }

  double get stepProgress => (todaySteps / stepGoal).clamp(0.0, 1.0);

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
  /// All WorkoutLog entries saved today (may be multiple if user saved in batches).
  List<WorkoutLog> get todayWorkouts {
    final now = DateTime.now();
    return _workoutHistory.where((w) =>
        w.date.year == now.year &&
        w.date.month == now.month &&
        w.date.day == now.day).toList();
  }

  /// Last workout logged today — kept for backward compatibility with home screen.
  WorkoutLog? get todayWorkout {
    final list = todayWorkouts;
    return list.isEmpty ? null : list.last;
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

  /// Consecutive days (including today) where ≥500 kcal was logged.
  /// Simple threshold — rewards logging, not perfection.
  int get calorieStreak {
    int streak = 0;
    final today = DateTime.now();

    // Check today first (include supplement calories in threshold)
    final todayCals = _todayFood.fold(0.0, (s, e) => s + e.calories) + supplementCalories;
    if (todayCals >= 500) streak++;

    // Walk backwards through history (include supplement calories for past days too)
    for (int i = 1; i <= 60; i++) {
      final d = today.subtract(Duration(days: i));
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final foods = _foodHistory[key];
      final supp = _supplementHistory[key];
      final dayFoodCals = foods?.fold(0.0, (s, e) => s + e.calories) ?? 0.0;
      final daySuppCals = (supp?.whey ?? false) ? 120.0 : 0.0;
      final dayCals = dayFoodCals + daySuppCals;
      if (dayCals >= 500) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  /// MET values for exercises (metabolic equivalent of task)
  static const Map<String, double> _exerciseMet = {
    'Running': 9.8, 'Cycling': 8.0, 'Jump Rope': 12.3, 'Swimming': 8.0,
    'HIIT': 10.0, 'Burpees': 8.0, 'Walking': 3.5, 'Jumping Jacks': 8.0,
    'Sprinting': 13.5, 'Sprints': 13.5, 'Stair Climbing': 8.0, 'Elliptical': 5.5,
    'Rowing': 7.0, 'Rowing Machine': 7.0, 'Boxing': 9.8, 'Kickboxing': 9.0,
    'Yoga': 3.0, 'Pilates': 3.5, 'Stretching': 2.5,
    'Rock Climbing': 8.0, 'Hiking': 6.0, 'Dancing': 5.0,
    'Default': 5.0, // strength training
  };

  int calculateWorkoutCalories(WorkoutLog w) {
    final weight = latestWeightKg ?? 70.0;
    int total = 0;
    for (final ex in w.exercises) {
      final met = _exerciseMet[ex.name] ?? _exerciseMet['Default']!;
      final sets = ex.sets.length;
      final durationMin = sets > 0 ? (sets * 2.25) : 2.0;
      total += (met * weight * durationMin / 60).round();
    }
    return total;
  }

  /// Sum of calories burned across ALL workouts logged today.
  int get todayCaloriesBurned {
    return todayWorkouts.fold(0, (sum, w) => sum + calculateWorkoutCalories(w));
  }

  /// Calories burned from resting (BMR prorated to time of day)
  double get restingCaloriesBurned {
    final b = bmr;
    if (b == null) return 0;
    final now = DateTime.now();
    final minutesElapsed = now.hour * 60 + now.minute;
    return b * (minutesElapsed / 1440.0);
  }

  /// Calories burned from steps (walking)
  double get walkingCaloriesBurned {
    final w = latestWeightKg ?? 70.0;
    return todaySteps * 0.04 * (w / 70.0);
  }

  /// Total calories burned today = resting + walking + workout
  double get totalCaloriesBurned =>
      restingCaloriesBurned + walkingCaloriesBurned + todayCaloriesBurned;

  /// Net calories = eaten (incl. supplements) - total burned
  double get netCaloriesDouble => todayCaloriesTotal - totalCaloriesBurned;

  int get weeklyCaloriesBurned {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return _workoutHistory
        .where((w) => w.date.isAfter(cutoff))
        .fold(0, (sum, w) => sum + calculateWorkoutCalories(w));
  }

  /// Number of distinct days with a workout in the last 7 days
  int get weeklyWorkoutDays {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final days = _workoutHistory
        .where((w) => w.date.isAfter(cutoff))
        .map((w) =>
            '${w.date.year}-${w.date.month}-${w.date.day}')
        .toSet();
    return days.length;
  }

  /// Get the last logged weight (kg) for a given exercise name.
  double? getLastExerciseWeight(String exerciseName) {
    for (final workout in _workoutHistory.reversed) {
      for (final ex in workout.exercises) {
        if (ex.name == exerciseName) {
          final nonZero = ex.sets.where((s) => s.weight > 0).toList();
          if (nonZero.isNotEmpty) return nonZero.last.weight;
        }
      }
    }
    return null;
  }

  /// Get the last logged reps for a given exercise name.
  int? getLastExerciseReps(String exerciseName) {
    for (final workout in _workoutHistory.reversed) {
      for (final ex in workout.exercises) {
        if (ex.name == exerciseName && ex.sets.isNotEmpty) {
          return ex.sets.last.reps;
        }
      }
    }
    return null;
  }

  /// Max weight ever lifted for an exercise (personal record)
  double? getPersonalRecord(String exerciseName) {
    double? max;
    for (final workout in _workoutHistory) {
      for (final ex in workout.exercises) {
        if (ex.name == exerciseName) {
          for (final s in ex.sets) {
            if (s.weight > 0 && (max == null || s.weight > max)) {
              max = s.weight;
            }
          }
        }
      }
    }
    return max;
  }

  /// Days of the current week (Mon-Sun) with workout done
  List<bool> get weeklyWorkoutMap {
    final now = DateTime.now();
    final weekday = now.weekday;
    final result = List<bool>.filled(7, false);
    for (int i = 0; i < 7; i++) {
      final day = now.subtract(Duration(days: weekday - 1 - i));
      result[i] = _workoutHistory.any((w) =>
          w.date.year == day.year &&
          w.date.month == day.month &&
          w.date.day == day.day);
    }
    return result;
  }

  // ── Persistence ────────────────────────────────────────────────────────────
  String get _todayKey {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // User profile
    _heightCm = prefs.getDouble('height_cm') ?? 160.0;
    _age = prefs.getInt('age') ?? 24;
    _goalWeightKg = prefs.getDouble('goal_weight_kg') ?? 70.0;
    _userName = prefs.getString('user_name') ?? 'Karthik';

    // Reminder intervals
    _waterReminderIntervalHours = prefs.getInt('water_reminder_interval') ?? 1;
    _walkReminderIntervalHours = prefs.getInt('walk_reminder_interval') ?? 2;

    // User-defined goals
    _calorieGoal = prefs.getInt('calorie_goal') ?? kDefaultCalorieGoal;
    _proteinGoal = prefs.getInt('protein_goal') ?? kDefaultProteinGoal;
    _waterGoalMl = prefs.getInt('water_goal_ml') ?? kDefaultWaterGoalMl;
    _stepGoal = prefs.getInt('step_goal') ?? kDefaultStepGoal;

    // Always reset today's data first (handles midnight day-change case)
    _todayFood = [];
    _todayWaterMl = 0;
    _supplements = SupplementStatus();

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

    // Smart scale history
    final scaleJson = prefs.getString('scale_history');
    if (scaleJson != null) {
      final list = jsonDecode(scaleJson) as List;
      _scaleHistory = list.map((e) => SmartScaleEntry.fromJson(e)).toList();
      _scaleHistory.sort((a, b) => a.date.compareTo(b.date));
    }

    // Historical food, water, supplement for last 60 days
    // (60 matches the calorieStreak look-back window)
    _foodHistory = {};
    _waterHistory = {};
    _supplementHistory = {};
    for (int i = 1; i <= 60; i++) {
      final date = DateTime.now().subtract(Duration(days: i));
      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final fJson = prefs.getString('food_$key');
      if (fJson != null) {
        try {
          final list = jsonDecode(fJson) as List;
          _foodHistory[key] = list.map((e) => FoodEntry.fromJson(e)).toList();
        } catch (_) {}
      }

      final w = prefs.getInt('water_$key');
      if (w != null) _waterHistory[key] = w;

      final sJson = prefs.getString('supp_$key');
      if (sJson != null) {
        try {
          _supplementHistory[key] =
              SupplementStatus.fromJson(jsonDecode(sJson));
        } catch (_) {}
      }
    }

    _isLoaded = true;
    _loadedForDate = _todayKey;
    notifyListeners();

    // Start pedometer after data is loaded (non-blocking)
    startPedometer();

    // Start day-reset watcher (detects midnight crossover while app is open)
    _startDayResetTimer();
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
    await prefs.setString(
        'supp_$_todayKey', jsonEncode(_supplements.toJson()));
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
    final todayEntry = _bodyHistory
        .where((e) =>
            e.date.year == now.year &&
            e.date.month == now.month &&
            e.date.day == now.day)
        .toList();

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

  // ── Smart Scale actions ────────────────────────────────────────────────────
  Future<void> logScaleEntry(SmartScaleEntry entry) async {
    final now = DateTime.now();
    _scaleHistory.removeWhere((e) =>
        e.date.year == now.year &&
        e.date.month == now.month &&
        e.date.day == now.day);
    _scaleHistory.add(entry);
    _scaleHistory.sort((a, b) => a.date.compareTo(b.date));
    final cutoff = now.subtract(const Duration(days: 365));
    _scaleHistory.removeWhere((e) => e.date.isBefore(cutoff));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'scale_history',
      jsonEncode(_scaleHistory.map((e) => e.toJson()).toList()),
    );
    // Also update bodyHistory weight to match scale
    await logBodyEntry(weightKg: entry.weightKg);
    notifyListeners();
  }

  // ── Export / Import ────────────────────────────────────────────────────────
  Future<String> exportAllData() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    final Map<String, dynamic> data = {};
    for (final key in allKeys) {
      final val = prefs.get(key);
      data[key] = val;
    }
    // Write to app documents directory
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String()
        .replaceAll(':', '-').replaceAll('.', '-').substring(0, 19);
    final fileName = 'kfitness_backup_$timestamp.json';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(jsonEncode(data));
    return file.path;
  }

  Future<bool> importAllData(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;
      final content = await file.readAsString();
      final Map<String, dynamic> data = jsonDecode(content);
      final prefs = await SharedPreferences.getInstance();
      for (final entry in data.entries) {
        final val = entry.value;
        if (val is String) await prefs.setString(entry.key, val);
        else if (val is int) await prefs.setInt(entry.key, val);
        else if (val is double) await prefs.setDouble(entry.key, val);
        else if (val is bool) await prefs.setBool(entry.key, val);
      }
      await loadData(); // reload everything
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Weight Prediction (Linear Regression) ─────────────────────────────────
  ({double slope, double intercept})? get _weightRegression {
    final entries = getRecentBodyEntries(days: 90);
    if (entries.length < 3) return null;

    final first = entries.first.date.millisecondsSinceEpoch.toDouble();
    final xs = entries
        .map((e) => (e.date.millisecondsSinceEpoch - first) / 86400000.0)
        .toList();
    final ys = entries.map((e) => e.weightKg).toList();
    final n = xs.length;
    final xMean = xs.reduce((a, b) => a + b) / n;
    final yMean = ys.reduce((a, b) => a + b) / n;
    final num = xs.asMap().entries
        .map((e) => (e.value - xMean) * (ys[e.key] - yMean))
        .reduce((a, b) => a + b);
    final den = xs.map((x) => (x - xMean) * (x - xMean)).reduce((a, b) => a + b);
    if (den == 0) return null;
    final slope = num / den;
    final intercept = yMean - slope * xMean;
    return (slope: slope, intercept: intercept);
  }

  double? predictedWeightInDays(int days) {
    final reg = _weightRegression;
    if (reg == null) return null;
    final entries = getRecentBodyEntries(days: 90);
    if (entries.isEmpty) return null;
    final first = entries.first.date.millisecondsSinceEpoch.toDouble();
    final today = DateTime.now().millisecondsSinceEpoch.toDouble();
    final x = (today - first) / 86400000.0 + days;
    return reg.intercept + reg.slope * x;
  }

  double? get weeklyWeightChange {
    final reg = _weightRegression;
    if (reg == null) return null;
    return reg.slope * 7;
  }

  List<(DateTime, double)> weightForecast({int days = 30}) {
    final reg = _weightRegression;
    if (reg == null) return [];
    final entries = getRecentBodyEntries(days: 90);
    if (entries.isEmpty) return [];
    final first = entries.first.date.millisecondsSinceEpoch.toDouble();
    final today = DateTime.now();
    return List.generate(days, (i) {
      final d = today.add(Duration(days: i + 1));
      final x = (d.millisecondsSinceEpoch - first) / 86400000.0;
      return (d, reg.intercept + reg.slope * x);
    });
  }

  DateTime? get estimatedGoalDate {
    final reg = _weightRegression;
    final w = latestWeightKg;
    if (reg == null || w == null) return null;
    if (reg.slope >= 0 && w > _goalWeightKg) return null;
    final entries = getRecentBodyEntries(days: 90);
    if (entries.isEmpty) return null;
    final first = entries.first.date.millisecondsSinceEpoch.toDouble();
    final today = DateTime.now().millisecondsSinceEpoch.toDouble();
    final x0 = (today - first) / 86400000.0;
    if (reg.slope == 0) return null;
    final xGoal = (_goalWeightKg - reg.intercept) / reg.slope;
    final daysToGoal = xGoal - x0;
    if (daysToGoal < 0 || daysToGoal > 730) return null;
    return DateTime.now().add(Duration(days: daysToGoal.round()));
  }

  Future<void> saveAge(int years) async {
    _age = years.clamp(10, 100);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('age', _age);
    notifyListeners();
  }

  Future<void> saveGoalWeight(double kg) async {
    _goalWeightKg = kg.clamp(30, 300);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('goal_weight_kg', _goalWeightKg);
    notifyListeners();
  }

  // ── Day-reset timer ────────────────────────────────────────────────────────
  /// Fires every minute. If the calendar date has changed since last load,
  /// saves the current live step count as the new day's baseline (so steps
  /// walked before midnight are preserved), then calls loadData().
  void _startDayResetTimer() {
    _dayResetTimer?.cancel();
    _dayResetTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      if (_loadedForDate.isNotEmpty && _loadedForDate != _todayKey) {
        // Before reloading, anchor the step baseline at the midnight crossover.
        // This ensures steps walked before first app-open of the new day are kept.
        if (_livePedometerTotal > 0) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('pedometer_baseline', _livePedometerTotal);
          await prefs.setString('pedometer_date', _todayKey);
          _pedometerDayBaseline = _livePedometerTotal;
          _pedometerBaselineDate = _todayKey;
        }
        await loadData(); // new day detected
      }
    });
  }

  // ── Pedometer ──────────────────────────────────────────────────────────────
  Future<void> startPedometer() async {
    final prefs = await SharedPreferences.getInstance();
    _pedometerBaselineDate = prefs.getString('pedometer_date') ?? '';
    _pedometerDayBaseline  = prefs.getInt('pedometer_baseline') ?? -1;

    if (_pedometerBaselineDate != _todayKey) {
      _pedometerDayBaseline = -1;
      _pedometerBaselineDate = '';
    }

    _stepSubscription?.cancel();
    try {
      _stepSubscription = Pedometer.stepCountStream.listen(
        (StepCount event) async {
          if (_livePedometerTotal > 0 && event.steps > _livePedometerTotal + 1000) {
            _pedometerDayBaseline = event.steps - (_livePedometerTotal - _pedometerDayBaseline);
            final p = await SharedPreferences.getInstance();
            await p.setInt('pedometer_baseline', _pedometerDayBaseline);
          }
          _livePedometerTotal = event.steps;

          if (_pedometerDayBaseline < 0) {
            _pedometerDayBaseline = event.steps;
            _pedometerBaselineDate = _todayKey;
            final p = await SharedPreferences.getInstance();
            await p.setInt('pedometer_baseline', _pedometerDayBaseline);
            await p.setString('pedometer_date', _pedometerBaselineDate);
          }

          notifyListeners();
        },
        onError: (_) {},
        cancelOnError: false,
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _dayResetTimer?.cancel();
    _stepSubscription?.cancel();
    super.dispose();
  }

  // Helper
  String newId() => const Uuid().v4();
}
