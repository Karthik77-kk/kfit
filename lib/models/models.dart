enum MealType { breakfast, lunch, dinner, snack }

enum WorkoutType { a, b }

// ─── Food Entry ───────────────────────────────────────────────────────────────

class FoodEntry {
  final String id;
  final String name;
  final double calories;
  final double protein;
  final MealType mealType;
  final DateTime timestamp;

  FoodEntry({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.mealType,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'calories': calories,
        'protein': protein,
        'mealType': mealType.index,
        'timestamp': timestamp.toIso8601String(),
      };

  factory FoodEntry.fromJson(Map<String, dynamic> j) => FoodEntry(
        id: j['id'],
        name: j['name'],
        calories: (j['calories'] as num).toDouble(),
        protein: (j['protein'] as num).toDouble(),
        mealType: MealType.values[j['mealType']],
        timestamp: DateTime.parse(j['timestamp']),
      );
}

// ─── Workout ──────────────────────────────────────────────────────────────────

class SetData {
  final int reps;
  final double weight;

  SetData({required this.reps, required this.weight});

  Map<String, dynamic> toJson() => {'reps': reps, 'weight': weight};

  factory SetData.fromJson(Map<String, dynamic> j) =>
      SetData(reps: j['reps'], weight: (j['weight'] as num).toDouble());
}

class ExerciseLog {
  final String name;
  final List<SetData> sets;

  ExerciseLog({required this.name, required this.sets});

  Map<String, dynamic> toJson() => {
        'name': name,
        'sets': sets.map((s) => s.toJson()).toList(),
      };

  factory ExerciseLog.fromJson(Map<String, dynamic> j) => ExerciseLog(
        name: j['name'],
        sets: (j['sets'] as List).map((s) => SetData.fromJson(s)).toList(),
      );
}

class WorkoutLog {
  final String id;
  final DateTime date;
  final WorkoutType workoutType;
  final List<ExerciseLog> exercises;
  final int durationMinutes;
  final int caloriesBurned;

  WorkoutLog({
    required this.id,
    required this.date,
    required this.workoutType,
    required this.exercises,
    required this.durationMinutes,
    this.caloriesBurned = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'workoutType': workoutType.index,
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'durationMinutes': durationMinutes,
        'caloriesBurned': caloriesBurned,
      };

  factory WorkoutLog.fromJson(Map<String, dynamic> j) => WorkoutLog(
        id: j['id'],
        date: DateTime.parse(j['date']),
        workoutType: WorkoutType.values[j['workoutType']],
        exercises:
            (j['exercises'] as List).map((e) => ExerciseLog.fromJson(e)).toList(),
        durationMinutes: j['durationMinutes'] ?? 0,
        caloriesBurned: j['caloriesBurned'] ?? 0,
      );
}

// ─── Body Entry ───────────────────────────────────────────────────────────────

class BodyEntry {
  final String id;
  final DateTime date;
  final double weightKg;
  final int steps;

  BodyEntry({
    required this.id,
    required this.date,
    required this.weightKg,
    this.steps = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'weightKg': weightKg,
        'steps': steps,
      };

  factory BodyEntry.fromJson(Map<String, dynamic> j) => BodyEntry(
        id: j['id'],
        date: DateTime.parse(j['date']),
        weightKg: (j['weightKg'] as num).toDouble(),
        steps: j['steps'] ?? 0,
      );
}

// ─── Supplements ─────────────────────────────────────────────────────────────

class SupplementStatus {
  bool whey;
  bool creatine;
  bool multivitamin;

  SupplementStatus({
    this.whey = false,
    this.creatine = false,
    this.multivitamin = false,
  });

  int get takenCount => [whey, creatine, multivitamin].where((b) => b).length;

  Map<String, dynamic> toJson() => {
        'whey': whey,
        'creatine': creatine,
        'multivitamin': multivitamin,
      };

  factory SupplementStatus.fromJson(Map<String, dynamic> j) => SupplementStatus(
        whey: j['whey'] ?? false,
        creatine: j['creatine'] ?? false,
        multivitamin: j['multivitamin'] ?? false,
      );
}

// ─── Food database (Indian meal plan) ────────────────────────────────────────

class FoodItem {
  final String name;
  final double calories;
  final double protein;
  final String category;
  final String emoji;

