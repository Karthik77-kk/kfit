import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../providers/fitness_provider.dart';
import '../models/models.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kGreen = Color(0xFF30D158);
const _kBlue = Color(0xFF40C8E0);
const _kRed = Color(0xFFFF453A);
const _kOrange = Color(0xFFFF9F0A);
const _kCard = Color(0xFF1C1C1E);
const _kSecondary = Color(0xFF8E8E93);

// ══════════════════════════════════════════════════════════════════════════════
// Workout overview screen
// ══════════════════════════════════════════════════════════════════════════════

class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FitnessProvider>();
    final todayWorkout = p.todayWorkout;
    final recent = p.getRecentWorkouts();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Workout Logger 🏋️',
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 20,
              letterSpacing: -0.5),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          16 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          if (todayWorkout != null) ...[
            _DoneCard(workout: todayWorkout),
            const SizedBox(height: 16),
          ],

          // Workout selector
          const Text(
            'START A WORKOUT',
            style: TextStyle(
                color: _kSecondary, fontSize: 11, fontWeight: FontWeight.w600,
                letterSpacing: 1.2),
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

          if (recent.isNotEmpty) ...[
            const Text(
              'RECENT HISTORY',
              style: TextStyle(
                  color: _kSecondary, fontSize: 11, fontWeight: FontWeight.w600,
                  letterSpacing: 1.2),
            ),
            const SizedBox(height: 10),
            ...recent.take(7).map((w) => _WorkoutHistoryTile(workout: w)),
          ] else
            _TipCard(),
        ],
      ),
    );
  }

  void _startWorkout(BuildContext context, WorkoutType type) {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ActiveWorkoutScreen(type: type),
      ),
    );
  }
}

