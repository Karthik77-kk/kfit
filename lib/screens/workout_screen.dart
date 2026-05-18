import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../providers/fitness_provider.dart';
import '../models/models.dart';

class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FitnessProvider>();
    final todayWorkout = p.todayWorkout;
    final recent = p.getRecentWorkouts();

    return Scaffold(
      appBar: AppBar(title: const Text('Workout Logger 🏋️')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Today's status ────────────────────────────────────────────────
          if (todayWorkout != null) ...[
            _DoneCard(workout: todayWorkout),
            const SizedBox(height: 16),
          ],

          // ── Workout selector ──────────────────────────────────────────────
          const Text(
            'Start a workout',
            style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _WorkoutTypeCard(
                  type: WorkoutType.a,
                  exercises: kWorkoutExercises[WorkoutType.a]!,
                  onStart: () => _startWorkout(context, WorkoutType.a),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _WorkoutTypeCard(
                  type: WorkoutType.b,
                  exercises: kWorkoutExercises[WorkoutType.b]!,
                  onStart: () => _startWorkout(context, WorkoutType.b),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Recent history ────────────────────────────────────────────────
          if (recent.isNotEmpty) ...[
            const Text(
              'Recent Workouts',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ...recent.take(7).map((w) => _WorkoutHistoryTile(workout: w)),
          ] else ...[
            const SizedBox(height: 12),
            _TipCard(),
          ],
        ],
      ),
    );
  }

  void _startWorkout(BuildContext context, WorkoutType type) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ActiveWorkoutScreen(type: type),
      ),
    );
  }
}

// ── Done card (today's workout already logged) ─────────────────────────────────

class _DoneCard extends StatelessWidget {
  final WorkoutLog workout;
  const _DoneCard({required this.workout});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF30D158).withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF30D158).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Text('✅', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Workout ${workout.workoutType.name.toUpperCase()} done today!',
                style: const TextStyle(
                    color: Color(0xFF30D158),
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
              ),
              Text(
                '${workout.durationMinutes} min · ${workout.exercises.length} exercises',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.5), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Workout type selection card ────────────────────────────────────────────────

class _WorkoutTypeCard extends StatelessWidget {
  final WorkoutType type;
  final List<String> exercises;
  final VoidCallback onStart;

  const _WorkoutTypeCard({
    required this.type,
    required this.exercises,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final label = 'Workout ${type.name.toUpperCase()}';
    final color = type == WorkoutType.a
        ? const Color(0xFF30D158)
        : const Color(0xFF40C8E0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          ...exercises.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• $e',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.7), fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onStart,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text('Start', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── History tile ───────────────────────────────────────────────────────────────

class _WorkoutHistoryTile extends StatelessWidget {
  final WorkoutLog workout;
  const _WorkoutHistoryTile({required this.workout});

  @override
  Widget build(BuildContext context) {
    final color = workout.workoutType == WorkoutType.a
        ? const Color(0xFF30D158)
        : const Color(0xFF40C8E0);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.white.withOpacity(0.06), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              workout.workoutType.name.toUpperCase(),
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEE, d MMM').format(workout.date),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                Text(
                  '${workout.durationMinutes} min · ${workout.exercises.length} exercises',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.45), fontSize: 11),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle,
              color: Color(0xFF30D158), size: 18),
        ],
      ),
    );
  }
}

// ── Tip card ───────────────────────────────────────────────────────────────────

class _TipCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF30D158).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        '💡 Start with Workout A on Monday, Workout B on Wednesday, A on Friday — alternate weekly for best results. Add reps or weight each week!',
        style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Active workout screen
// ══════════════════════════════════════════════════════════════════════════════

class _ActiveWorkoutScreen extends StatefulWidget {
  final WorkoutType type;
  const _ActiveWorkoutScreen({required this.type});

  @override
  State<_ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<_ActiveWorkoutScreen> {
  late DateTime _startTime;
  late List<_ExerciseEntry> _entries;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _entries = kWorkoutExercises[widget.type]!
        .map((name) => _ExerciseEntry(name: name))
        .toList();
  }