  const FoodItem({
    required this.name,
    required this.calories,
    required this.protein,
    required this.category,
    required this.emoji,
  });
}

const List<FoodItem> kFoodDatabase = [
  // Protein
  FoodItem(name: 'Boiled Egg (1)', calories: 78, protein: 6, category: 'Protein', emoji: '🥚'),
  FoodItem(name: 'Egg Omelette (3 eggs)', calories: 210, protein: 18, category: 'Protein', emoji: '🍳'),
  FoodItem(name: 'Grilled Chicken (150g)', calories: 219, protein: 43, category: 'Protein', emoji: '🍗'),
  FoodItem(name: 'Chicken Curry (150g)', calories: 248, protein: 28, category: 'Protein', emoji: '🍛'),
  FoodItem(name: 'Paneer (100g)', calories: 265, protein: 18, category: 'Protein', emoji: '🧀'),
  FoodItem(name: 'Paneer Bhurji (100g)', calories: 200, protein: 16, category: 'Protein', emoji: '🧆'),
  FoodItem(name: 'Dal (200ml)', calories: 120, protein: 8, category: 'Protein', emoji: '🫘'),
  FoodItem(name: 'Whey Protein Scoop (1)', calories: 120, protein: 24, category: 'Supplement', emoji: '💪'),
  FoodItem(name: 'Rajma (150g)', calories: 195, protein: 12, category: 'Protein', emoji: '🫘'),
  FoodItem(name: 'Chole (150g)', calories: 210, protein: 11, category: 'Protein', emoji: '🫘'),
  // Carbs
  FoodItem(name: 'Oats (40g)', calories: 148, protein: 5, category: 'Carbs', emoji: '🥣'),
  FoodItem(name: 'Roti (1)', calories: 104, protein: 3, category: 'Carbs', emoji: '🫓'),
  FoodItem(name: 'Brown Bread (1 slice)', calories: 69, protein: 3, category: 'Carbs', emoji: '🍞'),
  FoodItem(name: 'Rice (100g cooked)', calories: 130, protein: 2.7, category: 'Carbs', emoji: '🍚'),
  FoodItem(name: 'Biryani (1 plate)', calories: 450, protein: 20, category: 'Carbs', emoji: '🍚'),
  FoodItem(name: 'Idli (2 pieces)', calories: 140, protein: 4, category: 'Carbs', emoji: '🫓'),
  FoodItem(name: 'Dosa (1 plain)', calories: 165, protein: 4, category: 'Carbs', emoji: '🫓'),
  FoodItem(name: 'Upma (1 bowl)', calories: 175, protein: 5, category: 'Carbs', emoji: '🥣'),
  FoodItem(name: 'Paratha (1)', calories: 200, protein: 4, category: 'Carbs', emoji: '🫓'),
  FoodItem(name: 'Poha (1 bowl)', calories: 180, protein: 4, category: 'Carbs', emoji: '🥣'),
  // Fruits & Dairy
  FoodItem(name: 'Banana (1)', calories: 89, protein: 1, category: 'Fruits', emoji: '🍌'),
  FoodItem(name: 'Apple (1)', calories: 52, protein: 0.3, category: 'Fruits', emoji: '🍎'),
  FoodItem(name: 'Milk (200ml)', calories: 122, protein: 6.4, category: 'Dairy', emoji: '🥛'),
  FoodItem(name: 'Curd/Yogurt (100g)', calories: 60, protein: 3.5, category: 'Dairy', emoji: '🥛'),
  FoodItem(name: 'Mango (1 medium)', calories: 135, protein: 1.4, category: 'Fruits', emoji: '🥭'),
  // Nuts & Extras
  FoodItem(name: 'Almonds (10g)', calories: 58, protein: 2, category: 'Nuts', emoji: '🌰'),
  FoodItem(name: 'Walnuts (10g)', calories: 65, protein: 1.5, category: 'Nuts', emoji: '🫑'),
  FoodItem(name: 'Mixed Salad', calories: 50, protein: 2, category: 'Veggies', emoji: '🥗'),
  FoodItem(name: 'Black Coffee', calories: 2, protein: 0.3, category: 'Drinks', emoji: '☕'),
  FoodItem(name: 'Tea (no sugar)', calories: 5, protein: 0, category: 'Drinks', emoji: '🍵'),
  FoodItem(name: 'Samosa (1)', calories: 240, protein: 4, category: 'Snacks', emoji: '🥟'),
  FoodItem(name: 'Peanuts (30g)', calories: 170, protein: 8, category: 'Nuts', emoji: '🥜'),
];

// Workout A & B templates
const Map<WorkoutType, List<String>> kWorkoutExercises = {
  WorkoutType.a: [
    'Push-ups',
    'Squats',
    'Bicep Curls',
    'Plank (hold)',
    'Tricep Dips',
  ],
  WorkoutType.b: [
    'Shoulder Press',
    'Bent-over Rows',
    'Forearm Curls',
    'Lunges',
    'Lat Pulldown',
  ],
};

// Calorie burn estimate: MET * weight * duration
// Strength training MET ≈ 5
int estimateCaloriesBurned(double weightKg, int durationMinutes) {
  const double met = 5.0;
  return ((met * weightKg * durationMinutes) / 60).round();
}
