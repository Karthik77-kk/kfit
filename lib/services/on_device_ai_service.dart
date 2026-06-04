import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/fitness_provider.dart';

enum AiModelState { notInstalled, downloading, loading, ready, error }

/// Metadata for a downloadable on-device LLM.
class AiModelConfig {
  final String id;
  final String name;
  final String sizeLabel;
  final String qualityBadge;   // e.g. "Fast", "Best", "Alternative"
  final String description;
  final String url;
  final ModelType modelType;
  final ModelFileType fileType;
  final int maxTokens;          // KV-cache size for this model

  const AiModelConfig({
    required this.id,
    required this.name,
    required this.sizeLabel,
    required this.qualityBadge,
    required this.description,
    required this.url,
    required this.modelType,
    required this.fileType,
    required this.maxTokens,
  });
}

class OnDeviceAiService extends ChangeNotifier {
  // ── Enterprise token (never shown to user) ──────────────────────────────────
  static const _enterpriseToken = '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';
  static const _prefToken          = 'hf_token_ai_chat';
  static const _prefActiveModelId  = 'ai_active_model_id';
  static const _prefInstalledModel = 'ai_installed_model_id';

  // ── Available models ────────────────────────────────────────────────────────
  static const List<AiModelConfig> availableModels = [
    AiModelConfig(
      id: 'gemma3_1b',
      name: 'Gemma 3 1B',
      sizeLabel: '~600 MB',
      qualityBadge: 'Fast',
      description: 'Lightweight · runs on any device',
      url: 'https://huggingface.co/litert-community/Gemma3-1B-IT'
          '/resolve/main/gemma3-1b-it-int4.litertlm',
      modelType: ModelType.gemmaIt,
      fileType: ModelFileType.litertlm,
      maxTokens: 2048,
    ),
    AiModelConfig(
      id: 'gemma4_e4b',
      name: 'Gemma 4 E4B',
      sizeLabel: '~3.7 GB',
      qualityBadge: 'Best',
      description: 'Recommended · MoE · much smarter · needs WiFi + 4 GB free',
      url: 'https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm'
          '/resolve/main/gemma-4-E4B-it.litertlm',
      modelType: ModelType.gemma4,
      fileType: ModelFileType.litertlm,
      maxTokens: 4096,
    ),
    AiModelConfig(
      id: 'qwen25_1b5',
      name: 'Qwen 2.5 1.5B',
      sizeLabel: '~1.6 GB',
      qualityBadge: 'Alternative',
      description: "Alibaba's model · good reasoning · multilingual",
      url: 'https://huggingface.co/litert-community/Qwen2.5-1.5B-Instruct'
          '/resolve/main/Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv4096.litertlm',
      modelType: ModelType.qwen,
      fileType: ModelFileType.litertlm,
      maxTokens: 4096,
    ),
  ];

  // ── State ───────────────────────────────────────────────────────────────────
  AiModelState _state      = AiModelState.notInstalled;
  double       _dlProgress = 0.0;
  String       _error      = '';
  String       _hfToken    = '';
  String       _activeModelId  = 'gemma3_1b';  // user's selected model
  String       _installedModelId = '';          // what's actually on device

  InferenceModel? _model;
  InferenceChat?  _chat;

  // ── Getters ─────────────────────────────────────────────────────────────────
  AiModelState get state          => _state;
  double       get dlProgress     => _dlProgress;
  String       get errorMessage   => _error;
  String       get hfToken        => _hfToken;
  bool         get isReady        => _state == AiModelState.ready;
  bool         get hasToken       => _hfToken.isNotEmpty;
  String       get activeModelId  => _activeModelId;
  String       get installedModelId => _installedModelId;

  AiModelConfig get activeConfig =>
      availableModels.firstWhere((m) => m.id == _activeModelId,
          orElse: () => availableModels.first);

  bool isModelInstalled(String id) => _installedModelId == id;

  // ── Init ────────────────────────────────────────────────────────────────────
  Future<void> init() async {
    await saveToken(_enterpriseToken);
    final prefs = await SharedPreferences.getInstance();
    _activeModelId   = prefs.getString(_prefActiveModelId)  ?? 'gemma3_1b';
    _installedModelId = prefs.getString(_prefInstalledModel) ?? '';

    try {
      await FlutterGemma.initialize(huggingFaceToken: _enterpriseToken);
      if (_installedModelId == _activeModelId && FlutterGemma.hasActiveModel()) {
        await _loadModel();
      } else {
        _setState(AiModelState.notInstalled);
      }
    } catch (e) {
      _setState(AiModelState.notInstalled);
    }
  }