  void _saveWorkout(BuildContext context) {
    final duration = DateTime.now().difference(_startTime).inMinutes;
    final exercises = _entries.map((e) {
      final sets = e.sets
          .map((s) => SetData(
                reps: s.reps,
                weight: s.weight,
              ))
          .toList();
      return ExerciseLog(name: e.name, sets: sets);
    }).toList();

    final provider = context.read<FitnessProvider>();
    final weightKg = provider.latestWeightKg ?? 70.0;
    final burned = estimateCaloriesBurned(weightKg, duration.clamp(1, 300));

    final log = WorkoutLog(
      id: const Uuid().v4(),
      date: DateTime.now(),
      workoutType: widget.type,
      exercises: exercises,
      durationMinutes: duration,
      caloriesBurned: burned,
    );

    provider.logWorkout(log);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('🏋️ Workout saved! Great work!'),
      backgroundColor: Color(0xFF30D158),
      duration: Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.type == WorkoutType.a
        ? const Color(0xFF30D158)
        : const Color(0xFF40C8E0);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Workout ${widget.type.name.toUpperCase()} 💪'),
        actions: [
          TextButton(
            onPressed: () => _saveWorkout(context),
            child: Text('Done', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Log your sets below. Aim for 3 sets per exercise. Progressive overload = add reps or weight each week!',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.7), fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
          ..._entries.map((entry) => _ExerciseCard(
                entry: entry,
                color: color,
                onChanged: () => setState(() {}),
              )),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _saveWorkout(context),
            icon: const Icon(Icons.save_alt, color: Colors.white),
            label: const Text('Save Workout',
                style: TextStyle(color: Colors.white, fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF30D158),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Exercise data holder ───────────────────────────────────────────────────────

class _SetEntry {
  int reps;
  double weight;
  _SetEntry({this.reps = 10, this.weight = 0});
}

class _ExerciseEntry {
  final String name;
  final List<_SetEntry> sets;
  _ExerciseEntry({required this.name})
      : sets = [_SetEntry(), _SetEntry(), _SetEntry()];
}

// ── Exercise card ──────────────────────────────────────────────────────────────

class _ExerciseCard extends StatefulWidget {
  final _ExerciseEntry entry;
  final Color color;
  final VoidCallback onChanged;

  const _ExerciseCard({
    required this.entry,
    required this.color,
    required this.onChanged,
  });

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: widget.color.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.entry.name,
            style: TextStyle(
              color: widget.color,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 32,
                child: Text('Set',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11)),
              ),
              Expanded(
                child: Text('Reps',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11)),
              ),
              Expanded(
                child: Text('Weight (kg)',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...widget.entry.sets.asMap().entries.map(
                (e) => _SetRow(
                  setNumber: e.key + 1,
                  setData: e.value,
                  color: widget.color,
                  onChanged: () => setState(() {}),
                ),
              ),
          TextButton.icon(
            onPressed: () {
              setState(() {
                widget.entry.sets.add(_SetEntry());
              });
              widget.onChanged();
            },
            icon: Icon(Icons.add, size: 15, color: widget.color),
            label: Text('Add set',
                style: TextStyle(color: widget.color, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  final int setNumber;
  final _SetEntry setData;
  final Color color;
  final VoidCallback onChanged;

  const _SetRow({
    required this.setNumber,
    required this.setData,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text('$setNumber',
                style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
          Expanded(
            child: _InlineNumber(
              value: setData.reps,
              min: 1,
              max: 100,
              color: color,
              onChanged: (v) {
                setData.reps = v;
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _WeightField(
              value: setData.weight,
              color: color,
              onChanged: (v) {
                setData.weight = v;
                onChanged();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineNumber extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final Color color;
  final ValueChanged<int> onChanged;

  const _InlineNumber({
    required this.value,
    required this.min,
    required this.max,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SmallBtn(
          icon: Icons.remove,
          color: color,
          onTap: value > min ? () => onChanged(value - 1) : null,
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 30,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 4),
        _SmallBtn(
          icon: Icons.add,
          color: color,
          onTap: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _SmallBtn({required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: onTap != null ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon,
            size: 14,
            color: onTap != null ? color : Colors.white24),
      ),
    );
  }
}

class _WeightField extends StatefulWidget {
  final double value;
  final Color color;
  final ValueChanged<double> onChanged;

  const _WeightField(
      {required this.value, required this.color, required this.onChanged});

  @override
  State<_WeightField> createState() => _WeightFieldState();
}

class _WeightFieldState extends State<_WeightField> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.value == 0 ? '' : widget.value.toString());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: Colors.white, fontSize: 14),
      onChanged: (v) {
        final parsed = double.tryParse(v) ?? 0;
        widget.onChanged(parsed);
      },
      decoration: InputDecoration(
        hintText: '0',
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 13),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        suffixText: 'kg',
        suffixStyle:
            TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11),
      ),
    );
  }
}
