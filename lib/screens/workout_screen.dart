import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../providers/fitness_provider.dart';
import '../models/models.dart';

// ─── Design tokens ─────────────────────────────────────────────────────────────
const _kGreen = Color(0xFF30D158);
const _kBlue = Color(0xFF40C8E0);
const _kOrange = Color(0xFFFF9F0A);
const _kRed = Color(0xFFFF453A);
const _kCard = Color(0xFF1C1C1E);
const _kSecondary = Color(0xFF8E8E93);

// ══════════════════════════════════════════════════════════════════════════════
// Workout List Screen
// ══════════════════════════════════════════════════════════════════════════════

class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FitnessProvider>();
    final todayWorkout = p.todayWorkout;
    final recent = p.getRecentWorkouts(days: 21);

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.black,
            surfaceTintColor: Colors.transparent,
            title: const Text('Workout'),
            actions: [
              if (p.workoutStreak > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Row(
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 4),
                      Text(
                        '${p.workoutStreak}',
                        style: const TextStyle(
                          color: _kOrange,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Today done banner ────────────────────────────────────────
                if (todayWorkout != null) ...[
                  _DoneBanner(workout: todayWorkout),
                  const SizedBox(height: 20),
                ],

                // ── Select workout ───────────────────────────────────────────
                const _SectionLabel('START A WORKOUT'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _WorkoutCard(
                        type: WorkoutType.a,
                        onStart: () => _startWorkout(context, WorkoutType.a),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _WorkoutCard(
                        type: WorkoutType.b,
                        onStart: () => _startWorkout(context, WorkoutType.b),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _CustomWorkoutCard(
                  onStart: (exercises) =>
                      _startCustomWorkout(context, exercises),
                ),
                const SizedBox(height: 28),

                // ── Weekly plan tip ──────────────────────────────────────────
                _PlanTip(),
                const SizedBox(height: 28),

                // ── Recent history ───────────────────────────────────────────
                if (recent.isNotEmpty) ...[
                  const _SectionLabel('RECENT WORKOUTS'),
                  const SizedBox(height: 12),
                  ...recent.take(10).map((w) => _HistoryTile(workout: w)),
                ] else ...[
                  _EmptyState(),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _startWorkout(BuildContext context, WorkoutType type) {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _ActiveWorkoutScreen(type: type)),
    );
  }

  void _startCustomWorkout(BuildContext context, List<String> exercises) {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ActiveWorkoutScreen(
          type: WorkoutType.custom,
          customExercises: exercises,
        ),
      ),
    );
  }
}

// ─── Section label ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: _kSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      );
}

// ─── Done banner ───────────────────────────────────────────────────────────────
class _DoneBanner extends StatelessWidget {
  final WorkoutLog workout;
  const _DoneBanner({required this.workout});

  @override
  Widget build(BuildContext context) {
    final isCustom = workout.workoutType == WorkoutType.custom;
    final color = workout.workoutType == WorkoutType.a
        ? _kGreen
        : isCustom
            ? _kOrange
            : _kBlue;
    final label = isCustom
        ? 'Custom Workout complete!'
        : 'Workout ${workout.workoutType.name.toUpperCase()} complete!';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.35), width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: color, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${workout.durationMinutes} min · ${workout.exercises.length} exercises · ${workout.caloriesBurned} kcal',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Workout selection card ────────────────────────────────────────────────────
class _WorkoutCard extends StatelessWidget {
  final WorkoutType type;
  final VoidCallback onStart;
  const _WorkoutCard({required this.type, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final isA = type == WorkoutType.a;
    final color = isA ? _kGreen : _kBlue;
    final exercises = kWorkoutExercises[type]!;
    final p = context.watch<FitnessProvider>();

    // Show PR hint for first exercise
    final pr = p.getPersonalRecord(exercises.first);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isA ? 'A' : 'B',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isA ? 'Push' : 'Pull + Legs',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...exercises.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '· $e',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 12,
                ),
              ),
            ),
          ),
          if (pr != null) ...[
            const SizedBox(height: 6),
            Text(
              'PR: ${pr.toStringAsFixed(pr.truncateToDouble() == pr ? 0 : 1)} kg',
              style: TextStyle(
                color: _kOrange.withOpacity(0.8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onStart,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
                elevation: 0,
              ),
              child: const Text(
                'Start',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Custom workout card ───────────────────────────────────────────────────────

/// All exercises from A + B plus extra options for the picker
const List<String> kAllExercises = [
  'Push-ups', 'Squats', 'Bicep Curls', 'Plank (hold)', 'Tricep Dips',
  'Shoulder Press', 'Bent-over Rows', 'Forearm Curls', 'Lunges', 'Lat Pulldown',
  'Bench Press', 'Deadlift', 'Pull-ups', 'Dips', 'Cable Rows',
  'Incline Press', 'Decline Press', 'Leg Press', 'Romanian Deadlift',
  'Calf Raises', 'Face Pulls', 'Hammer Curls', 'Skull Crushers',
  'Hip Thrust', 'Bulgarian Split Squats', 'Chest Flyes', 'Lateral Raises',
  'Arnold Press', 'Preacher Curls', 'Tricep Pushdown',
];

class _CustomWorkoutCard extends StatelessWidget {
  final void Function(List<String>) onStart;
  const _CustomWorkoutCard({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showExercisePicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFFF9F0A).withOpacity(0.35),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9F0A).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('✏️', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Custom Workout',
                      style: TextStyle(
                          color: Color(0xFFFF9F0A),
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text('Pick your own exercises',
                      style: TextStyle(
                          color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFFF9F0A), size: 20),
          ],
        ),
      ),
    );
  }

  void _showExercisePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ExercisePickerSheet(onConfirm: onStart),
    );
  }
}

class _ExercisePickerSheet extends StatefulWidget {
  final void Function(List<String>) onConfirm;
  const _ExercisePickerSheet({required this.onConfirm});

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  final Set<String> _selected = {};
  final _customCtrl = TextEditingController();
  final List<String> _customAdded = [];

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  void _addCustom() {
    final name = _customCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _customAdded.add(name);
      _selected.add(name);
      _customCtrl.clear();
    });
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final allList = [..._customAdded, ...kAllExercises];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => Column(children: [
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 6),
          width: 40, height: 4,
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(children: [
            const Expanded(
              child: Text('Pick Exercises',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ),
            if (_selected.isNotEmpty)
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  widget.onConfirm(_selected.toList());
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: _kGreen,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                child: Text('Start (${_selected.length})',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
          ]),
        ),
        // Custom exercise input
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _customCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                onSubmitted: (_) => _addCustom(),
                decoration: InputDecoration(
                  hintText: 'Type a custom exercise...',
                  hintStyle:
                      TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.07),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _addCustom,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9F0A),
                  padding: const EdgeInsets.all(12),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: const Icon(Icons.add, color: Colors.white, size: 18),
            ),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            controller: scrollCtrl,
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: allList.length,
            itemBuilder: (_, i) {
              final ex = allList[i];
              final sel = _selected.contains(ex);
              return ListTile(
                leading: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: sel ? _kGreen.withOpacity(0.2) : Colors.white.withOpacity(0.06),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: sel ? _kGreen : Colors.white24, width: 1.5),
                  ),
                  child: sel
                      ? const Icon(Icons.check_rounded, color: _kGreen, size: 16)
                      : null,
                ),
                title: Text(ex,
                    style: TextStyle(
                        color: sel ? _kGreen : Colors.white, fontSize: 14)),
                subtitle: i < _customAdded.length
                    ? Text('custom', style: TextStyle(color: _kOrange.withOpacity(0.7), fontSize: 11))
                    : null,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (sel) _selected.remove(ex);
                    else _selected.add(ex);
                  });
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ─── Plan tip ─────────────────────────────────────────────────────────────────
class _PlanTip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.watch<FitnessProvider>();
    final map = p.weeklyWorkoutMap;
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This Week',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final done = i < map.length ? map[i] : false;
              return Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: done
                          ? _kGreen.withOpacity(0.2)
                          : Colors.white.withOpacity(0.06),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: done ? _kGreen : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: done
                          ? const Icon(Icons.check_rounded,
                              color: _kGreen, size: 16)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    days[i],
                    style: TextStyle(
                      color: done ? _kGreen : _kSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 10),
          Text(
            '${p.weeklyWorkoutDays}/7 days trained · ${p.weeklyCaloriesBurned} kcal burned this week',
            style: const TextStyle(color: _kSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ─── History tile ──────────────────────────────────────────────────────────────
class _HistoryTile extends StatelessWidget {
  final WorkoutLog workout;
  const _HistoryTile({required this.workout});

  @override
  Widget build(BuildContext context) {
    final isCustom = workout.workoutType == WorkoutType.custom;
    final color = workout.workoutType == WorkoutType.a
        ? _kGreen
        : isCustom
            ? _kOrange
            : _kBlue;
    final label = isCustom ? '✏️' : workout.workoutType.name.toUpperCase();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: isCustom ? 16 : 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEE, d MMM').format(workout.date),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  '${workout.durationMinutes} min · ${workout.exercises.length} exercises',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.45), fontSize: 11),
                ),
              ],
            ),
          ),
          if (workout.caloriesBurned > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _kRed.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${workout.caloriesBurned} kcal',
                style: const TextStyle(color: _kRed, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Text('🏋️', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text(
            'No workouts yet',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Start your first workout above.\nConsistency is the key to results.',
            textAlign: TextAlign.center,
            style:
                TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Active Workout Screen — with rest timer + progressive overload
// ══════════════════════════════════════════════════════════════════════════════

class _ActiveWorkoutScreen extends StatefulWidget {
  final WorkoutType type;
  final List<String>? customExercises;
  const _ActiveWorkoutScreen({required this.type, this.customExercises});

  @override
  State<_ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<_ActiveWorkoutScreen>
    with TickerProviderStateMixin {
  late DateTime _startTime;
  late List<_ExerciseEntry> _entries;
  late Timer _elapsedTimer;
  Duration _elapsed = Duration.zero;

  // Rest timer state
  Timer? _restTimer;
  int _restSecondsLeft = 0;
  int _restTotalSeconds = 0;
  bool _restActive = false;
  late AnimationController _restPulseCtrl;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    final provider = context.read<FitnessProvider>();
    final exerciseNames = widget.customExercises ??
        kWorkoutExercises[widget.type] ??
        [];
    _entries = exerciseNames
        .map((name) => _ExerciseEntry(name: name, provider: provider))
        .toList();

    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _elapsed = DateTime.now().difference(_startTime);
        });
      }
    });

    _restPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _elapsedTimer.cancel();
    _restTimer?.cancel();
    _restPulseCtrl.dispose();
    super.dispose();
  }

  String get _elapsedStr {
    final m = _elapsed.inMinutes;
    final s = _elapsed.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _startRest(int seconds) {
    HapticFeedback.mediumImpact();
    _restTimer?.cancel();
    setState(() {
      _restSecondsLeft = seconds;
      _restTotalSeconds = seconds;
      _restActive = true;
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _restSecondsLeft--;
        if (_restSecondsLeft <= 3 && _restSecondsLeft > 0) {
          HapticFeedback.lightImpact();
        }
        if (_restSecondsLeft <= 0) {
          t.cancel();
          _restActive = false;
          HapticFeedback.heavyImpact();
          // Double buzz for rest complete
          Future.delayed(const Duration(milliseconds: 200),
              () => HapticFeedback.heavyImpact());
        }
      });
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    HapticFeedback.selectionClick();
    setState(() {
      _restActive = false;
      _restSecondsLeft = 0;
    });
  }

  Future<void> _saveWorkout() async {
    // Confirm if workout is very short
    final duration = _elapsed.inMinutes;
    if (duration < 2) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _kCard,
          title: const Text('Save workout?',
              style: TextStyle(color: Colors.white)),
          content: Text(
            'Only $duration minute${duration == 1 ? '' : 's'} logged. Save anyway?',
            style: TextStyle(color: Colors.white.withOpacity(0.7)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: _kSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save',
                  style: TextStyle(color: _kGreen)),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    final exercises = _entries.map((e) {
      final sets = e.sets
          .map((s) => SetData(reps: s.reps, weight: s.weight))
          .toList();
      return ExerciseLog(name: e.name, sets: sets);
    }).toList();

    final provider = context.read<FitnessProvider>();
    final weightKg = provider.latestWeightKg ?? 70.0;
    final burned =
        estimateCaloriesBurned(weightKg, duration.clamp(1, 300));

    final log = WorkoutLog(
      id: const Uuid().v4(),
      date: DateTime.now(),
      workoutType: widget.type,
      exercises: exercises,
      durationMinutes: duration,
      caloriesBurned: burned,
    );

    provider.logWorkout(log);
    HapticFeedback.mediumImpact();

    if (mounted) {
      // Get messenger BEFORE pop to avoid detached context
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(
        content: Text('💪 Workout saved! ${duration}min · ${burned} kcal burned'),
        backgroundColor: _kGreen,
        duration: const Duration(seconds: 3),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCustom = widget.type == WorkoutType.custom;
    final color = widget.type == WorkoutType.a
        ? _kGreen
        : isCustom
            ? _kOrange
            : _kBlue;
    final title = isCustom
        ? 'Custom Workout'
        : 'Workout ${widget.type.name.toUpperCase()}';
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: _kCard,
                title: const Text('Discard workout?',
                    style: TextStyle(color: Colors.white)),
                content: Text(
                  'Your progress will be lost.',
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Keep going',
                        style: TextStyle(color: _kGreen)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Discard',
                        style: TextStyle(color: _kRed)),
                  ),
                ],
              ),
            );
            if (confirm == true && mounted) Navigator.pop(context);
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            Text(
              _elapsedStr,
              style: const TextStyle(color: _kSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _saveWorkout,
            child: Text(
              'Finish',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(
                16, 4, 16, _restActive ? 120 + bottom : 32 + bottom),
            children: [
              // Tip banner
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.tips_and_updates_outlined,
                        color: color, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Log each set. Beat last week\'s weight or reps for progressive overload. 💪',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.65),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Exercises
              ..._entries.map((entry) => _ExerciseCard(
                    entry: entry,
                    color: color,
                    onRestRequested: _startRest,
                    onChanged: () => setState(() {}),
                  )),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveWorkout,
                  icon: const Icon(Icons.check_rounded,
                      color: Colors.black),
                  label: const Text(
                    'Finish Workout',
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),

          // ── Rest timer overlay ─────────────────────────────────────────────
          if (_restActive || (_restSecondsLeft > 0))
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _RestTimerBar(
                secondsLeft: _restSecondsLeft,
                totalSeconds: _restTotalSeconds,
                active: _restActive,
                onSkip: _skipRest,
                onAddTime: () => setState(() => _restSecondsLeft += 30),
                onTimerSelect: _startRest,
                pulseCtrl: _restPulseCtrl,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Rest timer bottom bar ──────────────────────────────────────────────────────
class _RestTimerBar extends StatelessWidget {
  final int secondsLeft;
  final int totalSeconds;
  final bool active;
  final VoidCallback onSkip;
  final VoidCallback onAddTime;
  final void Function(int) onTimerSelect;
  final AnimationController pulseCtrl;

  const _RestTimerBar({
    required this.secondsLeft,
    required this.totalSeconds,
    required this.active,
    required this.onSkip,
    required this.onAddTime,
    required this.onTimerSelect,
    required this.pulseCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final progress =
        totalSeconds > 0 ? secondsLeft / totalSeconds : 0.0;
    final bottom = MediaQuery.of(context).padding.bottom;
    final color = secondsLeft <= 5 ? _kGreen : _kOrange;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + bottom),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: color.withOpacity(0.4), width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Timer display
              AnimatedBuilder(
                animation: pulseCtrl,
                builder: (_, __) {
                  final scale = active && secondsLeft <= 5
                      ? 1.0 + pulseCtrl.value * 0.05
                      : 1.0;
                  return Transform.scale(
                    scale: scale,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'REST',
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          _formatSeconds(secondsLeft),
                          style: TextStyle(
                            color: active ? Colors.white : _kSecondary,
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const Spacer(),
              // +30s button
              GestureDetector(
                onTap: onAddTime,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '+30s',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Skip button
              GestureDetector(
                onTap: onSkip,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _kGreen.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _kGreen.withOpacity(0.5), width: 1),
                  ),
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      color: _kGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [30, 60, 90, 120].map((s) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onTimerSelect(s);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${s}s',
                      style: const TextStyle(
                        color: _kSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _formatSeconds(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    if (m > 0) {
      return '${m}:${sec.toString().padLeft(2, '0')}';
    }
    return '${sec}s';
  }
}

// ── Exercise data model ────────────────────────────────────────────────────────
class _SetEntry {
  int reps;
  double weight;
  bool completed;
  _SetEntry({this.reps = 10, this.weight = 0, this.completed = false});
}

class _ExerciseEntry {
  final String name;
  final List<_SetEntry> sets;
  final double? lastWeight;
  final int? lastReps;

  _ExerciseEntry({required this.name, required FitnessProvider provider})
      : lastWeight = provider.getLastExerciseWeight(name),
        lastReps = provider.getLastExerciseReps(name),
        sets = [_SetEntry(), _SetEntry(), _SetEntry()];
}

// ── Exercise card ──────────────────────────────────────────────────────────────
class _ExerciseCard extends StatefulWidget {
  final _ExerciseEntry entry;
  final Color color;
  final void Function(int seconds) onRestRequested;
  final VoidCallback onChanged;

  const _ExerciseCard({
    required this.entry,
    required this.color,
    required this.onRestRequested,
    required this.onChanged,
  });

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  bool _expanded = true;

  int get _completedSets =>
      widget.entry.sets.where((s) => s.completed).length;

  @override
  Widget build(BuildContext context) {
    final allDone = _completedSets == widget.entry.sets.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: allDone
              ? widget.color.withOpacity(0.5)
              : widget.color.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  // Completion circle
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: allDone
                          ? widget.color.withOpacity(0.2)
                          : Colors.white.withOpacity(0.06),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: allDone ? widget.color : Colors.white24,
                        width: 1.5,
                      ),
                    ),
                    child: allDone
                        ? Icon(Icons.check_rounded,
                            color: widget.color, size: 16)
                        : Center(
                            child: Text(
                              '$_completedSets/${widget.entry.sets.length}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 9,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.entry.name,
                          style: TextStyle(
                            color: allDone ? widget.color : Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (widget.entry.lastWeight != null)
                          Text(
                            'Last: ${widget.entry.lastWeight!.toStringAsFixed(widget.entry.lastWeight!.truncateToDouble() == widget.entry.lastWeight ? 0 : 1)} kg'
                            '${widget.entry.lastReps != null ? ' × ${widget.entry.lastReps} reps' : ''}  →  try to beat it!',
                            style: TextStyle(
                              color: _kOrange.withOpacity(0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        else
                          Text(
                            'No previous data — set your baseline!',
                            style: TextStyle(
                              color: _kSecondary.withOpacity(0.7),
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: _kSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          if (_expanded) ...[
            const Divider(
                color: Color(0xFF38383A), thickness: 0.5, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(
                children: [
                  // Column headers
                  Row(
                    children: [
                      const SizedBox(width: 30),
                      Expanded(
                        flex: 2,
                        child: Text('REPS',
                            style: TextStyle(
                                color: _kSecondary,
                                fontSize: 10,
                                letterSpacing: 0.8)),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text('WEIGHT (KG)',
                            style: TextStyle(
                                color: _kSecondary,
                                fontSize: 10,
                                letterSpacing: 0.8)),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Set rows
                  ...widget.entry.sets.asMap().entries.map((e) => _SetRow(
                        setNumber: e.key + 1,
                        setData: e.value,
                        color: widget.color,
                        onComplete: () {
                          setState(() => e.value.completed = !e.value.completed);
                          if (e.value.completed) {
                            HapticFeedback.lightImpact();
                            // Auto-start rest timer after completing set
                            widget.onRestRequested(60);
                          }
                          widget.onChanged();
                        },
                        onChanged: () => setState(() {}),
                      )),

                  // Add set button
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            widget.entry.sets.add(_SetEntry(
                              reps: widget.entry.sets.last.reps,
                              weight: widget.entry.sets.last.weight,
                            ));
                          });
                          HapticFeedback.selectionClick();
                          widget.onChanged();
                        },
                        icon: Icon(Icons.add_circle_outline,
                            size: 15, color: widget.color),
                        label: Text('Add set',
                            style: TextStyle(
                                color: widget.color, fontSize: 12)),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const Spacer(),
                      // Rest timer quick buttons
                      ...[30, 60, 90].map((s) => Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: GestureDetector(
                              onTap: () => widget.onRestRequested(s),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.white.withOpacity(0.07),
                                  borderRadius:
                                      BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${s}s',
                                  style: const TextStyle(
                                    color: _kSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          )),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Set row ────────────────────────────────────────────────────────────────────
class _SetRow extends StatelessWidget {
  final int setNumber;
  final _SetEntry setData;
  final Color color;
  final VoidCallback onComplete;
  final VoidCallback onChanged;

  const _SetRow({
    required this.setNumber,
    required this.setData,
    required this.color,
    required this.onComplete,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Set number
          SizedBox(
            width: 20,
            child: Text(
              '$setNumber',
              style: TextStyle(
                color: setData.completed ? color : _kSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Reps stepper
          Expanded(
            flex: 2,
            child: _RepsStepper(
              value: setData.reps,
              color: color,
              completed: setData.completed,
              onChanged: (v) {
                setData.reps = v;
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),

          // Weight field
          Expanded(
            flex: 3,
            child: _WeightField(
              value: setData.weight,
              color: color,
              completed: setData.completed,
              onChanged: (v) {
                setData.weight = v;
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),

          // Complete toggle
          GestureDetector(
            onTap: onComplete,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: setData.completed
                    ? color.withOpacity(0.2)
                    : Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
                border: Border.all(
                  color: setData.completed ? color : Colors.white24,
                  width: 1.5,
                ),
              ),
              child: setData.completed
                  ? Icon(Icons.check_rounded, color: color, size: 16)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reps stepper ───────────────────────────────────────────────────────────────
class _RepsStepper extends StatelessWidget {
  final int value;
  final Color color;
  final bool completed;
  final ValueChanged<int> onChanged;

  const _RepsStepper({
    required this.value,
    required this.color,
    required this.completed,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StepBtn(
          icon: Icons.remove,
          color: color,
          onTap: value > 1 ? () => onChanged(value - 1) : null,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: completed ? color : Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 6),
        _StepBtn(
          icon: Icons.add,
          color: color,
          onTap: value < 99 ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _StepBtn({required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: onTap != null ? color.withOpacity(0.15) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 14,
          color: onTap != null ? color : Colors.white24,
        ),
      ),
    );
  }
}

// ── Weight text field ──────────────────────────────────────────────────────────
class _WeightField extends StatefulWidget {
  final double value;
  final Color color;
  final bool completed;
  final ValueChanged<double> onChanged;

  const _WeightField({
    required this.value,
    required this.color,
    required this.completed,
    required this.onChanged,
  });

  @override
  State<_WeightField> createState() => _WeightFieldState();
}

class _WeightFieldState extends State<_WeightField> {
  late TextEditingController _ctrl;
  late FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.value == 0 ? '' : widget.value.toStringAsFixed(
              widget.value.truncateToDouble() == widget.value ? 0 : 1,
            ));
    _focus = FocusNode();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      focusNode: _focus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(
        color: widget.completed ? widget.color : Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      onChanged: (v) {
        if (v.trim().isEmpty) {
          widget.onChanged(0);
          return;
        }
        final parsed = double.tryParse(v);
        if (parsed != null && parsed >= 0 && parsed <= 500) {
          widget.onChanged(parsed);
        }
      },
      decoration: InputDecoration(
        hintText: 'kg',
        hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.2), fontSize: 13),
        filled: true,
        fillColor: widget.completed
            ? widget.color.withOpacity(0.08)
            : Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              BorderSide(color: widget.color.withOpacity(0.5), width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 8),
        isDense: true,
        suffixText: 'kg',
        suffixStyle: TextStyle(
            color: Colors.white.withOpacity(0.3), fontSize: 11),
      ),
    );
  }
}