  Future<void> saveToken(String token) async {
    _hfToken = token.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefToken, _hfToken);
    notifyListeners();
  }

  // ── Model selection ─────────────────────────────────────────────────────────
  /// Select a model as the desired active model. If the model is already
  /// installed on device, loads it immediately. Otherwise the UI should
  /// show a download button.
  Future<void> selectModel(String modelId) async {
    if (!availableModels.any((m) => m.id == modelId)) return;
    _activeModelId = modelId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefActiveModelId, modelId);
    notifyListeners();

    if (_installedModelId == modelId && FlutterGemma.hasActiveModel()) {
      _model = null;
      _chat  = null;
      await _loadModel();
    } else {
      _model = null;
      _chat  = null;
      _setState(AiModelState.notInstalled);
    }
  }

  // ── Download ─────────────────────────────────────────────────────────────────
  Future<void> downloadAndLoad() async {
    final cfg = activeConfig;
    try {
      _dlProgress = 0;
      _setState(AiModelState.downloading);

      await FlutterGemma.initialize(huggingFaceToken: _enterpriseToken);
      await FlutterGemma.installModel(
        modelType: cfg.modelType,
        fileType:  cfg.fileType,
      )
          .fromNetwork(cfg.url, token: _enterpriseToken)
          .withProgress((pct) {
            _dlProgress = (pct / 100.0).clamp(0.0, 1.0);
            notifyListeners();
          })
          .install();

      // Record what we installed
      _installedModelId = cfg.id;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefInstalledModel, cfg.id);

      await _loadModel();
    } catch (e) {
      final msg = e.toString();
      _setState(AiModelState.error,
          error: msg.length > 200 ? '${msg.substring(0, 200)}…' : msg);
    }
  }

  Future<void> _loadModel() async {
    _setState(AiModelState.loading);
    try {
      _model = await FlutterGemma.getActiveModel(
        maxTokens:        activeConfig.maxTokens,
        preferredBackend: PreferredBackend.npu,
      );
      _setState(AiModelState.ready);
    } catch (e) {
      _setState(AiModelState.error, error: 'Failed to load model: $e');
    }
  }

  void resetConversation() {
    _chat = null;
    notifyListeners();
  }

  // ── Chat ────────────────────────────────────────────────────────────────────
  Stream<String> sendMessage(String userMessage, FitnessProvider provider) async* {
    if (_model == null) {
      yield 'Model not loaded. Reopen the chat to retry.';
      return;
    }
    try {
      _chat ??= await _model!.createChat(
        systemInstruction: _systemPrompt(provider),
        temperature:  0.7,
        topK:         40,
        randomSeed:   42,
        tokenBuffer:  256,
      );
      await _chat!.addQueryChunk(Message(text: userMessage, isUser: true));
      await for (final r in _chat!.generateChatResponseAsync()) {
        if (r is TextResponse) yield r.token;
      }
    } catch (e) {
      yield '\n\n[Error: $e]';
    }
  }

  // ── System prompt ────────────────────────────────────────────────────────────
  String _systemPrompt(FitnessProvider p) {
    final now    = DateTime.now();
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    String fmt(DateTime d) => '${d.day} ${months[d.month-1]}';

    final weight  = p.latestWeightKg?.toStringAsFixed(1) ?? 'not logged';
    final trend   = p.weeklyWeightChange != null
        ? '${p.weeklyWeightChange!.toStringAsFixed(2)} kg/wk'
        : 'no data';
    final eta     = p.estimatedGoalDate != null
        ? '${fmt(p.estimatedGoalDate!)} ${p.estimatedGoalDate!.year}'
        : 'N/A';
    final kgLeft  = p.kgToGoal?.toStringAsFixed(1) ?? 'N/A';
    final tdee    = p.bestTdee != null
        ? '${p.bestTdee!.round()} kcal${p.isTdeeCalibrated ? " (calibrated)" : " (est)"}'
        : 'N/A';
    final cut     = p.fatLossCalorieTarget?.round().toString() ?? 'N/A';

    final buf = StringBuffer();

    // ── GOALS ──────────────────────────────────────────────────────────────
    buf.writeln('\nGOALS');
    buf.writeln('Calories: ${p.calorieGoal} kcal · Protein: ${p.proteinGoal}g · Water: ${p.waterGoalMl}ml · Steps: ${p.stepGoal}');

    // ── BODY COMPOSITION ──────────────────────────────────────────────────
    buf.writeln('\nBODY COMPOSITION');
    if (p.bmi != null) buf.writeln('BMI: ${p.bmi!.toStringAsFixed(1)} (${p.bmiCategory})');
    final scale = p.latestScaleEntry;
    if (scale != null) {
      buf.writeln('Body fat: ${scale.bodyFatPercent.toStringAsFixed(1)}% (${scale.bodyFatKg.toStringAsFixed(1)}kg)');
      buf.writeln('Lean mass: ${scale.leanBodyMassKg.toStringAsFixed(1)}kg  Muscle: ${scale.muscleMassKg.toStringAsFixed(1)}kg');
      buf.writeln('Visceral fat index: ${scale.visceralFatIndex}  Bone mass: ${scale.boneMassKg.toStringAsFixed(2)}kg');
      buf.writeln('Body water: ${scale.bodyWaterPercent.toStringAsFixed(1)}%  Protein%: ${scale.proteinPercent.toStringAsFixed(1)}%');
      final bioDelta = p.bioAgeDelta;
      if (bioDelta != null) {
        buf.writeln('Bio age: ${scale.biologicalAge} (${bioDelta == 0 ? "same as real age" : bioDelta < 0 ? "${bioDelta.abs()}y younger than real age" : "${bioDelta}y older than real age"})');
      }
    }
    if (p.ffmi != null) buf.writeln('FFMI: ${p.ffmi!.toStringAsFixed(1)} (${p.ffmiStatus.label})');
    if (p.waistToHipRatio != null) buf.writeln('Waist:Hip: ${p.waistToHipRatio!.toStringAsFixed(2)} (${p.whrRisk?.label ?? "N/A"})');
    if (p.waistToHeightRatio != null) buf.writeln('Waist:Height: ${p.waistToHeightRatio!.toStringAsFixed(2)} (${p.whtrStatus.label})');
    if (p.fatMassKg != null && p.leanMassKg != null) {
      buf.writeln('Fat mass: ${p.fatMassKg!.toStringAsFixed(1)}kg  Fat-free mass: ${p.leanMassKg!.toStringAsFixed(1)}kg');
    }

    // ── GOAL PROGRESS ─────────────────────────────────────────────────────
    buf.writeln('\nGOAL PROGRESS');
    if (p.startWeightKg != null) buf.writeln('Start weight: ${p.startWeightKg!.toStringAsFixed(1)}kg');
    buf.writeln('Current: ${weight}kg  Goal: ${p.goalWeightKg.toStringAsFixed(1)}kg  Remaining: ${kgLeft}kg');
    buf.writeln('Progress: ${(p.goalProgress * 100).round()}% complete');
    if (p.weeksToGoal != null) buf.writeln('Weeks to goal: ~${p.weeksToGoal!.toStringAsFixed(0)} wks at current trend');

    // ── FOOD LOG — INDIVIDUAL ITEMS (last 7 days) ─────────────────────────
    buf.writeln('\nFOOD LOG — ITEMS (LAST 7 DAYS)');
    final foodHist = p.foodHistory;
    final mealLabel = {'breakfast': 'B', 'lunch': 'L', 'dinner': 'D', 'snack': 'S', 'other': 'O'};
    bool anyFood7 = false;
    for (int i = 0; i < 7; i++) {
      final d = now.subtract(Duration(days: i));
      final key = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
      final entries = foodHist[key];
      if (entries == null || entries.isEmpty) continue;
      anyFood7 = true;
      final totalCal  = entries.fold(0.0, (s, e) => s + e.calories);
      final totalProt = entries.fold(0.0, (s, e) => s + e.protein);
      buf.write('${fmt(d)}: ${totalCal.round()}kcal ${totalProt.round()}g prot');

      // Group by meal
      final byMeal = <String, List<dynamic>>{};
      for (final e in entries) {
        final ml = e.mealType.toString().split('.').last;
        byMeal.putIfAbsent(ml, () => []).add(e);
      }
      for (final ml in ['breakfast','lunch','dinner','snack','other']) {
        final items = byMeal[ml];
        if (items == null) continue;
        final short = mealLabel[ml] ?? ml[0].toUpperCase();
        final parts = items.map((e) => '${e.name}(${e.calories.round()}kcal,${e.protein.round()}g)').join(' ');
        buf.write(' | $short: $parts');
      }
      buf.writeln();
    }
    if (!anyFood7) buf.writeln('No food logged in last 7 days.');

    // ── FOOD LOG TOTALS (days 8–14) ───────────────────────────────────────
    buf.writeln('\nFOOD LOG — TOTALS (DAYS 8–14)');
    bool anyFood14 = false;
    for (int i = 7; i < 14; i++) {
      final d = now.subtract(Duration(days: i));
      final key = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
      final entries = foodHist[key];
      if (entries == null || entries.isEmpty) continue;
      anyFood14 = true;
      final totalCal  = entries.fold(0.0, (s, e) => s + e.calories);
      final totalProt = entries.fold(0.0, (s, e) => s + e.protein);
      buf.writeln('${fmt(d)}: ${totalCal.round()}kcal ${totalProt.round()}g protein (${entries.length} items)');
    }
    if (!anyFood14) buf.writeln('No food logged in days 8–14.');

    // ── WATER & SUPPLEMENTS (14 days) ─────────────────────────────────────
    buf.writeln('\nWATER & SUPPLEMENTS (LAST 14 DAYS)');
    final waterHist = p.waterHistory;
    final suppHist  = p.supplementHistory;
    bool anyWS = false;
    for (int i = 0; i < 14; i++) {
      final d = now.subtract(Duration(days: i));
      final key = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
      final ml   = waterHist[key] ?? 0;
      final supp = suppHist[key];
      if (ml == 0 && supp == null) continue;
      anyWS = true;
      final w  = supp?.whey       == true ? 'Whey✓'      : 'Whey✗';
      final cr = supp?.creatine   == true ? 'Creatine✓'  : 'Creatine✗';
      final mv = supp?.multivitamin == true ? 'Multi✓'   : 'Multi✗';
      buf.writeln('${fmt(d)}: ${ml}ml | $w $cr $mv');
    }
    if (!anyWS) buf.writeln('No water or supplement data in last 14 days.');

    // ── WEIGHT LOG (last 30 entries) ──────────────────────────────────────
    buf.writeln('\nWEIGHT LOG (LAST 30 ENTRIES)');
    final body = p.getRecentBodyEntries(days: 90);
    final recent30 = body.length > 30 ? body.sublist(body.length - 30) : body;
    if (recent30.isEmpty) {
      buf.writeln('No weight entries logged.');
    } else {
      for (final e in recent30) {
        buf.writeln('${fmt(e.date)}: ${e.weightKg.toStringAsFixed(1)}kg');
      }
    }

    // ── SCALE HISTORY (recent 10) ─────────────────────────────────────────
    buf.writeln('\nSCALE HISTORY (RECENT 10)');
    final scales = p.scaleHistory;
    final rs = scales.length > 10 ? scales.sublist(scales.length - 10) : scales;
    if (rs.isEmpty) {
      buf.writeln('No scale entries logged.');
    } else {
      for (final e in rs.reversed) {
        buf.writeln('${fmt(e.date)} ${e.date.year.toString().substring(2)}: '
            '${e.weightKg.toStringAsFixed(1)}kg fat ${e.bodyFatPercent.toStringAsFixed(1)}% '
            'muscle ${e.muscleMassKg.toStringAsFixed(1)}kg BMR ${e.bmr.round()}');
      }
    }

    // ── BODY MEASUREMENTS (recent 5) ──────────────────────────────────────
    buf.writeln('\nBODY MEASUREMENTS (RECENT 5)');
    final meas = p.measurementHistory;
    final rm = meas.length > 5 ? meas.sublist(meas.length - 5) : meas;
    if (rm.isEmpty) {
      buf.writeln('No measurements logged.');
    } else {
      for (final e in rm.reversed) {
        final parts = <String>[];
        if (e.chestCm     != null) parts.add('chest ${e.chestCm!.toStringAsFixed(1)}cm');
        if (e.waistCm     != null) parts.add('waist ${e.waistCm!.toStringAsFixed(1)}cm');
        if (e.hipsCm      != null) parts.add('hips ${e.hipsCm!.toStringAsFixed(1)}cm');
        if (e.leftArmCm   != null) parts.add('arm ${e.leftArmCm!.toStringAsFixed(1)}cm');
        if (e.leftThighCm != null) parts.add('thigh ${e.leftThighCm!.toStringAsFixed(1)}cm');
        buf.writeln('${fmt(e.date)}: ${parts.isEmpty ? "no data" : parts.join(", ")}');
      }
    }

    // ── WORKOUT LOG (last 15) ─────────────────────────────────────────────
    buf.writeln('\nWORKOUT LOG (LAST 15)');
    final allW = [...p.workoutHistory]..sort((a,b) => b.date.compareTo(a.date));
    final rw   = allW.length > 15 ? allW.sublist(0, 15) : allW;
    if (rw.isEmpty) {
      buf.writeln('No workouts logged.');
    } else {
      for (final w in rw) {
        final exParts = w.exercises.map((ex) {
          final sets = ex.sets.map((s) => '${s.reps}x${s.weight.toStringAsFixed(0)}kg').join(',');
          return '${ex.name}($sets)';
        }).join(' ');
        buf.writeln('${fmt(w.date)}: ${w.name} — $exParts');
      }
    }

    // ── 1RM ESTIMATES ─────────────────────────────────────────────────────
    buf.writeln('\nESTIMATED 1RM (EPLEY FORMULA)');
    const bigLifts = ['Deadlift','Squats','Bench Press','Overhead Press',
                      'Barbell Rows','Pull-ups','Romanian Deadlift'];
    bool any1rm = false;
    for (final lift in bigLifts) {
      double bestRM = 0; double bestW = 0; int bestR = 0;
      for (final w in p.workoutHistory) {
        for (final ex in w.exercises) {
          if (ex.name == lift) {
            for (final s in ex.sets) {
              final est = s.reps == 1 ? s.weight : s.weight * (1 + s.reps / 30.0);
              if (est > bestRM) { bestRM = est; bestW = s.weight; bestR = s.reps; }
            }
          }
        }
      }
      if (bestRM > 0) {
        any1rm = true;
        buf.writeln('$lift: ~${bestRM.toStringAsFixed(0)}kg (${bestW.toStringAsFixed(0)}kg×$bestR)');
      }
    }
    if (!any1rm) buf.writeln('No compound lifts logged yet.');

    return '''You are ${p.userName}'s personal on-device fitness AI coach. Today is ${fmt(now)} ${now.year}.

PROFILE
Age ${p.age} · ${p.heightCm.toInt()}cm · Goal: reach ${p.goalWeightKg.toStringAsFixed(1)}kg · Indian diet

TODAY
Calories  ${p.todayCaloriesTotal.round()} / ${p.calorieGoal}kcal (${(p.calorieProgress * 100).round()}%)
Protein   ${p.todayProteinTotal.round()} / ${p.proteinGoal}g (${(p.proteinProgress * 100).round()}%)
Water     ${p.todayWaterMl} / ${p.waterGoalMl}ml (${(p.waterProgress * 100).round()}%)
Steps     ${p.todaySteps} / ${p.stepGoal} (${(p.stepProgress * 100).round()}%)
Workout   ${p.todayWorkout != null ? 'done' : 'not done today'}

METABOLISM
TDEE  $tdee
Fat-loss target  ${cut}kcal/day (for ~0.5kg/wk loss)

7-DAY AVERAGES
Calories  ${p.avgCaloriesForDays(1, 7).round()}kcal/day
Protein   ${p.avgProteinForDays(1, 7).round()}g/day
Weight trend  $trend

BODY
Current weight  ${weight}kg
Goal weight  ${p.goalWeightKg.toStringAsFixed(1)}kg
ETA  $eta
${buf.toString()}
HABITS (last 30 days)
Habit score          ${p.habitScore}/100
Deficit streak       ${p.deficitStreak} days
Calorie adherence    ${(p.calorieAdherenceRate * 100).round()}%
Protein adherence    ${(p.proteinAdherenceRate * 100).round()}%
Late-night eating    ${p.hasLateNightEatingPattern ? 'pattern detected (>9 PM)' : 'none'}
Days since workout   ${p.daysSinceLastWorkout == 999 ? 'never' : p.daysSinceLastWorkout == 0 ? 'today' : '${p.daysSinceLastWorkout}d ago'}
Workout streak       ${p.workoutStreak} days
Diet streak          ${p.calorieStreak} days

RULES
- Answer in 2–4 sentences unless more detail is explicitly asked.
- Reference his ACTUAL numbers — never invent data.
- For food: suggest Indian foods (roti, dal, paneer, eggs, sabji, rice, curd, whey shake).
- Be direct, specific, and actionable.''';
  }

  /// Exposed for unit tests only — do not call from UI.
  @visibleForTesting
  String buildSystemPromptForTest(FitnessProvider p) => _systemPrompt(p);

  // ── Helpers ─────────────────────────────────────────────────────────────────
  void _setState(AiModelState s, {String error = ''}) {
    _state = s;
    _error = error;
    notifyListeners();
  }

  @override
  void dispose() {
    _model?.close();
    super.dispose();
  }
}
