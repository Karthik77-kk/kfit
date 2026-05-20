enum MealType { breakfast, lunch, dinner, snack }

enum WorkoutType { a, b, custom }

/// Preset exercises for Workout A (Push) and Workout B (Pull + Legs).
/// WorkoutType.custom is NOT included — it uses a user-selected list.
const Map<WorkoutType, List<String>> kWorkoutExercises = {
  WorkoutType.a: [
    'Push-ups',
    'Bench Press',
    'Incline Press',
    'Shoulder Press',
    'Tricep Dips',
    'Squats',
  ],
  WorkoutType.b: [
    'Pull-ups',
    'Bent-over Rows',
    'Lat Pulldown',
    'Bicep Curls',
    'Romanian Deadlift',
    'Lunges',
  ],
};

/// Estimates calories burned from a resistance-training session.
/// Uses MET ≈ 5 for weight training (moderate effort).
int estimateCaloriesBurned(double weightKg, int durationMinutes) {
  const met = 5.0;
  return (met * weightKg * durationMinutes / 60).round();
}

// ─── Food Entry ───────────────────────────────────────────────────────────────

class FoodEntry {
  final String id;
  final String name;
  final double calories;
  final double protein;
  final MealType mealType;
  final DateTime timestamp;
  final String servingNote; // e.g. "2× 1 roti (~40g)" or "custom entry"

