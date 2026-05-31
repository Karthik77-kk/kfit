import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:uuid/uuid.dart';
import 'package:pedometer/pedometer.dart';
import 'package:home_widget/home_widget.dart';

import '../models/models.dart';
import '../widgets/home_widget_view.dart';
import '../services/smart_insight_engine.dart' show topInsight, topInsights;
import '../services/notification_center.dart';

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
  double _heightCm = 170.0;
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
  List<MeasurementEntry> _measurementHistory = [];
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
  List<MeasurementEntry> get measurementHistory => _measurementHistory;
  MeasurementEntry? get latestMeasurements =>
      _measurementHistory.isEmpty ? null : _measurementHistory.last;
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

  /// Estimated carbs today (Indian diet approximation):
  /// protein_cal = protein*4, fat_cal = remaining*35%, carb_cal = remaining*65%
  double get todayCarbsEstimate {
    final proteinCal = todayProteinTotal * 4.0;
    final remaining = (todayCaloriesTotal - proteinCal).clamp(0.0, double.infinity);
    return (remaining * 0.65) / 4.0; // convert kcal → grams
  }

  /// Estimated fat today (Indian diet approximation)
  double get todayFatEstimate {
    final proteinCal = todayProteinTotal * 4.0;
    final remaining = (todayCaloriesTotal - proteinCal).clamp(0.0, double.infinity);
    return (remaining * 0.35) / 9.0; // convert kcal → grams
  }

  /// Last 7 days of calorie data for bar chart.
  /// Returns list of [dayLabel, calories] pairs, oldest→newest.
  List<Map<String, dynamic>> get weeklyCalorieData {
    final result = <Map<String, dynamic>>[];
    final today = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      double cal;
      if (i == 0) {
        cal = todayCaloriesTotal;
      } else {
        final foods = _foodHistory[key];
        final supp = _supplementHistory[key];
        final foodCal = foods?.fold(0.0, (s, e) => s + e.calories) ?? 0.0;
        final suppCal = (supp?.whey ?? false) ? 120.0 : 0.0;
        cal = foodCal + suppCal;
      }
      final label = i == 0
          ? 'Today'
          : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1];
      result.add({'label': label, 'calories': cal, 'date': key});
    }
    return result;
  }

  double get calorieProgress =>
      (todayCaloriesTotal / calorieGoal).clamp(0.0, 1.0);
  double get proteinProgress =>
      (todayProteinTotal / proteinGoal).clamp(0.0, 1.0);
  double get waterProgress =>
      (_todayWaterMl / waterGoalMl).clamp(0.0, 1.0);

  // ── Net calories & deficit ─────────────────────────────────────────────────
  /// Calories eaten minus calories burned from workout
  int get netCalories => (todayCaloriesTotal - todayCaloriesBurned).round();

  /// Positive = deficit (good for fat loss), Negative = surplus.
  /// Uses totalCaloriesBurned (resting + walking + workout) for accuracy.
  int get calorieDeficit => calorieGoal - (todayCaloriesTotal - totalCaloriesBurned).round();

  /// True if currently in a calorie deficit
  bool get inDeficit => (todayCaloriesTotal - totalCaloriesBurned) < calorieGoal;

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

  // ── Body-composition analytics (uses ALL scale + measurement data) ──────────
  static const _bcGreen = Color(0xFF30D158);
  static const _bcOrange = Color(0xFFFF9F0A);
  static const _bcRed = Color(0xFFFF453A);
  static const _bcBlue = Color(0xFF40C8E0);
  static const _bcMuted = Color(0xFF8E8E93);

  /// Earliest logged weight across body + scale history — the baseline for goal progress.
  double? get startWeightKg {
    DateTime? earliest;
    double? weight;
    void consider(DateTime d, double w) {
      if (w <= 0) return;
      if (earliest == null || d.isBefore(earliest!)) {
        earliest = d;
        weight = w;
      }
    }
    if (_bodyHistory.isNotEmpty) consider(_bodyHistory.first.date, _bodyHistory.first.weightKg);
    if (_scaleHistory.isNotEmpty) consider(_scaleHistory.first.date, _scaleHistory.first.weightKg);
    return weight;
  }

  /// Fraction (0–1) of the start→goal journey completed. Handles loss and gain goals.
  double get goalProgress {
    final start = startWeightKg;
    final current = latestWeightKg;
    if (start == null || current == null) return 0;
    final span = start - _goalWeightKg;
    if (span.abs() < 0.05) return 1; // already at goal / no meaningful span
    return ((start - current) / span).clamp(0.0, 1.0);
  }

  /// Waist-to-hip ratio (fat-distribution / health-risk indicator).
  double? get waistToHipRatio {
    final m = latestMeasurements;
    final waist = m?.waistCm;
    final hips = m?.hipsCm;
    if (waist == null || hips == null || hips <= 0) return null;
    return waist / hips;
  }

  ({String label, Color color})? get whrRisk {
    final r = waistToHipRatio;
    if (r == null) return null;
    if (r < 0.90) return (label: 'Low risk', color: _bcGreen);
    if (r < 1.00) return (label: 'Moderate risk', color: _bcOrange);
    return (label: 'High risk', color: _bcRed);
  }

  /// Waist-to-height ratio — a stronger central-obesity signal than BMI.
  double? get waistToHeightRatio {
    final waist = latestMeasurements?.waistCm;
    if (waist == null || _heightCm <= 0) return null;
    return waist / _heightCm;
  }

  ({String label, Color color}) get whtrStatus {
    final r = waistToHeightRatio;
    if (r == null) return (label: '—', color: _bcMuted);
    if (r < 0.5) return (label: 'Healthy', color: _bcGreen);
    if (r < 0.6) return (label: 'Raised', color: _bcOrange);
    return (label: 'High', color: _bcRed);
  }

  /// Normalized Fat-Free Mass Index — your actual muscle-development score.
  double? get ffmi {
    final lean = latestScaleEntry?.leanBodyMassKg;
    if (lean == null || lean <= 0 || _heightCm <= 0) return null;
    final h = _heightCm / 100.0;
    return lean / (h * h) + 6.1 * (1.8 - h);
  }

  ({String label, Color color}) get ffmiStatus {
    final f = ffmi;
    if (f == null) return (label: '—', color: _bcMuted);
    if (f < 18) return (label: 'Below average', color: _bcOrange);
    if (f < 20) return (label: 'Average', color: _bcBlue);
    if (f < 22) return (label: 'Athletic', color: _bcGreen);
    if (f < 25) return (label: 'Excellent', color: _bcGreen);
    return (label: 'Very high', color: _bcBlue);
  }

  double? get fatMassKg {
    final v = latestScaleEntry?.bodyFatKg;
    return (v != null && v > 0) ? v : null;
  }

  double? get leanMassKg {
    final v = latestScaleEntry?.leanBodyMassKg;
    return (v != null && v > 0) ? v : null;
  }

  /// Fat / lean change from the earliest to latest scale reading — the real recomp story.
  ({double fatChange, double leanChange, String verdict, Color color})? get bodyCompTrajectory {
    if (_scaleHistory.length < 2) return null;
    final first = _scaleHistory.first;
    final last = _scaleHistory.last;
    if (first.bodyFatKg <= 0 || last.bodyFatKg <= 0) return null;
    final fatChange = last.bodyFatKg - first.bodyFatKg;
    final leanChange = last.leanBodyMassKg - first.leanBodyMassKg;
    String verdict;
    Color color;
    if (fatChange < -0.3 && leanChange > 0.3) {
      verdict = 'Recomp — fat down, muscle up';
      color = _bcGreen;
    } else if (fatChange < -0.3 && leanChange >= -0.3) {
      verdict = 'Losing fat, holding muscle';
      color = _bcGreen;
    } else if (fatChange < -0.3 && leanChange < -0.3) {
      verdict = 'Losing fat and some muscle';
      color = _bcOrange;
    } else if (fatChange > 0.3 && leanChange > 0.3) {
      verdict = 'Gaining both fat and muscle';
      color = _bcOrange;
    } else if (fatChange > 0.3) {
      verdict = 'Fat trending up';
      color = _bcRed;
    } else {
      verdict = 'Holding steady';
      color = _bcMuted;
    }
    return (fatChange: fatChange, leanChange: leanChange, verdict: verdict, color: color);
  }

  /// Smart-scale biological age minus real age (negative = younger than your years).
  int? get bioAgeDelta {
    final b = latestScaleEntry?.biologicalAge;
    if (b == null || b <= 0) return null;
    return b - _age;
  }

  ({String label, Color color})? get hydrationStatus {
    final w = latestScaleEntry?.bodyWaterPercent;
    if (w == null || w <= 0) return null;
    if (w < 50) return (label: 'Low', color: _bcOrange);
    if (w <= 65) return (label: 'Healthy', color: _bcGreen);
    return (label: 'High', color: _bcBlue);
  }

  /// Headline body-composition classification from BMI + body-fat% + FFMI.
  ({String label, Color color, String detail}) get bodyCompositionStatus {
    final bf = latestScaleEntry?.bodyFatPercent;
    final f = ffmi;
    final b = bmi;
    if (bf == null && b == null) {
      return (label: 'Log data', color: _bcMuted, detail: 'Log weight (and scale) to assess.');
    }
    if (bf != null && bf > 0) {
      if (bf >= 25) {
        return (label: 'Overfat', color: _bcRed,
            detail: 'Body fat ${bf.toStringAsFixed(0)}% is high — prioritise the deficit + protein.');
      }
      if (bf < 15 && (f == null || f >= 20)) {
        return (label: 'Athletic', color: _bcGreen,
            detail: 'Lean and muscular — maintain protein and training.');
      }
      if (bf < 20 && (f == null || f >= 19)) {
        return (label: 'Lean', color: _bcGreen,
            detail: 'Good composition — keep protein high to hold muscle.');
      }
      if (f != null && f < 18) {
        return (label: 'Recomp needed', color: _bcOrange,
            detail: 'Lowish muscle (FFMI ${f.toStringAsFixed(1)}) — lift heavy while holding the deficit.');
      }
      return (label: 'Average', color: _bcBlue,
          detail: 'Solid base — small deficit + strength work moves you toward lean.');
    }
    // Fall back to BMI category when no body-fat reading.
    return (label: bmiCategory, color: _bcBlue, detail: 'Log smart-scale data for a full composition read.');
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

  List<MeasurementEntry> getRecentMeasurements({int days = 90}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _measurementHistory
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

  /// Average daily calories (incl. supplements) over the last 7 days
  double get weeklyAvgCalories {
    final data = weeklyCalorieData; // already computed, 7 entries
    if (data.isEmpty) return 0;
    final total = data.fold(0.0, (sum, d) => sum + (d['calories'] as double));
    return total / data.length;
  }

  /// Average daily protein (incl. whey) over the last 7 days
  double get weeklyAvgProtein {
    double total = 0;
    final today = DateTime.now();
    for (int i = 0; i < 7; i++) {
      final d = today.subtract(Duration(days: i));
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      if (i == 0) {
        total += todayProteinTotal;
      } else {
        final foods = _foodHistory[key];
        final supp = _supplementHistory[key];
        final foodProt = foods?.fold(0.0, (s, e) => s + e.protein) ?? 0.0;
        final suppProt = (supp?.whey ?? false) ? 25.0 : 0.0;
        total += foodProt + suppProt;
      }
    }
    return total / 7;
  }

  /// Days in the last 7 where water intake met the daily goal
  int get weeklyWaterGoalHitDays {
    int count = 0;
    final today = DateTime.now();
    for (int i = 0; i < 7; i++) {
      final d = today.subtract(Duration(days: i));
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final ml = i == 0 ? _todayWaterMl : (_waterHistory[key] ?? 0);
      if (ml >= _waterGoalMl) count++;
    }
    return count;
  }

  /// Days in the last 7 where protein met the daily goal
  int get weeklyProteinGoalHitDays {
    int count = 0;
    final today = DateTime.now();
    for (int i = 0; i < 7; i++) {
      final d = today.subtract(Duration(days: i));
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      double prot;
      if (i == 0) {
        prot = todayProteinTotal;
      } else {
        final foods = _foodHistory[key];
        final supp = _supplementHistory[key];
        final foodProt = foods?.fold(0.0, (s, e) => s + e.protein) ?? 0.0;
        final suppProt = (supp?.whey ?? false) ? 25.0 : 0.0;
        prot = foodProt + suppProt;
      }
      if (prot >= _proteinGoal) count++;
    }
    return count;
  }

  // ── Historical aggregates (for the smart insight engine) ────────────────────
  /// Returns a 'YYYY-MM-DD' key for [d].
  String _keyFor(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Total calories logged on [d] (incl. whey). Uses live data for today.
  double caloriesForDate(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return todayCaloriesTotal;
    }
    final key = _keyFor(d);
    final foods = _foodHistory[key];
    final supp = _supplementHistory[key];
    final foodCal = foods?.fold(0.0, (s, e) => s + e.calories) ?? 0.0;
    final suppCal = (supp?.whey ?? false) ? 120.0 : 0.0;
    return foodCal + suppCal;
  }

  /// Total protein logged on [d] (incl. whey). Uses live data for today.
  double proteinForDate(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return todayProteinTotal;
    }
    final key = _keyFor(d);
    final foods = _foodHistory[key];
    final supp = _supplementHistory[key];
    final foodProt = foods?.fold(0.0, (s, e) => s + e.protein) ?? 0.0;
    final suppProt = (supp?.whey ?? false) ? 25.0 : 0.0;
    return foodProt + suppProt;
  }

  /// Water (mL) logged on [d]. Uses live data for today.
  int waterForDate(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return _todayWaterMl;
    }
    return _waterHistory[_keyFor(d)] ?? 0;
  }

  /// Mean daily calories over days [startAgo..endAgo] inclusive (0 = today).
  /// Only counts days that have any logged data, so a partial history isn't diluted by zeros.
  double avgCaloriesForDays(int startAgo, int endAgo) =>
      _avgForDays(startAgo, endAgo, caloriesForDate);
  double avgProteinForDays(int startAgo, int endAgo) =>
      _avgForDays(startAgo, endAgo, (d) => proteinForDate(d));
  double avgWaterForDays(int startAgo, int endAgo) =>
      _avgForDays(startAgo, endAgo, (d) => waterForDate(d).toDouble());

  double _avgForDays(int startAgo, int endAgo, double Function(DateTime) value) {
    final now = DateTime.now();
    double total = 0;
    int counted = 0;
    for (int i = startAgo; i <= endAgo; i++) {
      final v = value(now.subtract(Duration(days: i)));
      if (v > 0) {
        total += v;
        counted++;
      }
    }
    return counted == 0 ? 0 : total / counted;
  }

  /// Mean protein for a given [weekday] (1=Mon..7=Sun) across loaded history (60d).
  /// Returns null if no data for that weekday.
  double? proteinAvgForWeekday(int weekday) => _avgForWeekday(weekday, proteinForDate);
  double? waterAvgForWeekday(int weekday) =>
      _avgForWeekday(weekday, (d) => waterForDate(d).toDouble());

  double? _avgForWeekday(int weekday, double Function(DateTime) value) {
    final now = DateTime.now();
    double total = 0;
    int counted = 0;
    for (int i = 0; i <= 60; i++) {
      final d = now.subtract(Duration(days: i));
      if (d.weekday != weekday) continue;
      final v = value(d);
      if (v > 0) {
        total += v;
        counted++;
      }
    }
    return counted == 0 ? null : total / counted;
  }

  /// Days since the most recent workout (0 = today). Returns 999 if none ever.
  int get daysSinceLastWorkout {
    if (_workoutHistory.isEmpty) return 999;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime latest = _workoutHistory.first.date;
    for (final w in _workoutHistory) {
      if (w.date.isAfter(latest)) latest = w.date;
    }
    final latestDay = DateTime(latest.year, latest.month, latest.day);
    return today.difference(latestDay).inDays;
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
    _heightCm = prefs.getDouble('height_cm') ?? 170.0;
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

    // Body measurements history
    final measureJson = prefs.getString('measurements_history');
    if (measureJson != null) {
      final list = jsonDecode(measureJson) as List;
      _measurementHistory = list.map((e) => MeasurementEntry.fromJson(e)).toList();
      _measurementHistory.sort((a, b) => a.date.compareTo(b.date));
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

    // Purge food/water/supp keys older than 60 days from SharedPreferences.
    // These keys accumulate indefinitely otherwise, bloating storage and exports.
    _purgeStaleDailyKeys(prefs);

    notifyListeners();
    _updateWidget();

    // Populate the in-app notification center (insights snapshot + milestones).
    _populateNotifications();

    // Start pedometer after data is loaded (non-blocking)
    startPedometer();

    // Start day-reset watcher (detects midnight crossover while app is open)
    _startDayResetTimer();
  }

  // ── In-app notification center ──────────────────────────────────────────────
  List<AppNotification> _appNotifications = [];
  int _unreadNotifications = 0;
  List<AppNotification> get appNotifications => _appNotifications;
  int get unreadNotifications => _unreadNotifications;

  Future<void> _refreshNotifications() async {
    _appNotifications = await NotificationCenter.all();
    _unreadNotifications = _appNotifications.where((n) => !n.read).length;
    notifyListeners();
  }

  Future<void> markNotificationsRead() async {
    await NotificationCenter.markAllRead();
    await _refreshNotifications();
  }

  Future<void> clearNotifications() async {
    await NotificationCenter.clear();
    await _refreshNotifications();
  }

  Future<void> _populateNotifications() async {
    try {
      // Snapshot today's top AI Coach insights (deduped by title/day in the store).
      final insights = topInsights(this, DateTime.now(), count: 3);
      for (final ins in insights) {
        await NotificationCenter.add(AppNotification(
          id: const Uuid().v4(),
          emoji: ins.emoji,
          title: ins.title,
          body: ins.body,
          accent: ins.accent.value,
          category: 'insight',
          timestamp: DateTime.now(),
        ));
      }
      await _detectMilestones();
      await _refreshNotifications();
    } catch (_) {}
  }

  Future<void> _detectMilestones() async {
    final prefs = await SharedPreferences.getInstance();

    // Workout-streak milestones (fire once per threshold crossing).
    final ws = workoutStreak;
    final lastWs = prefs.getInt('ms_workout_streak') ?? 0;
    for (final m in [7, 14, 30, 60, 100]) {
      if (ws >= m && lastWs < m) {
        await NotificationCenter.add(AppNotification(
          id: const Uuid().v4(), emoji: '🏋️',
          title: '$m-day workout streak!',
          body: '$m days in a row — elite consistency. Keep the chain unbroken.',
          accent: 0xFFFF9F0A, category: 'milestone', timestamp: DateTime.now(),
        ));
      }
    }
    await prefs.setInt('ms_workout_streak', ws);

    // Diet-streak milestones.
    final cs = calorieStreak;
    final lastCs = prefs.getInt('ms_calorie_streak') ?? 0;
    for (final m in [7, 30]) {
      if (cs >= m && lastCs < m) {
        await NotificationCenter.add(AppNotification(
          id: const Uuid().v4(), emoji: '🥗',
          title: '$m-day diet logging streak!',
          body: 'Logged your food $m days straight. Awareness is half the battle.',
          accent: 0xFF40C8E0, category: 'milestone', timestamp: DateTime.now(),
        ));
      }
    }
    await prefs.setInt('ms_calorie_streak', cs);

    // Goal reached.
    final reached = startWeightKg != null && goalProgress >= 1.0;
    final wasReached = prefs.getBool('ms_goal_reached') ?? false;
    if (reached && !wasReached) {
      await NotificationCenter.add(AppNotification(
        id: const Uuid().v4(), emoji: '🎯',
        title: 'Goal weight reached! 🎉',
        body: 'You hit ${_goalWeightKg.toStringAsFixed(1)} kg. Time to set a new '
            'target or shift to maintenance.',
        accent: 0xFF30D158, category: 'milestone', timestamp: DateTime.now(),
      ));
    }
    await prefs.setBool('ms_goal_reached', reached);
  }

  /// Adds a notification to the in-app center (used by reminders/foreground service).
  Future<void> pushNotification(AppNotification n) async {
    await NotificationCenter.add(n);
    await _refreshNotifications();
  }

  void _purgeStaleDailyKeys(SharedPreferences prefs) {
    final cutoff = DateTime.now().subtract(const Duration(days: 61));
    final cutoffKey =
        '${cutoff.year}-${cutoff.month.toString().padLeft(2, '0')}-${cutoff.day.toString().padLeft(2, '0')}';
    final toRemove = prefs.getKeys().where((k) {
      if (!k.startsWith('food_') &&
          !k.startsWith('water_') &&
          !k.startsWith('supp_')) return false;
      final datePart = k.substring(k.indexOf('_') + 1);
      return datePart.compareTo(cutoffKey) < 0;
    }).toList();
    for (final k in toRemove) {
      prefs.remove(k);
    }
  }

  // ── Food actions ───────────────────────────────────────────────────────────
  Future<void> addFoodEntry(FoodEntry entry) async {
    _todayFood.add(entry);
    await _saveFoodEntries();
    notifyListeners();
    _updateWidget();
  }

  Future<void> removeFoodEntry(String id) async {
    _todayFood.removeWhere((e) => e.id == id);
    await _saveFoodEntries();
    notifyListeners();
    _updateWidget();
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
    _updateWidget();
  }

  Future<void> removeWater(int ml) async {
    _todayWaterMl = (_todayWaterMl - ml).clamp(0, 99999);
    await _saveWater();
    notifyListeners();
    _updateWidget();
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
      default:
        assert(false, 'updateSupplement: unknown key "$key"');
        return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'supp_$_todayKey', jsonEncode(_supplements.toJson()));
    notifyListeners();
    _updateWidget();
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
    // Preserve today's manually-logged steps — logBodyEntry defaults steps to 0
    // which would wipe any steps the user entered before logging the scale.
    final todayBody = _bodyHistory.where((e) =>
        e.date.year == now.year &&
        e.date.month == now.month &&
        e.date.day == now.day).toList();
    final existingSteps = todayBody.isNotEmpty ? todayBody.first.steps : 0;
    await logBodyEntry(weightKg: entry.weightKg, steps: existingSteps);
    notifyListeners();
  }

  // ── Measurement actions ────────────────────────────────────────────────────
  Future<void> logMeasurement(MeasurementEntry entry) async {
    if (entry.isEmpty) return;
    final now = DateTime.now();
    _measurementHistory.removeWhere((e) =>
        e.date.year == now.year &&
        e.date.month == now.month &&
        e.date.day == now.day);
    _measurementHistory.add(entry);
    _measurementHistory.sort((a, b) => a.date.compareTo(b.date));
    final cutoff = now.subtract(const Duration(days: 180));
    _measurementHistory.removeWhere((e) => e.date.isBefore(cutoff));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'measurements_history',
      jsonEncode(_measurementHistory.map((e) => e.toJson()).toList()),
    );
    notifyListeners();
  }

  // ── Export / Import ────────────────────────────────────────────────────────
  // Keys that are device-specific and must not be exported/imported.
  static const _exportExcludeKeys = {'pedometer_baseline', 'pedometer_date'};

  Future<String> exportAllData() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    final Map<String, dynamic> data = {};
    for (final key in allKeys) {
      if (_exportExcludeKeys.contains(key)) continue;
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
          if (_livePedometerTotal > 0 && event.steps > _livePedometerTotal + 50000) {
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

  // ── Home widget ────────────────────────────────────────────────────────────
  Future<void> _updateWidget() async {
    try {
      // Numeric fallbacks (kept for resilience / first render).
      await HomeWidget.saveWidgetData<int>('calories', todayCaloriesTotal.round());
      await HomeWidget.saveWidgetData<int>('calorieGoal', calorieGoal);
      await HomeWidget.saveWidgetData<int>('protein', todayProteinTotal.round());
      await HomeWidget.saveWidgetData<int>('proteinGoal', proteinGoal);
      await HomeWidget.saveWidgetData<int>('water', todayWaterMl);
      await HomeWidget.saveWidgetData<int>('waterGoal', waterGoalMl);

      // Render the concentric-ring + insight card to a PNG the Android widget shows.
      final insight = topInsight(this, DateTime.now());
      await HomeWidget.renderFlutterWidget(
        HomeWidgetView(
          calProgress: calorieProgress,
          proteinProgress: proteinProgress,
          waterProgress: waterProgress,
          calories: todayCaloriesTotal.round(),
          protein: todayProteinTotal.round(),
          waterMl: todayWaterMl,
          insight: insight,
        ),
        key: 'widget_img',
        logicalSize: const Size(360, 170),
        pixelRatio: 3,
      );

      await HomeWidget.updateWidget(
        name: 'KFitnessWidgetProvider',
        androidName: 'KFitnessWidgetProvider',
        qualifiedAndroidName: 'com.example.karthik_fitness.KFitnessWidgetProvider',
      );
    } catch (_) {}
  }

  // Helper
  String newId() => const Uuid().v4();
}