// ── Done card ──────────────────────────────────────────────────────────────────
class _DoneCard extends StatelessWidget {
  final WorkoutLog workout;
  const _DoneCard({required this.workout});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kGreen.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kGreen.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Text('✅', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Workout ${workout.workoutType.name.toUpperCase()} done!',
                style: const TextStyle(
                    color: _kGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
              ),
              Text(
                '${workout.durationMinutes} min · ${workout.exercises.length} exercises',
                style: const TextStyle(color: _kSecondary, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Workout type card ──────────────────────────────────────────────────────────
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
    final color = type == WorkoutType.a ? _kGreen : _kBlue;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          ...exercises.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $e',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.7), fontSize: 12)),
              )),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onStart,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text('Start',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.black)),
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
    final color =
        workout.workoutType == WorkoutType.a ? _kGreen : _kBlue;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
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
                  '${workout.durationMinutes} min · ${workout.exercises.length} exercises · ${workout.caloriesBurned} kcal',
                  style: const TextStyle(color: _kSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: _kGreen, size: 18),
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
        color: _kGreen.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kGreen.withOpacity(0.2)),
      ),
      child: const Text(
        '💡 Start Workout A on Monday, B on Wednesday, A on Friday. Alternate weekly for best results. Add reps or weight each session for progressive overload!',
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

class _ActiveWorkoutScreenState extends State<_ActiveWorkoutScreen>
    with SingleTickerProviderStateMixin {
  late DateTime _startTime;
  late List<_ExerciseEntry> _entries;
  late Timer _elapsedTimer;
  int _elapsedSeconds = 0;

  // Rest timer
  int _restRemaining = 0;
  int _restTotal = 0;
  Timer? _restTimer;
  late AnimationController _restPulseCtrl;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();

    // Build exercise entries with progressive overload hints from provider
    final provider = context.read<FitnessProvider>();
    _entries = kWorkoutExercises[widget.type]!.map((name) {
      final lastWeight = provider.getLastExerciseWeight(name);
      final lastReps = provider.getLastExerciseReps(name);
      return _ExerciseEntry(
          name: name, lastWeight: lastWeight, lastReps: lastReps);
    }).toList();

    // Elapsed timer
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });

    // Pulse animation for rest timer
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

  String get _elapsedFormatted {
    final m = _elapsedSeconds ~/ 60;
    final s = _elapsedSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _startRest(int seconds) {
    HapticFeedback.lightImpact();
    _restTimer?.cancel();
    setState(() {
      _restRemaining = seconds;
      _restTotal = seconds;
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _restRemaining--;
        if (_restRemaining <= 0) {
          _restRemaining = 0;
          _restTotal = 0;
          t.cancel();
          HapticFeedback.heavyImpact();
        }
      });
    });
  }

  void _saveWorkout(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final duration = DateTime.now().difference(_startTime).inMinutes;
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
    navigator.pop();
    messenger.showSnackBar(const SnackBar(
      content: Text('🏋️ Workout saved! Great work!'),
      backgroundColor: _kGreen,
      duration: Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.type == WorkoutType.a ? _kGreen : _kBlue;
    final isResting = _restRemaining > 0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Workout ${widget.type.name.toUpperCase()} · $_elapsedFormatted',
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 17,
              letterSpacing: -0.3),
        ),
        actions: [
          TextButton(
            onPressed: () => _saveWorkout(context),
            child: Text(
              'Done ✓',
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Rest timer bar
          if (isResting)
            _RestTimerBar(
              remaining: _restRemaining,
              total: _restTotal,
              pulseCtrl: _restPulseCtrl,
              onSkip: () {
                _restTimer?.cancel();
                setState(() {
                  _restRemaining = 0;
                  _restTotal = 0;
                });
              },
              onAddTime: () => setState(() => _restRemaining += 15),
              onTimerSelect: _startRest,
            ),

          // Exercise list
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                  16, 12, 16, 16 + MediaQuery.of(context).padding.bottom),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: color.withOpacity(0.2)),
                  ),
                  child: Text(
                    '💡 Log each set. Tap ✓ to mark complete & start rest timer. Beat your last session!',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),
                ..._entries.map((entry) => _ExerciseCard(
                      entry: entry,
                      color: color,
                      onSetCompleted: (secs) => _startRest(secs),
                      onChanged: () => setState(() {}),
                    )),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _saveWorkout(context),
                  icon: const Icon(Icons.save_alt, color: Colors.black),
                  label: const Text('Save Workout',
                      style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
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

// ── Rest timer bar ─────────────────────────────────────────────────────────────
class _RestTimerBar extends StatelessWidget {
  final int remaining;
  final int total;
  final AnimationController pulseCtrl;
  final VoidCallback onSkip;
  final VoidCallback onAddTime;
  final void Function(int) onTimerSelect;

  const _RestTimerBar({
    required this.remaining,
    required this.total,
    required this.pulseCtrl,
    required this.onSkip,
    required this.onAddTime,
    required this.onTimerSelect,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? remaining / total : 0.0;

    return Container(
      color: _kCard,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: pulseCtrl,
                builder: (_, __) => Text(
                  '😮‍💨 REST',
                  style: TextStyle(
                    color: Color.lerp(_kBlue, Colors.white, pulseCtrl.value),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${remaining}s',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              _TimerChip(label: '+15s', onTap: onAddTime),
              const SizedBox(width: 6),
              _TimerChip(
                  label: '60s',
                  onTap: () => onTimerSelect(60)),
              const SizedBox(width: 6),
              _TimerChip(
                  label: '90s',
                  onTap: () => onTimerSelect(90)),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onSkip,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _kRed.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Skip',
                      style: TextStyle(
                          color: _kRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(_kBlue),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimerChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _TimerChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _kBlue.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: const TextStyle(
                color: _kBlue, fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ── Exercise data ──────────────────────────────────────────────────────────────
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

  _ExerciseEntry({
    required this.name,
    required this.lastWeight,
    required this.lastReps,
  }) : sets = [_SetEntry(), _SetEntry(), _SetEntry()];
}

// ── Exercise card ──────────────────────────────────────────────────────────────
class _ExerciseCard extends StatefulWidget {
  final _ExerciseEntry entry;
  final Color color;
  final void Function(int seconds) onSetCompleted;
  final VoidCallback onChanged;

  const _ExerciseCard({
    required this.entry,
    required this.color,
    required this.onSetCompleted,
    required this.onChanged,
  });

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  @override
  Widget build(BuildContext context) {
    final hasHistory =
        widget.entry.lastWeight != null || widget.entry.lastReps != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: widget.color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.entry.name,
                  style: TextStyle(
                    color: widget.color,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (hasHistory)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Last: ${widget.entry.lastWeight?.toStringAsFixed(1) ?? '—'}kg × ${widget.entry.lastReps ?? '—'}',
                    style: const TextStyle(
                        color: _kSecondary, fontSize: 10),
                  ),
                ),
            ],
          ),
          if (hasHistory)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 2),
              child: Text(
                '🎯 Beat it — try adding weight or a rep!',
                style: TextStyle(
                    color: widget.color.withOpacity(0.7), fontSize: 11),
              ),
            ),
          const SizedBox(height: 10),
          // Header
          Row(
            children: [
              const SizedBox(width: 26),
              const Expanded(
                  child: Text('Set',
                      style: TextStyle(
                          color: _kSecondary,
                          fontSize: 11))),
              const SizedBox(
                  width: 80,
                  child: Text('Weight (kg)',
                      style: TextStyle(
                          color: _kSecondary, fontSize: 11),
                      textAlign: TextAlign.center)),
              const SizedBox(
                  width: 60,
                  child: Text('Reps',
                      style: TextStyle(
                          color: _kSecondary, fontSize: 11),
                      textAlign: TextAlign.center)),
              const SizedBox(width: 40),
            ],
          ),
          const SizedBox(height: 6),
          ...List.generate(widget.entry.sets.length, (i) {
            final s = widget.entry.sets[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  // Set number
                  SizedBox(
                    width: 26,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                          color: _kSecondary, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Weight field
                  SizedBox(
                    width: 80,
                    child: _WeightField(
                      value: s.weight,
                      completed: s.completed,
                      hint: widget.entry.lastWeight
                              ?.toStringAsFixed(1) ??
                          '0',
                      onChanged: (v) {
                        setState(() => s.weight = v);
                        widget.onChanged();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Reps field
                  SizedBox(
                    width: 60,
                    child: _RepsField(
                      value: s.reps,
                      completed: s.completed,
                      hint: widget.entry.lastReps?.toString() ?? '10',
                      onChanged: (v) {
                        setState(() => s.reps = v);
                        widget.onChanged();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Complete button
                  SizedBox(
                    width: 32,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => s.completed = !s.completed);
                        widget.onChanged();
                        if (!s.completed) return;
                        // Auto-start 60s rest after completing a set
                        widget.onSetCompleted(60);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: s.completed
                              ? _kGreen
                              : Colors.white.withOpacity(0.07),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: s.completed
                                ? _kGreen
                                : Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: Icon(
                          s.completed
                              ? Icons.check
                              : Icons.radio_button_unchecked,
                          size: 16,
                          color: s.completed
                              ? Colors.black
                              : Colors.white.withOpacity(0.3),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Weight input field ─────────────────────────────────────────────────────────
class _WeightField extends StatefulWidget {
  final double value;
  final bool completed;
  final String hint;
  final void Function(double) onChanged;

  const _WeightField({
    required this.value,
    required this.completed,
    required this.hint,
    required this.onChanged,
  });

  @override
  State<_WeightField> createState() => _WeightFieldState();
}

class _WeightFieldState extends State<_WeightField> {
  late final TextEditingController _ctrl;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.value > 0 ? widget.value.toStringAsFixed(1) : '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _hasFocus = f),
      child: TextField(
        controller: _ctrl,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.next,
        textAlign: TextAlign.center,
        readOnly: widget.completed,
        style: TextStyle(
          color: widget.completed ? _kGreen : Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle:
              const TextStyle(color: _kSecondary, fontSize: 13),
          filled: true,
          fillColor: widget.completed
              ? _kGreen.withOpacity(0.1)
              : _hasFocus
                  ? Colors.white.withOpacity(0.1)
                  : Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
              vertical: 8, horizontal: 6),
          isDense: true,
        ),
        onChanged: (v) {
          if (v.trim().isEmpty) {
            widget.onChanged(0);
            return;
          }
          final parsed = double.tryParse(v);
          if (parsed != null) widget.onChanged(parsed);
        },
      ),
    );
  }
}

// ── Reps input field ───────────────────────────────────────────────────────────
class _RepsField extends StatefulWidget {
  final int value;
  final bool completed;
  final String hint;
  final void Function(int) onChanged;

  const _RepsField({
    required this.value,
    required this.completed,
    required this.hint,
    required this.onChanged,
  });

  @override
  State<_RepsField> createState() => _RepsFieldState();
}

class _RepsFieldState extends State<_RepsField> {
  late final TextEditingController _ctrl;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.value > 0 ? widget.value.toString() : '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _hasFocus = f),
      child: TextField(
        controller: _ctrl,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
        textAlign: TextAlign.center,
        readOnly: widget.completed,
        style: TextStyle(
          color: widget.completed ? _kGreen : Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle:
              const TextStyle(color: _kSecondary, fontSize: 13),
          filled: true,
          fillColor: widget.completed
              ? _kGreen.withOpacity(0.1)
              : _hasFocus
                  ? Colors.white.withOpacity(0.1)
                  : Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
              vertical: 8, horizontal: 6),
          isDense: true,
        ),
        onChanged: (v) {
          if (v.trim().isEmpty) {
            widget.onChanged(0);
            return;
          }
          final parsed = int.tryParse(v);
          if (parsed != null) widget.onChanged(parsed);
        },
      ),
    );
  }
}