  FoodEntry({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.mealType,
    required this.timestamp,
    this.servingNote = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'calories': calories,
        'protein': protein,
        'mealType': mealType.index,
        'timestamp': timestamp.toIso8601String(),
        'servingNote': servingNote,
      };

  factory FoodEntry.fromJson(Map<String, dynamic> j) => FoodEntry(
        id: j['id'],
        name: j['name'],
        calories: (j['calories'] as num).toDouble(),
        protein: (j['protein'] as num).toDouble(),
        mealType: MealType.values[j['mealType']],
        timestamp: DateTime.parse(j['timestamp']),
        servingNote: j['servingNote'] as String? ?? '',
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

// ─── Food database (Indian + common foods) ───────────────────────────────────

class FoodItem {
  final String name;
  final double calories; // per default serving
  final double protein;  // grams per default serving
  final String category;
  final String emoji;
  final String serving;  // human-readable serving description

  const FoodItem({
    required this.name,
    required this.calories,
    required this.protein,
    required this.category,
    required this.emoji,
    this.serving = '1 serving',
  });
}

/// Categories in display order
const List<String> kFoodCategories = [
  'Popular',
  'Breakfast',
  'Protein',
  'Rice & Roti',
  'Dal & Curry',
  'Snacks',
  'Street Food',
  'Fruits',
  'Dairy',
  'Nuts & Seeds',
  'Drinks',
  'Supplement',
];

const List<FoodItem> kFoodDatabase = [
  // ── Popular (most-used items shown first) ────────────────────────────────
  FoodItem(name: 'Boiled Egg', calories: 78, protein: 6, category: 'Popular', emoji: '🥚', serving: '1 egg'),
  FoodItem(name: 'Roti', calories: 104, protein: 3, category: 'Popular', emoji: '🫓', serving: '1 roti (~40g)'),
  FoodItem(name: 'Rice (cooked)', calories: 130, protein: 2.7, category: 'Popular', emoji: '🍚', serving: '100g cooked'),
  FoodItem(name: 'Dal', calories: 120, protein: 8, category: 'Popular', emoji: '🫘', serving: '1 katori (200ml)'),
  FoodItem(name: 'Grilled Chicken', calories: 219, protein: 43, category: 'Popular', emoji: '🍗', serving: '150g'),
  FoodItem(name: 'Paneer', calories: 265, protein: 18, category: 'Popular', emoji: '🧀', serving: '100g'),
  FoodItem(name: 'Oats', calories: 148, protein: 5, category: 'Popular', emoji: '🥣', serving: '40g dry'),
  FoodItem(name: 'Banana', calories: 89, protein: 1.1, category: 'Popular', emoji: '🍌', serving: '1 medium'),
  FoodItem(name: 'Curd / Dahi', calories: 60, protein: 3.5, category: 'Popular', emoji: '🥛', serving: '100g'),
  FoodItem(name: 'Whey Protein Shake', calories: 130, protein: 25, category: 'Popular', emoji: '💪', serving: '1 scoop (33g)'),

  // ── Breakfast ────────────────────────────────────────────────────────────
  FoodItem(name: 'Egg Omelette (3 eggs)', calories: 210, protein: 18, category: 'Breakfast', emoji: '🍳', serving: '3 eggs'),
  FoodItem(name: 'Masala Omelette (2 eggs)', calories: 165, protein: 13, category: 'Breakfast', emoji: '🍳', serving: '2 eggs'),
  FoodItem(name: 'Scrambled Eggs (2)', calories: 150, protein: 12, category: 'Breakfast', emoji: '🍳', serving: '2 eggs'),
  FoodItem(name: 'Idli', calories: 70, protein: 2, category: 'Breakfast', emoji: '🫓', serving: '1 piece'),
  FoodItem(name: 'Idli with Sambar', calories: 220, protein: 8, category: 'Breakfast', emoji: '🫓', serving: '2 idli + 1 bowl sambar'),
  FoodItem(name: 'Plain Dosa', calories: 165, protein: 4, category: 'Breakfast', emoji: '🫓', serving: '1 dosa'),
  FoodItem(name: 'Masala Dosa', calories: 290, protein: 6, category: 'Breakfast', emoji: '🫓', serving: '1 dosa'),
  FoodItem(name: 'Upma', calories: 175, protein: 5, category: 'Breakfast', emoji: '🥣', serving: '1 bowl (150g)'),
  FoodItem(name: 'Poha', calories: 180, protein: 4, category: 'Breakfast', emoji: '🥣', serving: '1 bowl (150g)'),
  FoodItem(name: 'Rava Idli', calories: 95, protein: 3, category: 'Breakfast', emoji: '🫓', serving: '1 piece'),
  FoodItem(name: 'Medu Vada', calories: 150, protein: 5, category: 'Breakfast', emoji: '🍩', serving: '1 piece'),
  FoodItem(name: 'Bread (White)', calories: 69, protein: 2.3, category: 'Breakfast', emoji: '🍞', serving: '1 slice (30g)'),
  FoodItem(name: 'Bread (Brown/Multigrain)', calories: 65, protein: 3, category: 'Breakfast', emoji: '🍞', serving: '1 slice (30g)'),
  FoodItem(name: 'Bread with Peanut Butter', calories: 188, protein: 8, category: 'Breakfast', emoji: '🍞', serving: '2 slices + 1 tbsp PB'),
  FoodItem(name: 'Corn Flakes with Milk', calories: 185, protein: 6, category: 'Breakfast', emoji: '🥣', serving: '30g flakes + 150ml milk'),
  FoodItem(name: 'Besan Chilla (2)', calories: 180, protein: 10, category: 'Breakfast', emoji: '🥞', serving: '2 chilla'),
  FoodItem(name: 'Paratha (Plain)', calories: 200, protein: 4, category: 'Breakfast', emoji: '🫓', serving: '1 paratha'),
  FoodItem(name: 'Aloo Paratha', calories: 260, protein: 5, category: 'Breakfast', emoji: '🫓', serving: '1 paratha'),

  // ── Protein sources ───────────────────────────────────────────────────────
  FoodItem(name: 'Boiled Egg White (1)', calories: 17, protein: 3.6, category: 'Protein', emoji: '🥚', serving: '1 white only'),
  FoodItem(name: 'Boiled Egg (whole)', calories: 78, protein: 6, category: 'Protein', emoji: '🥚', serving: '1 egg'),
  FoodItem(name: 'Grilled Chicken Breast', calories: 165, protein: 31, category: 'Protein', emoji: '🍗', serving: '100g'),
  FoodItem(name: 'Chicken Curry', calories: 248, protein: 28, category: 'Protein', emoji: '🍛', serving: '150g'),
  FoodItem(name: 'Boiled Chicken', calories: 215, protein: 40, category: 'Protein', emoji: '🍗', serving: '150g'),
  FoodItem(name: 'Egg Curry (2 eggs)', calories: 200, protein: 14, category: 'Protein', emoji: '🍳', serving: '2 eggs in curry'),
  FoodItem(name: 'Paneer (raw)', calories: 265, protein: 18, category: 'Protein', emoji: '🧀', serving: '100g'),
  FoodItem(name: 'Paneer Bhurji', calories: 200, protein: 16, category: 'Protein', emoji: '🧆', serving: '100g'),
  FoodItem(name: 'Paneer Tikka', calories: 230, protein: 19, category: 'Protein', emoji: '🍢', serving: '100g'),
  FoodItem(name: 'Tofu (firm)', calories: 76, protein: 8, category: 'Protein', emoji: '🧀', serving: '100g'),
  FoodItem(name: 'Rajma', calories: 195, protein: 12, category: 'Protein', emoji: '🫘', serving: '150g cooked'),
  FoodItem(name: 'Chole (Chickpeas)', calories: 210, protein: 11, category: 'Protein', emoji: '🫘', serving: '150g cooked'),
  FoodItem(name: 'Moong Dal (cooked)', calories: 105, protein: 7, category: 'Protein', emoji: '🫘', serving: '100g cooked'),
  FoodItem(name: 'Sprouts (mixed)', calories: 62, protein: 4, category: 'Protein', emoji: '🌱', serving: '100g'),
  FoodItem(name: 'Tuna (canned)', calories: 116, protein: 25, category: 'Protein', emoji: '🐟', serving: '100g drained'),
  FoodItem(name: 'Fish Curry', calories: 190, protein: 22, category: 'Protein', emoji: '🐟', serving: '150g'),

  // ── Rice & Roti ───────────────────────────────────────────────────────────
  FoodItem(name: 'White Rice', calories: 130, protein: 2.7, category: 'Rice & Roti', emoji: '🍚', serving: '100g cooked'),
  FoodItem(name: 'Brown Rice', calories: 112, protein: 2.6, category: 'Rice & Roti', emoji: '🍚', serving: '100g cooked'),
  FoodItem(name: 'Jeera Rice', calories: 160, protein: 3, category: 'Rice & Roti', emoji: '🍚', serving: '1 cup cooked'),
  FoodItem(name: 'Veg Biryani', calories: 350, protein: 8, category: 'Rice & Roti', emoji: '🍚', serving: '1 plate'),
  FoodItem(name: 'Chicken Biryani', calories: 490, protein: 28, category: 'Rice & Roti', emoji: '🍚', serving: '1 plate'),
  FoodItem(name: 'Curd Rice', calories: 190, protein: 5, category: 'Rice & Roti', emoji: '🍚', serving: '1 plate'),
  FoodItem(name: 'Lemon Rice', calories: 200, protein: 3, category: 'Rice & Roti', emoji: '🍚', serving: '1 plate'),
  FoodItem(name: 'Roti (wheat)', calories: 104, protein: 3, category: 'Rice & Roti', emoji: '🫓', serving: '1 roti (~40g)'),
  FoodItem(name: 'Roti with Ghee', calories: 134, protein: 3, category: 'Rice & Roti', emoji: '🫓', serving: '1 roti + 1 tsp ghee'),
  FoodItem(name: 'Chapati (thin)', calories: 80, protein: 2.5, category: 'Rice & Roti', emoji: '🫓', serving: '1 small'),
  FoodItem(name: 'Naan', calories: 262, protein: 8, category: 'Rice & Roti', emoji: '🫓', serving: '1 piece'),
  FoodItem(name: 'Fried Rice', calories: 220, protein: 5, category: 'Rice & Roti', emoji: '🍚', serving: '1 cup cooked'),

  // ── Dal & Curry ───────────────────────────────────────────────────────────
  FoodItem(name: 'Toor Dal', calories: 115, protein: 7, category: 'Dal & Curry', emoji: '🫘', serving: '1 katori (200ml)'),
  FoodItem(name: 'Dal Makhani', calories: 200, protein: 9, category: 'Dal & Curry', emoji: '🫘', serving: '1 bowl (200ml)'),
  FoodItem(name: 'Palak Dal', calories: 130, protein: 8, category: 'Dal & Curry', emoji: '🥬', serving: '1 katori'),
  FoodItem(name: 'Sambar', calories: 85, protein: 4, category: 'Dal & Curry', emoji: '🍲', serving: '1 bowl (200ml)'),
  FoodItem(name: 'Rasam', calories: 45, protein: 2, category: 'Dal & Curry', emoji: '🍲', serving: '1 cup'),
  FoodItem(name: 'Baingan Bharta', calories: 130, protein: 3, category: 'Dal & Curry', emoji: '🍆', serving: '1 katori'),
  FoodItem(name: 'Aloo Gobi', calories: 150, protein: 4, category: 'Dal & Curry', emoji: '🥦', serving: '1 katori'),
  FoodItem(name: 'Palak Paneer', calories: 220, protein: 14, category: 'Dal & Curry', emoji: '🥬', serving: '1 katori'),
  FoodItem(name: 'Butter Chicken', calories: 300, protein: 25, category: 'Dal & Curry', emoji: '🍗', serving: '150g'),

  // ── Snacks ───────────────────────────────────────────────────────────────
  FoodItem(name: 'Samosa', calories: 240, protein: 4, category: 'Snacks', emoji: '🥟', serving: '1 piece'),
  FoodItem(name: 'Kachori', calories: 210, protein: 5, category: 'Snacks', emoji: '🥟', serving: '1 piece'),
  FoodItem(name: 'Pakora (veg, 3 pcs)', calories: 180, protein: 4, category: 'Snacks', emoji: '🧆', serving: '3 pieces'),
  FoodItem(name: 'Murukku', calories: 150, protein: 3, category: 'Snacks', emoji: '🌀', serving: '30g'),
  FoodItem(name: 'Bhel Puri', calories: 180, protein: 5, category: 'Snacks', emoji: '🥗', serving: '1 plate'),
  FoodItem(name: 'Sev Puri', calories: 200, protein: 5, category: 'Snacks', emoji: '🥗', serving: '1 plate'),
  FoodItem(name: 'Roasted Chana', calories: 164, protein: 9, category: 'Snacks', emoji: '🫘', serving: '30g'),
  FoodItem(name: 'Khakhra (2)', calories: 120, protein: 3, category: 'Snacks', emoji: '🫓', serving: '2 pieces'),
  FoodItem(name: 'Marie Biscuits (3)', calories: 90, protein: 1.5, category: 'Snacks', emoji: '🍪', serving: '3 biscuits'),
  FoodItem(name: 'Digestive Biscuit (2)', calories: 140, protein: 2, category: 'Snacks', emoji: '🍪', serving: '2 biscuits'),
  FoodItem(name: 'Protein Bar (MuscleBlaze)', calories: 210, protein: 20, category: 'Snacks', emoji: '🍫', serving: '1 bar (70g)'),
  FoodItem(name: 'Banana Chips (30g)', calories: 162, protein: 1, category: 'Snacks', emoji: '🍌', serving: '30g'),
  FoodItem(name: 'Popcorn (plain)', calories: 93, protein: 3, category: 'Snacks', emoji: '🍿', serving: '30g popped'),

  // ── Street Food ───────────────────────────────────────────────────────────
  FoodItem(name: 'Pav Bhaji', calories: 400, protein: 10, category: 'Street Food', emoji: '🥖', serving: '2 pav + bhaji'),
  FoodItem(name: 'Vada Pav', calories: 285, protein: 7, category: 'Street Food', emoji: '🥖', serving: '1 piece'),
  FoodItem(name: 'Chole Bhature', calories: 550, protein: 18, category: 'Street Food', emoji: '🍛', serving: '1 plate (2 bhature)'),
  FoodItem(name: 'Dahi Puri (6)', calories: 210, protein: 6, category: 'Street Food', emoji: '🫙', serving: '6 pieces'),
  FoodItem(name: 'Pani Puri (6)', calories: 200, protein: 4, category: 'Street Food', emoji: '🫙', serving: '6 pieces'),
  FoodItem(name: 'Masala Puri', calories: 230, protein: 6, category: 'Street Food', emoji: '🥗', serving: '1 plate'),
  FoodItem(name: 'Sandwich (Veg)', calories: 200, protein: 7, category: 'Street Food', emoji: '🥪', serving: '1 sandwich'),
  FoodItem(name: 'Chicken Sandwich', calories: 280, protein: 22, category: 'Street Food', emoji: '🥪', serving: '1 sandwich'),
  FoodItem(name: 'Pizza (1 slice)', calories: 285, protein: 12, category: 'Street Food', emoji: '🍕', serving: '1 slice (~100g)'),
  FoodItem(name: 'Burger (veg)', calories: 310, protein: 10, category: 'Street Food', emoji: '🍔', serving: '1 burger'),
  FoodItem(name: 'Chicken Burger', calories: 430, protein: 28, category: 'Street Food', emoji: '🍔', serving: '1 burger'),

  // ── Fruits ───────────────────────────────────────────────────────────────
  FoodItem(name: 'Apple', calories: 52, protein: 0.3, category: 'Fruits', emoji: '🍎', serving: '1 medium (150g)'),
  FoodItem(name: 'Banana', calories: 89, protein: 1.1, category: 'Fruits', emoji: '🍌', serving: '1 medium (120g)'),
  FoodItem(name: 'Mango', calories: 135, protein: 1.4, category: 'Fruits', emoji: '🥭', serving: '1 medium (200g)'),
  FoodItem(name: 'Orange', calories: 47, protein: 0.9, category: 'Fruits', emoji: '🍊', serving: '1 medium (130g)'),
  FoodItem(name: 'Papaya', calories: 43, protein: 0.5, category: 'Fruits', emoji: '🍈', serving: '100g'),
  FoodItem(name: 'Watermelon', calories: 30, protein: 0.6, category: 'Fruits', emoji: '🍉', serving: '100g'),
  FoodItem(name: 'Pomegranate', calories: 83, protein: 1.7, category: 'Fruits', emoji: '🍎', serving: '100g arils'),
  FoodItem(name: 'Grapes (100g)', calories: 67, protein: 0.6, category: 'Fruits', emoji: '🍇', serving: '100g'),
  FoodItem(name: 'Guava', calories: 68, protein: 2.6, category: 'Fruits', emoji: '🍈', serving: '1 medium (100g)'),
  FoodItem(name: 'Pineapple (100g)', calories: 50, protein: 0.5, category: 'Fruits', emoji: '🍍', serving: '100g'),

  // ── Dairy ────────────────────────────────────────────────────────────────
  FoodItem(name: 'Full-Fat Milk', calories: 122, protein: 6.4, category: 'Dairy', emoji: '🥛', serving: '200ml'),
  FoodItem(name: 'Toned Milk', calories: 100, protein: 6, category: 'Dairy', emoji: '🥛', serving: '200ml'),
  FoodItem(name: 'Curd / Dahi', calories: 60, protein: 3.5, category: 'Dairy', emoji: '🥛', serving: '100g'),
  FoodItem(name: 'Greek Yogurt', calories: 100, protein: 10, category: 'Dairy', emoji: '🥛', serving: '150g'),
  FoodItem(name: 'Buttermilk (Chaas)', calories: 45, protein: 3, category: 'Dairy', emoji: '🥛', serving: '250ml'),
  FoodItem(name: 'Cottage Cheese (Paneer)', calories: 265, protein: 18, category: 'Dairy', emoji: '🧀', serving: '100g'),
  FoodItem(name: 'Ghee', calories: 112, protein: 0, category: 'Dairy', emoji: '🧈', serving: '1 tsp (14g)'),
  FoodItem(name: 'Butter', calories: 102, protein: 0.1, category: 'Dairy', emoji: '🧈', serving: '1 tbsp (14g)'),

  // ── Nuts & Seeds ──────────────────────────────────────────────────────────
  FoodItem(name: 'Almonds', calories: 58, protein: 2.1, category: 'Nuts & Seeds', emoji: '🌰', serving: '10g (~8 nuts)'),
  FoodItem(name: 'Cashews', calories: 55, protein: 1.8, category: 'Nuts & Seeds', emoji: '🥜', serving: '10g (~6 nuts)'),
  FoodItem(name: 'Walnuts', calories: 65, protein: 1.5, category: 'Nuts & Seeds', emoji: '🌰', serving: '10g'),
  FoodItem(name: 'Peanuts', calories: 170, protein: 7.7, category: 'Nuts & Seeds', emoji: '🥜', serving: '30g'),
  FoodItem(name: 'Peanut Butter (1 tbsp)', calories: 94, protein: 4, category: 'Nuts & Seeds', emoji: '🥜', serving: '1 tbsp (16g)'),
  FoodItem(name: 'Chia Seeds', calories: 58, protein: 2, category: 'Nuts & Seeds', emoji: '🌱', serving: '1 tbsp (15g)'),
  FoodItem(name: 'Flax Seeds', calories: 55, protein: 1.9, category: 'Nuts & Seeds', emoji: '🌱', serving: '1 tbsp (14g)'),
  FoodItem(name: 'Mixed Nuts (30g)', calories: 170, protein: 4.5, category: 'Nuts & Seeds', emoji: '🌰', serving: '30g'),

  // ── Drinks ───────────────────────────────────────────────────────────────
  FoodItem(name: 'Black Coffee', calories: 2, protein: 0.3, category: 'Drinks', emoji: '☕', serving: '1 cup (240ml)'),
  FoodItem(name: 'Coffee with Milk', calories: 65, protein: 3.5, category: 'Drinks', emoji: '☕', serving: '1 cup + 100ml milk'),
  FoodItem(name: 'Tea (no sugar)', calories: 5, protein: 0, category: 'Drinks', emoji: '🍵', serving: '1 cup'),
  FoodItem(name: 'Tea with Milk & Sugar', calories: 55, protein: 1.5, category: 'Drinks', emoji: '🍵', serving: '1 cup'),
  FoodItem(name: 'Protein Milk (200ml)', calories: 145, protein: 12, category: 'Drinks', emoji: '🥛', serving: '200ml'),
  FoodItem(name: 'Banana Protein Shake', calories: 280, protein: 28, category: 'Drinks', emoji: '🥤', serving: '1 shake (1 banana + 1 scoop)'),
  FoodItem(name: 'Coconut Water', calories: 48, protein: 0.5, category: 'Drinks', emoji: '🥥', serving: '240ml'),
  FoodItem(name: 'Lassi (sweet)', calories: 170, protein: 5, category: 'Drinks', emoji: '🥛', serving: '250ml'),
  FoodItem(name: 'Lassi (salted)', calories: 75, protein: 5, category: 'Drinks', emoji: '🥛', serving: '250ml'),
  FoodItem(name: 'Mango Lassi', calories: 220, protein: 4, category: 'Drinks', emoji: '🥭', serving: '250ml'),
  FoodItem(name: 'Fresh Lime Soda', calories: 25, protein: 0, category: 'Drinks', emoji: '🍋', serving: '1 glass'),
  FoodItem(name: 'Orange Juice', calories: 112, protein: 1.7, category: 'Drinks', emoji: '🍊', serving: '240ml'),

  // ── Supplements ───────────────────────────────────────────────────────────
  FoodItem(name: 'Whey Protein (1 scoop)', calories: 130, protein: 25, category: 'Supplement', emoji: '💪', serving: '1 scoop (33g)'),
  FoodItem(name: 'Creatine', calories: 0, protein: 0, category: 'Supplement', emoji: '⚡', serving: '5g'),
  FoodItem(name: 'BCAA (1 serving)', calories: 20, protein: 5, category: 'Supplement', emoji: '💊', serving: '1 scoop'),
  FoodItem(name: 'Mass Gainer (1 scoop)', calories: 380, protein: 28, category: 'Supplement', emoji: '💪', serving: '1 scoop (100g)'),
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
