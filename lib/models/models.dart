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
  'South Indian',
  'North Indian',
  'Indo-Chinese',
  'Breakfast',
  'Protein',
  'Rice & Biryani',
  'Roti & Bread',
  'Dal & Curry',
  'Street Food',
  'Fast Food',
  'Sweets & Desserts',
  'Snacks',
  'Fruits',
  'Dairy',
  'Nuts & Seeds',
  'Drinks',
  'Supplement',
];

const List<FoodItem> kFoodDatabase = [
  // ── Popular ───────────────────────────────────────────────────────────────
  FoodItem(name: 'Boiled Egg', calories: 78, protein: 6, category: 'Popular', emoji: '🥚', serving: '1 egg'),
  FoodItem(name: 'Roti', calories: 104, protein: 3, category: 'Popular', emoji: '🫓', serving: '1 roti (~40g)'),
  FoodItem(name: 'Rice (cooked)', calories: 130, protein: 2.7, category: 'Popular', emoji: '🍚', serving: '100g cooked'),
  FoodItem(name: 'Dal', calories: 120, protein: 8, category: 'Popular', emoji: '🫘', serving: '1 katori'),
  FoodItem(name: 'Grilled Chicken', calories: 219, protein: 43, category: 'Popular', emoji: '🍗', serving: '150g'),
  FoodItem(name: 'Paneer', calories: 265, protein: 18, category: 'Popular', emoji: '🧀', serving: '100g'),
  FoodItem(name: 'Oats', calories: 148, protein: 5, category: 'Popular', emoji: '🥣', serving: '40g dry'),
  FoodItem(name: 'Banana', calories: 89, protein: 1.1, category: 'Popular', emoji: '🍌', serving: '1 medium'),
  FoodItem(name: 'Curd / Dahi', calories: 60, protein: 3.5, category: 'Popular', emoji: '🥛', serving: '100g'),
  FoodItem(name: 'Whey Protein Shake', calories: 130, protein: 25, category: 'Popular', emoji: '💪', serving: '1 scoop (33g)'),
  FoodItem(name: 'Idli', calories: 70, protein: 2, category: 'Popular', emoji: '🫓', serving: '1 piece'),
  FoodItem(name: 'Masala Dosa', calories: 290, protein: 6, category: 'Popular', emoji: '🫓', serving: '1 dosa'),
  FoodItem(name: 'Chicken Biryani', calories: 490, protein: 28, category: 'Popular', emoji: '🍛', serving: '1 plate'),
  FoodItem(name: 'Rajma Chawal', calories: 390, protein: 15, category: 'Popular', emoji: '🫘', serving: '1 plate'),
  FoodItem(name: 'Pav Bhaji', calories: 400, protein: 10, category: 'Popular', emoji: '🥖', serving: '2 pav + bhaji'),

  // ── South Indian ──────────────────────────────────────────────────────────
  FoodItem(name: 'Idli', calories: 70, protein: 2, category: 'South Indian', emoji: '🫓', serving: '1 piece'),
  FoodItem(name: 'Idli with Sambar', calories: 220, protein: 8, category: 'South Indian', emoji: '🫓', serving: '2 idli + sambar'),
  FoodItem(name: 'Plain Dosa', calories: 165, protein: 4, category: 'South Indian', emoji: '🫓', serving: '1 dosa'),
  FoodItem(name: 'Masala Dosa', calories: 290, protein: 6, category: 'South Indian', emoji: '🫓', serving: '1 dosa'),
  FoodItem(name: 'Rava Dosa', calories: 200, protein: 4, category: 'South Indian', emoji: '🫓', serving: '1 dosa'),
  FoodItem(name: 'Uttapam', calories: 210, protein: 5, category: 'South Indian', emoji: '🥞', serving: '1 piece'),
  FoodItem(name: 'Pesarattu', calories: 170, protein: 8, category: 'South Indian', emoji: '🫓', serving: '1 piece'),
  FoodItem(name: 'Appam', calories: 120, protein: 3, category: 'South Indian', emoji: '🫓', serving: '1 piece'),
  FoodItem(name: 'Puttu', calories: 185, protein: 4, category: 'South Indian', emoji: '🌀', serving: '100g'),
  FoodItem(name: 'Idiyappam', calories: 110, protein: 2, category: 'South Indian', emoji: '🌀', serving: '2 pieces'),
  FoodItem(name: 'Kerala Parotta', calories: 280, protein: 5, category: 'South Indian', emoji: '🫓', serving: '1 piece'),
  FoodItem(name: 'Ven Pongal', calories: 200, protein: 6, category: 'South Indian', emoji: '🥣', serving: '1 bowl'),
  FoodItem(name: 'Medu Vada', calories: 150, protein: 5, category: 'South Indian', emoji: '🍩', serving: '1 piece'),
  FoodItem(name: 'Rava Idli', calories: 95, protein: 3, category: 'South Indian', emoji: '🫓', serving: '1 piece'),
  FoodItem(name: 'Upma', calories: 175, protein: 5, category: 'South Indian', emoji: '🥣', serving: '1 bowl (150g)'),
  FoodItem(name: 'Poha', calories: 180, protein: 4, category: 'South Indian', emoji: '🥣', serving: '1 bowl (150g)'),
  FoodItem(name: 'Sambar', calories: 85, protein: 4, category: 'South Indian', emoji: '🍲', serving: '1 bowl'),
  FoodItem(name: 'Rasam', calories: 45, protein: 2, category: 'South Indian', emoji: '🍲', serving: '1 cup'),
  FoodItem(name: 'Avial', calories: 130, protein: 3, category: 'South Indian', emoji: '🥘', serving: '1 katori'),
  FoodItem(name: 'Thoran (Cabbage)', calories: 90, protein: 2, category: 'South Indian', emoji: '🥗', serving: '1 katori'),
  FoodItem(name: 'Olan', calories: 100, protein: 3, category: 'South Indian', emoji: '🥘', serving: '1 katori'),
  FoodItem(name: 'Erissery', calories: 120, protein: 3, category: 'South Indian', emoji: '🥘', serving: '1 katori'),
  FoodItem(name: 'Kerala Fish Curry', calories: 200, protein: 24, category: 'South Indian', emoji: '🐟', serving: '150g'),
  FoodItem(name: 'Chettinad Chicken Curry', calories: 280, protein: 30, category: 'South Indian', emoji: '🍗', serving: '150g'),
  FoodItem(name: 'Curd Rice', calories: 190, protein: 5, category: 'South Indian', emoji: '🍚', serving: '1 plate'),
  FoodItem(name: 'Lemon Rice', calories: 200, protein: 3, category: 'South Indian', emoji: '🍚', serving: '1 plate'),
  FoodItem(name: 'Tamarind Rice (Puliyodharai)', calories: 210, protein: 3, category: 'South Indian', emoji: '🍚', serving: '1 plate'),
  FoodItem(name: 'Kozhukattai', calories: 120, protein: 2, category: 'South Indian', emoji: '🌀', serving: '2 pieces'),
  FoodItem(name: 'Murukku', calories: 150, protein: 3, category: 'South Indian', emoji: '🌀', serving: '30g'),
  FoodItem(name: 'Chakli', calories: 145, protein: 3, category: 'South Indian', emoji: '🌀', serving: '30g'),
  FoodItem(name: 'Payasam (Vermicelli)', calories: 220, protein: 4, category: 'South Indian', emoji: '🍮', serving: '1 bowl'),
  FoodItem(name: 'Payasam (Rice)', calories: 200, protein: 4, category: 'South Indian', emoji: '🍮', serving: '1 bowl'),
  FoodItem(name: 'Mysore Pak', calories: 180, protein: 3, category: 'South Indian', emoji: '🍬', serving: '1 piece (30g)'),

  // ── North Indian ──────────────────────────────────────────────────────────
  FoodItem(name: 'Roti (Wheat)', calories: 104, protein: 3, category: 'North Indian', emoji: '🫓', serving: '1 roti (~40g)'),
  FoodItem(name: 'Aloo Paratha', calories: 260, protein: 5, category: 'North Indian', emoji: '🫓', serving: '1 paratha'),
  FoodItem(name: 'Gobi Paratha', calories: 240, protein: 5, category: 'North Indian', emoji: '🫓', serving: '1 paratha'),
  FoodItem(name: 'Paneer Paratha', calories: 290, protein: 10, category: 'North Indian', emoji: '🫓', serving: '1 paratha'),
  FoodItem(name: 'Methi Paratha', calories: 220, protein: 5, category: 'North Indian', emoji: '🫓', serving: '1 paratha'),
  FoodItem(name: 'Thepla', calories: 165, protein: 4, category: 'North Indian', emoji: '🫓', serving: '1 piece'),
  FoodItem(name: 'Puri', calories: 160, protein: 2.5, category: 'North Indian', emoji: '🫓', serving: '1 piece'),
  FoodItem(name: 'Bhatura', calories: 280, protein: 6, category: 'North Indian', emoji: '🫓', serving: '1 piece'),
  FoodItem(name: 'Naan', calories: 262, protein: 8, category: 'North Indian', emoji: '🫓', serving: '1 piece'),
  FoodItem(name: 'Kulcha', calories: 240, protein: 7, category: 'North Indian', emoji: '🫓', serving: '1 piece'),
  FoodItem(name: 'Dal Makhani', calories: 200, protein: 9, category: 'North Indian', emoji: '🫘', serving: '1 bowl'),
  FoodItem(name: 'Dal Tadka', calories: 150, protein: 8, category: 'North Indian', emoji: '🫘', serving: '1 bowl'),
  FoodItem(name: 'Dal Fry', calories: 160, protein: 8, category: 'North Indian', emoji: '🫘', serving: '1 bowl'),
  FoodItem(name: 'Toor Dal', calories: 115, protein: 7, category: 'North Indian', emoji: '🫘', serving: '1 katori'),
  FoodItem(name: 'Rajma', calories: 195, protein: 12, category: 'North Indian', emoji: '🫘', serving: '1 katori'),
  FoodItem(name: 'Chole Masala', calories: 210, protein: 11, category: 'North Indian', emoji: '🫘', serving: '1 katori'),
  FoodItem(name: 'Palak Paneer', calories: 220, protein: 14, category: 'North Indian', emoji: '🥬', serving: '1 katori'),
  FoodItem(name: 'Matar Paneer', calories: 230, protein: 13, category: 'North Indian', emoji: '🧀', serving: '1 katori'),
  FoodItem(name: 'Kadai Paneer', calories: 250, protein: 14, category: 'North Indian', emoji: '🧀', serving: '1 katori'),
  FoodItem(name: 'Shahi Paneer', calories: 280, protein: 13, category: 'North Indian', emoji: '🧀', serving: '1 katori'),
  FoodItem(name: 'Malai Kofta', calories: 300, protein: 10, category: 'North Indian', emoji: '🧆', serving: '1 katori'),
  FoodItem(name: 'Paneer Tikka Masala', calories: 270, protein: 16, category: 'North Indian', emoji: '🧀', serving: '1 katori'),
  FoodItem(name: 'Butter Chicken', calories: 300, protein: 25, category: 'North Indian', emoji: '🍗', serving: '150g'),
  FoodItem(name: 'Chicken Tikka Masala', calories: 290, protein: 28, category: 'North Indian', emoji: '🍗', serving: '150g'),
  FoodItem(name: 'Aloo Gobi', calories: 150, protein: 4, category: 'North Indian', emoji: '🥦', serving: '1 katori'),
  FoodItem(name: 'Aloo Matar', calories: 160, protein: 5, category: 'North Indian', emoji: '🥔', serving: '1 katori'),
  FoodItem(name: 'Baingan Bharta', calories: 130, protein: 3, category: 'North Indian', emoji: '🍆', serving: '1 katori'),
  FoodItem(name: 'Bhindi Masala', calories: 120, protein: 3, category: 'North Indian', emoji: '🌿', serving: '1 katori'),
  FoodItem(name: 'Saag (Sarson ka Saag)', calories: 140, protein: 5, category: 'North Indian', emoji: '🥬', serving: '1 katori'),
  FoodItem(name: 'Palak Dal', calories: 130, protein: 8, category: 'North Indian', emoji: '🥬', serving: '1 katori'),
  FoodItem(name: 'Chole Bhature', calories: 550, protein: 18, category: 'North Indian', emoji: '🍛', serving: '1 plate'),
  FoodItem(name: 'Dhokla', calories: 120, protein: 4, category: 'North Indian', emoji: '🟡', serving: '3 pieces'),
  FoodItem(name: 'Khandvi', calories: 100, protein: 4, category: 'North Indian', emoji: '🌀', serving: '3 pieces'),
  FoodItem(name: 'Khaman', calories: 130, protein: 5, category: 'North Indian', emoji: '🟡', serving: '3 pieces'),
  FoodItem(name: 'Samosa', calories: 240, protein: 4, category: 'North Indian', emoji: '🥟', serving: '1 piece'),
  FoodItem(name: 'Kachori', calories: 210, protein: 5, category: 'North Indian', emoji: '🥟', serving: '1 piece'),
  FoodItem(name: 'Misal Pav', calories: 350, protein: 12, category: 'North Indian', emoji: '🥘', serving: '1 plate'),
  FoodItem(name: 'Pani Puri (6)', calories: 200, protein: 4, category: 'North Indian', emoji: '🫙', serving: '6 pieces'),
  FoodItem(name: 'Dahi Puri (6)', calories: 210, protein: 6, category: 'North Indian', emoji: '🫙', serving: '6 pieces'),
  FoodItem(name: 'Bhel Puri', calories: 180, protein: 5, category: 'North Indian', emoji: '🥗', serving: '1 plate'),

  // ── Indo-Chinese ──────────────────────────────────────────────────────────
  FoodItem(name: 'Veg Hakka Noodles', calories: 320, protein: 8, category: 'Indo-Chinese', emoji: '🍜', serving: '1 plate'),
  FoodItem(name: 'Chicken Chowmein', calories: 420, protein: 22, category: 'Indo-Chinese', emoji: '🍜', serving: '1 plate'),
  FoodItem(name: 'Veg Fried Rice', calories: 280, protein: 7, category: 'Indo-Chinese', emoji: '🍚', serving: '1 plate'),
  FoodItem(name: 'Egg Fried Rice', calories: 350, protein: 12, category: 'Indo-Chinese', emoji: '🍚', serving: '1 plate'),
  FoodItem(name: 'Chicken Fried Rice', calories: 420, protein: 22, category: 'Indo-Chinese', emoji: '🍚', serving: '1 plate'),
  FoodItem(name: 'Schezwan Fried Rice', calories: 380, protein: 8, category: 'Indo-Chinese', emoji: '🍚', serving: '1 plate'),
  FoodItem(name: 'Schezwan Noodles', calories: 360, protein: 9, category: 'Indo-Chinese', emoji: '🍜', serving: '1 plate'),
  FoodItem(name: 'Gobi Manchurian (Dry)', calories: 240, protein: 5, category: 'Indo-Chinese', emoji: '🥦', serving: '1 plate'),
  FoodItem(name: 'Gobi Manchurian (Gravy)', calories: 280, protein: 6, category: 'Indo-Chinese', emoji: '🥦', serving: '1 bowl'),
  FoodItem(name: 'Veg Manchurian', calories: 250, protein: 6, category: 'Indo-Chinese', emoji: '🧆', serving: '1 plate'),
  FoodItem(name: 'Chilli Chicken (Dry)', calories: 310, protein: 28, category: 'Indo-Chinese', emoji: '🍗', serving: '150g'),
  FoodItem(name: 'Chilli Chicken (Gravy)', calories: 290, protein: 26, category: 'Indo-Chinese', emoji: '🍗', serving: '1 bowl'),
  FoodItem(name: 'Chilli Paneer (Dry)', calories: 270, protein: 16, category: 'Indo-Chinese', emoji: '🧀', serving: '1 plate'),
  FoodItem(name: 'Chilli Paneer (Gravy)', calories: 290, protein: 15, category: 'Indo-Chinese', emoji: '🧀', serving: '1 bowl'),
  FoodItem(name: 'Veg Momos (6 pcs)', calories: 220, protein: 8, category: 'Indo-Chinese', emoji: '🥟', serving: '6 pieces'),
  FoodItem(name: 'Chicken Momos (6 pcs)', calories: 280, protein: 18, category: 'Indo-Chinese', emoji: '🥟', serving: '6 pieces'),
  FoodItem(name: 'Pan-Fried Momos (6)', calories: 320, protein: 14, category: 'Indo-Chinese', emoji: '🥟', serving: '6 pieces'),
  FoodItem(name: 'Veg Spring Roll (2)', calories: 190, protein: 4, category: 'Indo-Chinese', emoji: '🌯', serving: '2 rolls'),
  FoodItem(name: 'Crispy Corn', calories: 300, protein: 5, category: 'Indo-Chinese', emoji: '🌽', serving: '1 bowl'),
  FoodItem(name: 'Honey Chilli Potato', calories: 350, protein: 4, category: 'Indo-Chinese', emoji: '🍟', serving: '1 plate'),
  FoodItem(name: 'Chicken 65', calories: 320, protein: 28, category: 'Indo-Chinese', emoji: '🍗', serving: '150g'),
  FoodItem(name: 'Babycorn Manchurian', calories: 220, protein: 5, category: 'Indo-Chinese', emoji: '🌽', serving: '1 plate'),

  // ── Breakfast ────────────────────────────────────────────────────────────
  FoodItem(name: 'Egg Omelette (3 eggs)', calories: 210, protein: 18, category: 'Breakfast', emoji: '🍳', serving: '3 eggs'),
  FoodItem(name: 'Masala Omelette (2 eggs)', calories: 165, protein: 13, category: 'Breakfast', emoji: '🍳', serving: '2 eggs'),
  FoodItem(name: 'Scrambled Eggs (2)', calories: 150, protein: 12, category: 'Breakfast', emoji: '🍳', serving: '2 eggs'),
  FoodItem(name: 'Boiled Egg', calories: 78, protein: 6, category: 'Breakfast', emoji: '🥚', serving: '1 egg'),
  FoodItem(name: 'Bread (White)', calories: 69, protein: 2.3, category: 'Breakfast', emoji: '🍞', serving: '1 slice (30g)'),
  FoodItem(name: 'Bread (Brown/Multigrain)', calories: 65, protein: 3, category: 'Breakfast', emoji: '🍞', serving: '1 slice (30g)'),
  FoodItem(name: 'Bread with Peanut Butter', calories: 188, protein: 8, category: 'Breakfast', emoji: '🍞', serving: '2 slices + 1 tbsp PB'),
  FoodItem(name: 'Oats (plain)', calories: 148, protein: 5, category: 'Breakfast', emoji: '🥣', serving: '40g dry'),
  FoodItem(name: 'Oats with Milk & Banana', calories: 285, protein: 10, category: 'Breakfast', emoji: '🥣', serving: '40g oats + 200ml milk + banana'),
  FoodItem(name: 'Corn Flakes with Milk', calories: 185, protein: 6, category: 'Breakfast', emoji: '🥣', serving: '30g + 150ml milk'),
  FoodItem(name: 'Muesli with Milk', calories: 240, protein: 8, category: 'Breakfast', emoji: '🥣', serving: '45g + 150ml milk'),
  FoodItem(name: 'Besan Chilla (2)', calories: 180, protein: 10, category: 'Breakfast', emoji: '🥞', serving: '2 chilla'),
  FoodItem(name: 'Moong Chilla (2)', calories: 160, protein: 9, category: 'Breakfast', emoji: '🥞', serving: '2 chilla'),
  FoodItem(name: 'Upma', calories: 175, protein: 5, category: 'Breakfast', emoji: '🥣', serving: '1 bowl (150g)'),
  FoodItem(name: 'Poha', calories: 180, protein: 4, category: 'Breakfast', emoji: '🥣', serving: '1 bowl (150g)'),
  FoodItem(name: 'Aloo Paratha', calories: 260, protein: 5, category: 'Breakfast', emoji: '🫓', serving: '1 paratha'),

  // ── Protein sources ───────────────────────────────────────────────────────
  FoodItem(name: 'Boiled Egg White (1)', calories: 17, protein: 3.6, category: 'Protein', emoji: '🥚', serving: '1 white only'),
  FoodItem(name: 'Boiled Egg (whole)', calories: 78, protein: 6, category: 'Protein', emoji: '🥚', serving: '1 egg'),
  FoodItem(name: 'Egg Curry (2 eggs)', calories: 200, protein: 14, category: 'Protein', emoji: '🍳', serving: '2 eggs'),
  FoodItem(name: 'Grilled Chicken Breast', calories: 165, protein: 31, category: 'Protein', emoji: '🍗', serving: '100g'),
  FoodItem(name: 'Boiled Chicken', calories: 215, protein: 40, category: 'Protein', emoji: '🍗', serving: '150g'),
  FoodItem(name: 'Chicken Curry', calories: 248, protein: 28, category: 'Protein', emoji: '🍛', serving: '150g'),
  FoodItem(name: 'Paneer (raw)', calories: 265, protein: 18, category: 'Protein', emoji: '🧀', serving: '100g'),
  FoodItem(name: 'Paneer Bhurji', calories: 200, protein: 16, category: 'Protein', emoji: '🧆', serving: '100g'),
  FoodItem(name: 'Paneer Tikka', calories: 230, protein: 19, category: 'Protein', emoji: '🍢', serving: '100g'),
  FoodItem(name: 'Tofu (firm)', calories: 76, protein: 8, category: 'Protein', emoji: '🧀', serving: '100g'),
  FoodItem(name: 'Moong Dal (cooked)', calories: 105, protein: 7, category: 'Protein', emoji: '🫘', serving: '100g cooked'),
  FoodItem(name: 'Sprouts (mixed)', calories: 62, protein: 4, category: 'Protein', emoji: '🌱', serving: '100g'),
  FoodItem(name: 'Tuna (canned)', calories: 116, protein: 25, category: 'Protein', emoji: '🐟', serving: '100g drained'),
  FoodItem(name: 'Fish Curry', calories: 190, protein: 22, category: 'Protein', emoji: '🐟', serving: '150g'),
  FoodItem(name: 'Soya Chunks (cooked)', calories: 145, protein: 20, category: 'Protein', emoji: '🌱', serving: '100g'),

  // ── Rice & Biryani ────────────────────────────────────────────────────────
  FoodItem(name: 'White Rice', calories: 130, protein: 2.7, category: 'Rice & Biryani', emoji: '🍚', serving: '100g cooked'),
  FoodItem(name: 'Brown Rice', calories: 112, protein: 2.6, category: 'Rice & Biryani', emoji: '🍚', serving: '100g cooked'),
  FoodItem(name: 'Jeera Rice', calories: 160, protein: 3, category: 'Rice & Biryani', emoji: '🍚', serving: '1 cup cooked'),
  FoodItem(name: 'Veg Biryani', calories: 350, protein: 8, category: 'Rice & Biryani', emoji: '🍛', serving: '1 plate'),
  FoodItem(name: 'Chicken Biryani', calories: 490, protein: 28, category: 'Rice & Biryani', emoji: '🍛', serving: '1 plate'),
  FoodItem(name: 'Mutton Biryani', calories: 540, protein: 30, category: 'Rice & Biryani', emoji: '🍛', serving: '1 plate'),
  FoodItem(name: 'Egg Biryani', calories: 400, protein: 18, category: 'Rice & Biryani', emoji: '🍛', serving: '1 plate'),
  FoodItem(name: 'Hyderabadi Biryani', calories: 510, protein: 26, category: 'Rice & Biryani', emoji: '🍛', serving: '1 plate'),
  FoodItem(name: 'Kozhikodan Biryani', calories: 480, protein: 27, category: 'Rice & Biryani', emoji: '🍛', serving: '1 plate'),
  FoodItem(name: 'Pulao (veg)', calories: 280, protein: 6, category: 'Rice & Biryani', emoji: '🍚', serving: '1 plate'),
  FoodItem(name: 'Curd Rice', calories: 190, protein: 5, category: 'Rice & Biryani', emoji: '🍚', serving: '1 plate'),
  FoodItem(name: 'Lemon Rice', calories: 200, protein: 3, category: 'Rice & Biryani', emoji: '🍚', serving: '1 plate'),
  FoodItem(name: 'Tomato Rice', calories: 210, protein: 4, category: 'Rice & Biryani', emoji: '🍚', serving: '1 plate'),
  FoodItem(name: 'Coconut Rice', calories: 230, protein: 3, category: 'Rice & Biryani', emoji: '🍚', serving: '1 plate'),
  FoodItem(name: 'Rajma Chawal', calories: 390, protein: 15, category: 'Rice & Biryani', emoji: '🫘', serving: '1 plate'),

  // ── Roti & Bread ──────────────────────────────────────────────────────────
  FoodItem(name: 'Roti (wheat)', calories: 104, protein: 3, category: 'Roti & Bread', emoji: '🫓', serving: '1 roti (~40g)'),
  FoodItem(name: 'Roti with Ghee', calories: 134, protein: 3, category: 'Roti & Bread', emoji: '🫓', serving: '1 roti + ghee'),
  FoodItem(name: 'Chapati (thin)', calories: 80, protein: 2.5, category: 'Roti & Bread', emoji: '🫓', serving: '1 small'),
  FoodItem(name: 'Plain Paratha', calories: 200, protein: 4, category: 'Roti & Bread', emoji: '🫓', serving: '1 paratha'),
  FoodItem(name: 'Naan', calories: 262, protein: 8, category: 'Roti & Bread', emoji: '🫓', serving: '1 piece'),
  FoodItem(name: 'Garlic Naan', calories: 290, protein: 8, category: 'Roti & Bread', emoji: '🫓', serving: '1 piece'),
  FoodItem(name: 'Bread (White)', calories: 69, protein: 2.3, category: 'Roti & Bread', emoji: '🍞', serving: '1 slice (30g)'),
  FoodItem(name: 'Bread (Brown)', calories: 65, protein: 3, category: 'Roti & Bread', emoji: '🍞', serving: '1 slice (30g)'),
  FoodItem(name: 'Puri', calories: 160, protein: 2.5, category: 'Roti & Bread', emoji: '🫓', serving: '1 piece'),

  // ── Dal & Curry ───────────────────────────────────────────────────────────
  FoodItem(name: 'Toor Dal', calories: 115, protein: 7, category: 'Dal & Curry', emoji: '🫘', serving: '1 katori'),
  FoodItem(name: 'Dal Makhani', calories: 200, protein: 9, category: 'Dal & Curry', emoji: '🫘', serving: '1 bowl'),
  FoodItem(name: 'Dal Tadka', calories: 150, protein: 8, category: 'Dal & Curry', emoji: '🫘', serving: '1 bowl'),
  FoodItem(name: 'Palak Dal', calories: 130, protein: 8, category: 'Dal & Curry', emoji: '🥬', serving: '1 katori'),
  FoodItem(name: 'Rajma', calories: 195, protein: 12, category: 'Dal & Curry', emoji: '🫘', serving: '1 katori'),
  FoodItem(name: 'Chole (Chickpeas)', calories: 210, protein: 11, category: 'Dal & Curry', emoji: '🫘', serving: '1 katori'),
  FoodItem(name: 'Sambar', calories: 85, protein: 4, category: 'Dal & Curry', emoji: '🍲', serving: '1 bowl'),
  FoodItem(name: 'Palak Paneer', calories: 220, protein: 14, category: 'Dal & Curry', emoji: '🥬', serving: '1 katori'),
  FoodItem(name: 'Butter Chicken', calories: 300, protein: 25, category: 'Dal & Curry', emoji: '🍗', serving: '150g'),
  FoodItem(name: 'Mixed Veg Curry', calories: 140, protein: 4, category: 'Dal & Curry', emoji: '🥘', serving: '1 katori'),

  // ── Street Food ───────────────────────────────────────────────────────────
  FoodItem(name: 'Pav Bhaji', calories: 400, protein: 10, category: 'Street Food', emoji: '🥖', serving: '2 pav + bhaji'),
  FoodItem(name: 'Vada Pav', calories: 285, protein: 7, category: 'Street Food', emoji: '🥖', serving: '1 piece'),
  FoodItem(name: 'Pani Puri (6)', calories: 200, protein: 4, category: 'Street Food', emoji: '🫙', serving: '6 pieces'),
  FoodItem(name: 'Dahi Puri (6)', calories: 210, protein: 6, category: 'Street Food', emoji: '🫙', serving: '6 pieces'),
  FoodItem(name: 'Bhel Puri', calories: 180, protein: 5, category: 'Street Food', emoji: '🥗', serving: '1 plate'),
  FoodItem(name: 'Sev Puri', calories: 200, protein: 5, category: 'Street Food', emoji: '🥗', serving: '1 plate'),
  FoodItem(name: 'Masala Puri', calories: 230, protein: 6, category: 'Street Food', emoji: '🥗', serving: '1 plate'),
  FoodItem(name: 'Dabeli', calories: 280, protein: 6, category: 'Street Food', emoji: '🥖', serving: '1 piece'),
  FoodItem(name: 'Kathi Roll / Frankie (Veg)', calories: 280, protein: 7, category: 'Street Food', emoji: '🌯', serving: '1 roll'),
  FoodItem(name: 'Kathi Roll / Frankie (Chicken)', calories: 350, protein: 22, category: 'Street Food', emoji: '🌯', serving: '1 roll'),
  FoodItem(name: 'Egg Roll', calories: 320, protein: 14, category: 'Street Food', emoji: '🌯', serving: '1 roll'),
  FoodItem(name: 'Veg Sandwich', calories: 200, protein: 7, category: 'Street Food', emoji: '🥪', serving: '1 sandwich'),
  FoodItem(name: 'Bombay Sandwich', calories: 280, protein: 8, category: 'Street Food', emoji: '🥪', serving: '1 sandwich'),
  FoodItem(name: 'Club Sandwich', calories: 380, protein: 18, category: 'Street Food', emoji: '🥪', serving: '1 sandwich'),
  FoodItem(name: 'Chicken Sandwich', calories: 280, protein: 22, category: 'Street Food', emoji: '🥪', serving: '1 sandwich'),
  FoodItem(name: 'Maggi (1 pack)', calories: 350, protein: 8, category: 'Street Food', emoji: '🍜', serving: '1 pack (70g)'),
  FoodItem(name: 'Samosa', calories: 240, protein: 4, category: 'Street Food', emoji: '🥟', serving: '1 piece'),
  FoodItem(name: 'Pakora (3 pcs)', calories: 180, protein: 4, category: 'Street Food', emoji: '🧆', serving: '3 pieces'),
  FoodItem(name: 'Misal Pav', calories: 350, protein: 12, category: 'Street Food', emoji: '🥘', serving: '1 plate'),

  // ── Fast Food ─────────────────────────────────────────────────────────────
  FoodItem(name: 'McAloo Tikki Burger', calories: 340, protein: 10, category: 'Fast Food', emoji: '🍔', serving: '1 burger'),
  FoodItem(name: 'McSpicy Paneer Burger', calories: 440, protein: 15, category: 'Fast Food', emoji: '🍔', serving: '1 burger'),
  FoodItem(name: 'McSpicy Chicken Burger', calories: 510, protein: 28, category: 'Fast Food', emoji: '🍔', serving: '1 burger'),
  FoodItem(name: 'KFC Chicken Burger', calories: 490, protein: 26, category: 'Fast Food', emoji: '🍔', serving: '1 burger'),
  FoodItem(name: 'Veg Burger', calories: 310, protein: 10, category: 'Fast Food', emoji: '🍔', serving: '1 burger'),
  FoodItem(name: 'Chicken Burger', calories: 430, protein: 28, category: 'Fast Food', emoji: '🍔', serving: '1 burger'),
  FoodItem(name: 'French Fries (Medium)', calories: 320, protein: 4, category: 'Fast Food', emoji: '🍟', serving: '1 medium pack'),
  FoodItem(name: 'Pizza Margherita (2 slices)', calories: 500, protein: 20, category: 'Fast Food', emoji: '🍕', serving: '2 slices'),
  FoodItem(name: 'Pizza Farmhouse (2 slices)', calories: 560, protein: 24, category: 'Fast Food', emoji: '🍕', serving: '2 slices'),
  FoodItem(name: 'Pizza (1 slice)', calories: 285, protein: 12, category: 'Fast Food', emoji: '🍕', serving: '1 slice'),
  FoodItem(name: 'Subway Veg Sub (6")', calories: 350, protein: 12, category: 'Fast Food', emoji: '🥖', serving: '6 inch sub'),
  FoodItem(name: 'Subway Chicken Sub (6")', calories: 420, protein: 28, category: 'Fast Food', emoji: '🥖', serving: '6 inch sub'),
  FoodItem(name: 'Loaded Nachos', calories: 420, protein: 8, category: 'Fast Food', emoji: '🌮', serving: '1 plate'),
  FoodItem(name: 'Chicken Wings (6 pcs)', calories: 430, protein: 36, category: 'Fast Food', emoji: '🍗', serving: '6 pieces'),
  FoodItem(name: 'Lays Chips (30g)', calories: 160, protein: 2, category: 'Fast Food', emoji: '🥔', serving: '30g bag'),
  FoodItem(name: 'Kurkure (30g)', calories: 150, protein: 2, category: 'Fast Food', emoji: '🌽', serving: '30g'),

  // ── Sweets & Desserts ──────────────────────────────────────────────────────
  FoodItem(name: 'Gulab Jamun', calories: 175, protein: 3, category: 'Sweets & Desserts', emoji: '🍮', serving: '2 pieces'),
  FoodItem(name: 'Rasgulla', calories: 100, protein: 3, category: 'Sweets & Desserts', emoji: '⚪', serving: '2 pieces'),
  FoodItem(name: 'Rasmalai', calories: 150, protein: 5, category: 'Sweets & Desserts', emoji: '🍮', serving: '2 pieces'),
  FoodItem(name: 'Jalebi', calories: 150, protein: 1, category: 'Sweets & Desserts', emoji: '🍩', serving: '2 pieces (50g)'),
  FoodItem(name: 'Imarti', calories: 160, protein: 2, category: 'Sweets & Desserts', emoji: '🍩', serving: '1 piece'),
  FoodItem(name: 'Besan Ladoo', calories: 175, protein: 4, category: 'Sweets & Desserts', emoji: '🟡', serving: '1 piece (40g)'),
  FoodItem(name: 'Motichoor Ladoo', calories: 180, protein: 3, category: 'Sweets & Desserts', emoji: '🟡', serving: '1 piece (40g)'),
  FoodItem(name: 'Coconut Ladoo', calories: 160, protein: 2, category: 'Sweets & Desserts', emoji: '🥥', serving: '1 piece (35g)'),
  FoodItem(name: 'Gajar Halwa', calories: 200, protein: 3, category: 'Sweets & Desserts', emoji: '🥕', serving: '1 katori (100g)'),
  FoodItem(name: 'Suji Halwa', calories: 190, protein: 3, category: 'Sweets & Desserts', emoji: '🍮', serving: '1 katori (100g)'),
  FoodItem(name: 'Moong Dal Halwa', calories: 220, protein: 6, category: 'Sweets & Desserts', emoji: '🍮', serving: '1 katori'),
  FoodItem(name: 'Rice Kheer', calories: 180, protein: 4, category: 'Sweets & Desserts', emoji: '🥣', serving: '1 bowl'),
  FoodItem(name: 'Seviyan Kheer', calories: 190, protein: 5, category: 'Sweets & Desserts', emoji: '🥣', serving: '1 bowl'),
  FoodItem(name: 'Kaju Barfi', calories: 195, protein: 4, category: 'Sweets & Desserts', emoji: '🍬', serving: '2 pieces (40g)'),
  FoodItem(name: 'Milk Barfi', calories: 185, protein: 4, category: 'Sweets & Desserts', emoji: '🍬', serving: '2 pieces'),
  FoodItem(name: 'Coconut Barfi', calories: 170, protein: 2, category: 'Sweets & Desserts', emoji: '🥥', serving: '2 pieces'),
  FoodItem(name: 'Peda', calories: 130, protein: 3, category: 'Sweets & Desserts', emoji: '🟤', serving: '2 pieces'),
  FoodItem(name: 'Sandesh', calories: 120, protein: 5, category: 'Sweets & Desserts', emoji: '⚪', serving: '2 pieces'),
  FoodItem(name: 'Mysore Pak', calories: 180, protein: 3, category: 'Sweets & Desserts', emoji: '🍬', serving: '1 piece (30g)'),
  FoodItem(name: 'Kulfi (Matka)', calories: 130, protein: 4, category: 'Sweets & Desserts', emoji: '🍦', serving: '1 piece (80g)'),
  FoodItem(name: 'Rabri', calories: 190, protein: 5, category: 'Sweets & Desserts', emoji: '🥛', serving: '1 bowl'),
  FoodItem(name: 'Basundi', calories: 200, protein: 6, category: 'Sweets & Desserts', emoji: '🥛', serving: '1 bowl'),
  FoodItem(name: 'Ice Cream (Vanilla)', calories: 207, protein: 4, category: 'Sweets & Desserts', emoji: '🍦', serving: '100g'),
  FoodItem(name: 'Payasam', calories: 210, protein: 4, category: 'Sweets & Desserts', emoji: '🍮', serving: '1 bowl'),
  FoodItem(name: 'Halwa Poori (combo)', calories: 520, protein: 8, category: 'Sweets & Desserts', emoji: '🍮', serving: '1 plate'),

  // ── Snacks ───────────────────────────────────────────────────────────────
  FoodItem(name: 'Roasted Chana', calories: 164, protein: 9, category: 'Snacks', emoji: '🫘', serving: '30g'),
  FoodItem(name: 'Khakhra (2)', calories: 120, protein: 3, category: 'Snacks', emoji: '🫓', serving: '2 pieces'),
  FoodItem(name: 'Marie Biscuits (3)', calories: 90, protein: 1.5, category: 'Snacks', emoji: '🍪', serving: '3 biscuits'),
  FoodItem(name: 'Digestive Biscuit (2)', calories: 140, protein: 2, category: 'Snacks', emoji: '🍪', serving: '2 biscuits'),
  FoodItem(name: 'Protein Bar (MuscleBlaze)', calories: 210, protein: 20, category: 'Snacks', emoji: '🍫', serving: '1 bar (70g)'),
  FoodItem(name: 'Banana Chips (30g)', calories: 162, protein: 1, category: 'Snacks', emoji: '🍌', serving: '30g'),
  FoodItem(name: 'Popcorn (plain)', calories: 93, protein: 3, category: 'Snacks', emoji: '🍿', serving: '30g popped'),
  FoodItem(name: 'Peanuts (salted)', calories: 170, protein: 7.7, category: 'Snacks', emoji: '🥜', serving: '30g'),
  FoodItem(name: 'Chivda / Mixture', calories: 160, protein: 4, category: 'Snacks', emoji: '🌾', serving: '30g'),
  FoodItem(name: 'Mathri', calories: 160, protein: 3, category: 'Snacks', emoji: '🫓', serving: '3 pieces'),
  FoodItem(name: 'Namak Para', calories: 155, protein: 3, category: 'Snacks', emoji: '🫓', serving: '30g'),

  // ── Fruits ───────────────────────────────────────────────────────────────
  FoodItem(name: 'Apple', calories: 52, protein: 0.3, category: 'Fruits', emoji: '🍎', serving: '1 medium (150g)'),
  FoodItem(name: 'Banana', calories: 89, protein: 1.1, category: 'Fruits', emoji: '🍌', serving: '1 medium (120g)'),
  FoodItem(name: 'Mango', calories: 135, protein: 1.4, category: 'Fruits', emoji: '🥭', serving: '1 medium (200g)'),
  FoodItem(name: 'Orange', calories: 47, protein: 0.9, category: 'Fruits', emoji: '🍊', serving: '1 medium (130g)'),
  FoodItem(name: 'Papaya', calories: 43, protein: 0.5, category: 'Fruits', emoji: '🍈', serving: '100g'),
  FoodItem(name: 'Watermelon', calories: 30, protein: 0.6, category: 'Fruits', emoji: '🍉', serving: '100g'),
  FoodItem(name: 'Pomegranate', calories: 83, protein: 1.7, category: 'Fruits', emoji: '🍎', serving: '100g arils'),
  FoodItem(name: 'Grapes', calories: 67, protein: 0.6, category: 'Fruits', emoji: '🍇', serving: '100g'),
  FoodItem(name: 'Guava', calories: 68, protein: 2.6, category: 'Fruits', emoji: '🍈', serving: '1 medium (100g)'),
  FoodItem(name: 'Pineapple', calories: 50, protein: 0.5, category: 'Fruits', emoji: '🍍', serving: '100g'),
  FoodItem(name: 'Strawberry', calories: 32, protein: 0.7, category: 'Fruits', emoji: '🍓', serving: '100g'),
  FoodItem(name: 'Chickoo (Sapota)', calories: 83, protein: 0.4, category: 'Fruits', emoji: '🍈', serving: '100g'),
  FoodItem(name: 'Kiwi', calories: 61, protein: 1.1, category: 'Fruits', emoji: '🥝', serving: '1 medium (76g)'),
  FoodItem(name: 'Dates (Khajur)', calories: 282, protein: 2.5, category: 'Fruits', emoji: '🤎', serving: '4 pieces (40g)'),

  // ── Dairy ────────────────────────────────────────────────────────────────
  FoodItem(name: 'Full-Fat Milk', calories: 122, protein: 6.4, category: 'Dairy', emoji: '🥛', serving: '200ml'),
  FoodItem(name: 'Toned Milk', calories: 100, protein: 6, category: 'Dairy', emoji: '🥛', serving: '200ml'),
  FoodItem(name: 'Skim Milk', calories: 70, protein: 7, category: 'Dairy', emoji: '🥛', serving: '200ml'),
  FoodItem(name: 'Curd / Dahi', calories: 60, protein: 3.5, category: 'Dairy', emoji: '🥛', serving: '100g'),
  FoodItem(name: 'Greek Yogurt', calories: 100, protein: 10, category: 'Dairy', emoji: '🥛', serving: '150g'),
  FoodItem(name: 'Buttermilk (Chaas)', calories: 45, protein: 3, category: 'Dairy', emoji: '🥛', serving: '250ml'),
  FoodItem(name: 'Paneer', calories: 265, protein: 18, category: 'Dairy', emoji: '🧀', serving: '100g'),
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
  FoodItem(name: 'Pistachios', calories: 57, protein: 2.1, category: 'Nuts & Seeds', emoji: '🌰', serving: '10g'),

  // ── Drinks ───────────────────────────────────────────────────────────────
  FoodItem(name: 'Black Coffee', calories: 2, protein: 0.3, category: 'Drinks', emoji: '☕', serving: '1 cup (240ml)'),
  FoodItem(name: 'Coffee with Milk', calories: 65, protein: 3.5, category: 'Drinks', emoji: '☕', serving: '1 cup + 100ml milk'),
  FoodItem(name: 'Filter Coffee (South Indian)', calories: 80, protein: 3, category: 'Drinks', emoji: '☕', serving: '1 cup with milk'),
  FoodItem(name: 'Tea (no sugar)', calories: 5, protein: 0, category: 'Drinks', emoji: '🍵', serving: '1 cup'),
  FoodItem(name: 'Masala Chai', calories: 60, protein: 2, category: 'Drinks', emoji: '🍵', serving: '1 cup (150ml)'),
  FoodItem(name: 'Tea with Milk & Sugar', calories: 55, protein: 1.5, category: 'Drinks', emoji: '🍵', serving: '1 cup'),
  FoodItem(name: 'Badam Milk', calories: 165, protein: 7, category: 'Drinks', emoji: '🥛', serving: '250ml'),
  FoodItem(name: 'Turmeric Milk (Haldi Doodh)', calories: 110, protein: 5, category: 'Drinks', emoji: '🥛', serving: '200ml'),
  FoodItem(name: 'Banana Protein Shake', calories: 280, protein: 28, category: 'Drinks', emoji: '🥤', serving: '1 shake'),
  FoodItem(name: 'Coconut Water', calories: 48, protein: 0.5, category: 'Drinks', emoji: '🥥', serving: '240ml'),
  FoodItem(name: 'Lassi (sweet)', calories: 170, protein: 5, category: 'Drinks', emoji: '🥛', serving: '250ml'),
  FoodItem(name: 'Lassi (salted)', calories: 75, protein: 5, category: 'Drinks', emoji: '🥛', serving: '250ml'),
  FoodItem(name: 'Mango Lassi', calories: 220, protein: 4, category: 'Drinks', emoji: '🥭', serving: '250ml'),
  FoodItem(name: 'Nimbu Pani / Lemonade', calories: 30, protein: 0, category: 'Drinks', emoji: '🍋', serving: '1 glass'),
  FoodItem(name: 'Sugarcane Juice', calories: 180, protein: 0.3, category: 'Drinks', emoji: '🍹', serving: '1 glass (250ml)'),
  FoodItem(name: 'Orange Juice (fresh)', calories: 112, protein: 1.7, category: 'Drinks', emoji: '🍊', serving: '240ml'),
  FoodItem(name: 'Aam Panna', calories: 90, protein: 0.5, category: 'Drinks', emoji: '🥭', serving: '1 glass'),
  FoodItem(name: 'Jaljeera', calories: 40, protein: 0.5, category: 'Drinks', emoji: '🥤', serving: '1 glass'),
  FoodItem(name: 'Rose Milk', calories: 150, protein: 5, category: 'Drinks', emoji: '🥛', serving: '250ml'),
  FoodItem(name: 'Protein Milk (200ml)', calories: 145, protein: 12, category: 'Drinks', emoji: '🥛', serving: '200ml'),
  FoodItem(name: 'Energy Drink (can)', calories: 110, protein: 1, category: 'Drinks', emoji: '⚡', serving: '250ml can'),
  FoodItem(name: 'Cold Coffee', calories: 150, protein: 5, category: 'Drinks', emoji: '☕', serving: '250ml'),
  FoodItem(name: 'Thandai', calories: 190, protein: 5, category: 'Drinks', emoji: '🥛', serving: '1 glass'),

  // ── Supplement ────────────────────────────────────────────────────────────
  FoodItem(name: 'Whey Protein (1 scoop)', calories: 130, protein: 25, category: 'Supplement', emoji: '💪', serving: '1 scoop (33g)'),
  FoodItem(name: 'Creatine', calories: 0, protein: 0, category: 'Supplement', emoji: '⚡', serving: '5g'),
  FoodItem(name: 'BCAA (1 serving)', calories: 20, protein: 5, category: 'Supplement', emoji: '💊', serving: '1 scoop'),
  FoodItem(name: 'Mass Gainer (1 scoop)', calories: 380, protein: 28, category: 'Supplement', emoji: '💪', serving: '1 scoop (100g)'),
  FoodItem(name: 'Multivitamin Tablet', calories: 5, protein: 0, category: 'Supplement', emoji: '💊', serving: '1 tablet'),
  FoodItem(name: 'Casein Protein (1 scoop)', calories: 120, protein: 24, category: 'Supplement', emoji: '💪', serving: '1 scoop (34g)'),
];

