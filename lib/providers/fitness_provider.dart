import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:uuid/uuid.dart';
import 'package:pedometer/pedometer.dart';
import 'package:flutter/services.dart';
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

  int _age = 24; // Karthik's age
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

  // ── Historical data (last 30 days, loaded at startup) ──────────────────────
  Map<String, List<FoodEntry>> _foodHistory = {};
  Map<String, int> _waterHistory = {};
  Map<String, SupplementStatus> _supplementHistory = {};

  // ── Pedometer ──────────────────────────────────────────────────────────────
  StreamSubscription<StepCount>? _stepSubscription;
  int _livePedometerTotal = 0;   // cumulative total from sensor
  int _pedometerDayBaseline = -1; // sensor total at start of today
  String _pedometerBaselineDate = '';

  // ── Getters ────────────────────────────────────────────────────────────────
  List<FoodEntry> get todayFood => _todayFood;
  int get todayWaterMl => _todayWaterMl;
  SupplementStatus get supplements => _supplements;
  List<WorkoutLog> get workoutHistory => _workoutHistory;
  List<BodyEntry> get bodyHistory => _bodyHistory;
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

  double get calorieProgress =>
      (todayCalories / kCalorieGoal).clamp(0.0, 1.0);
  double get proteinProgress =>
      (todayProtein / kProteinGoal).clamp(0.0, 1.0);
  double get waterProgress =>
      (_todayWaterMl / kWaterGoalMl).clamp(0.0, 1.0);

  // ── Net calories & deficit ─────────────────────────────────────────────────
  /// Calories eaten minus calories burned from workout
  int get netCalories => (todayCalories - todayCaloriesBurned).round();

  /// Positive = deficit (good for fat loss), Negative = surplus
  int get calorieDeficit => kCalorieGoal - netCalories;

  /// True if currently in a calorie deficit
  bool get inDeficit => netCalories < kCalorieGoal;

  /// Remaining calories left to eat (vs goal). Can be negative if over.
  int get caloriesRemaining => kCalorieGoal - todayCalories.round();

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

  /// BMR using Mifflin-St Jeor equation (male)
  /// BMR = 10×weight + 6.25×height − 5×age + 5
  double? get bmr {
    final w = latestWeightKg;
    if (w == null) return null;
    return 10 * w + 6.25 * _heightCm - 5 * _age + 5;
  }

  /// TDEE = BMR × activity multiplier
  /// 1.375 = lightly active (1-3 days/week)
  /// 1.55  = moderately active (3-5 days/week)
  double? get tdee {
    final b = bmr;
    if (b == null) return null;
    final multiplier = weeklyWorkoutDays >= 4 ? 1.55 : 1.375;
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
    // 1 kg fat ≈ 7700 kcal deficit
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

  double get stepProgress => (todaySteps / kStepGoal).clamp(0.0, 1.0);

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
  /// Returns null if never logged.
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
    // Monday = 1, Sunday = 7
    final weekday = now.weekday; // 1=Mon ... 7=Sun
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
    _heightCm = prefs.getDouble('height_cm') ?? 170.0;
    _age = prefs.getInt('age') ?? 24;
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

    // Historical food, water, supplement for last 30 days
    _foodHistory = {};
    _waterHistory = {};
    _supplementHistory = {};
    for (int i = 1; i <= 30; i++) {
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
    notifyListeners();

    // Start pedometer after data is loaded (non-blocking)
    startPedometer();
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
    _updateWidgets();
  }

  Future<void> removeWater(int ml) async {
    _todayWaterMl = (_todayWaterMl - ml).clamp(0, 99999);
    await _saveWater();
    notifyListeners();
    _updateWidgets();
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

  // ── Weight Prediction (Linear Regression) ─────────────────────────────────
  /// Returns (slope_per_day, intercept) for weight trend, or null if < 3 entries.
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

  /// Predicted weight N days from today based on current trend.
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

  /// kg per week based on trend (negative = losing)
  double? get weeklyWeightChange {
    final reg = _weightRegression;
    if (reg == null) return null;
    return reg.slope * 7;
  }

  /// List of (date, predictedWeight) for the next N days
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

  /// Estimated date to reach goal weight (null if trend is wrong direction)
  DateTime? get estimatedGoalDate {
    final reg = _weightRegression;
    final w = latestWeightKg;
    if (reg == null || w == null) return null;
    if (reg.slope >= 0 && w > _goalWeightKg) return null; // Gaining, not losing
    final entries = getRecentBodyEntries(days: 90);
    if (entries.isEmpty) return null;
    final first = entries.first.date.millisecondsSinceEpoch.toDouble();
    final today = DateTime.now().millisecondsSinceEpoch.toDouble();
    final x0 = (today - first) / 86400000.0;
    // intercept + slope * x = goalWeight → x = (goal - intercept) / slope
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

  // ── Pedometer ──────────────────────────────────────────────────────────────
  Future<void> startPedometer() async {
    final prefs = await SharedPreferences.getInstance();
    _pedometerBaselineDate = prefs.getString('pedometer_date') ?? '';
    _pedometerDayBaseline  = prefs.getInt('pedometer_baseline') ?? -1;

    // Reset if saved baseline is from a previous day
    if (_pedometerBaselineDate != _todayKey) {
      _pedometerDayBaseline = -1;
      _pedometerBaselineDate = '';
    }

    _stepSubscription?.cancel();
    try {
      _stepSubscription = Pedometer.stepCountStream.listen(
        (StepCount event) async {
          _livePedometerTotal = event.steps;

          // Record baseline at first reading of today
          if (_pedometerDayBaseline < 0) {
            _pedometerDayBaseline = event.steps;
            _pedometerBaselineDate = _todayKey;
            final p = await SharedPreferences.getInstance();
            await p.setInt('pedometer_baseline', _pedometerDayBaseline);
            await p.setString('pedometer_date', _pedometerBaselineDate);
          }

          notifyListeners();
          _updateWidgets();
        },
        onError: (_) {/* sensor not available or permission denied */},
        cancelOnError: false,
      );
    } catch (_) {/* pedometer unsupported */}
  }

  @override
  void dispose() {
    _stepSubscription?.cancel();
    super.dispose();
  }

  // ── Home-screen widget data sync ───────────────────────────────────────────
  void _updateWidgets() {
    _doUpdateWidgets().catchError((_) {});
  }

  Future<void> _doUpdateWidgets() async {
    try {
      // Write data directly to FlutterSharedPreferences (with flutter. prefix)
      // The Kotlin AppWidgetProvider reads these keys directly.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('water_ml', _todayWaterMl);
      await prefs.setInt('steps_today', todaySteps);
      // Trigger widget redraw via MethodChannel (fails gracefully on non-Android)
      const _channel = MethodChannel('com.example.karthik_fitness/widgets');
      await _channel.invokeMethod('updateWidgets');
    } catch (_) {/* not on Android or widget not installed — non-fatal */}
  }

  // Helper
  String newId() => const Uuid().v4();
}
