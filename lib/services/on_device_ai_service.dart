import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/fitness_provider.dart';

enum AiModelState { notInstalled, downloading, loading, ready, error }

class OnDeviceAiService extends ChangeNotifier {
  // ── Single model: Gemma 3 1B INT4 (~600 MB) ────────────────────────────────
  static const _enterpriseToken = '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';
  static const _modelUrl =
      'https://huggingface.co/litert-community/Gemma3-1B-IT'
      '/resolve/main/gemma3-1b-it-int4.litertlm';
  static const _modelType    = ModelType.gemmaIt;
  static const _modelFile    = ModelFileType.litertlm;
  static const _modelName    = 'Gemma 3 1B';
  static const _modelSize    = '~600 MB';
  // KV-cache for 1B model. Compact prompt targets ~700 tokens leaving ~1300 for chat.
  static const _maxTokens    = 2048;

  static const _prefToken          = 'hf_token_ai_chat';
  static const _prefInstalledModel = 'ai_installed_model_id';
  static const _installedId        = 'gemma3_1b';

  // ── State ───────────────────────────────────────────────────────────────────
  AiModelState _state      = AiModelState.notInstalled;
  double       _dlProgress = 0.0;
  String       _error      = '';
  String       _hfToken    = '';
  bool         _installed  = false;

  InferenceModel? _model;
  InferenceChat?  _chat;

  // ── Getters ─────────────────────────────────────────────────────────────────
  AiModelState get state        => _state;
  double       get dlProgress   => _dlProgress;
  String       get errorMessage => _error;
  String       get hfToken      => _hfToken;
  bool         get isReady      => _state == AiModelState.ready;
  bool         get hasToken     => _hfToken.isNotEmpty;
  bool         get isInstalled  => _installed;
  String       get modelName    => _modelName;
  String       get modelSize    => _modelSize;

  // ── Init — called at app start and on chat-screen open ─────────────────────
  Future<void> init() async {
    await saveToken(_enterpriseToken);
    final prefs = await SharedPreferences.getInstance();
    _installed = (prefs.getString(_prefInstalledModel) ?? '') == _installedId;

    try {
      await FlutterGemma.initialize(huggingFaceToken: _enterpriseToken);
      if (_installed && FlutterGemma.hasActiveModel()) {
        await _loadModel();
      } else {
        _installed = false;
        _setState(AiModelState.notInstalled);
      }
    } catch (_) {
      _setState(AiModelState.notInstalled);
    }
  }

  Future<void> saveToken(String token) async {
    _hfToken = token.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefToken, _hfToken);
    notifyListeners();
  }

  // ── Download + load ─────────────────────────────────────────────────────────
  Future<void> downloadAndLoad() async {
    if (_state == AiModelState.downloading || _state == AiModelState.loading) return;
    try {
      _dlProgress = 0;
      _setState(AiModelState.downloading);

      await FlutterGemma.initialize(huggingFaceToken: _enterpriseToken);
      await FlutterGemma.installModel(
        modelType: _modelType,
        fileType:  _modelFile,
      )
          .fromNetwork(_modelUrl, token: _enterpriseToken)
          .withProgress((pct) {
            _dlProgress = (pct / 100.0).clamp(0.0, 1.0);
            notifyListeners();
          })
          .install();

      _installed = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefInstalledModel, _installedId);

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
        maxTokens:        _maxTokens,
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
      yield 'Model not loaded. Close and reopen the chat to retry.';
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

  // ── Compact system prompt — targets ~700 tokens for Gemma 3 1B (2048 limit) ─
  // Leaves ~1300 tokens for multi-turn conversation.
  String _systemPrompt(FitnessProvider p) {
    final now = DateTime.now();
    final mo  = ['Jan','Feb','Mar','Apr','May','Jun',
                 'Jul','Aug','Sep','Oct','Nov','Dec'];
    String d(DateTime dt) => '${dt.day} ${mo[dt.month - 1]}';

    final wt     = p.latestWeightKg?.toStringAsFixed(1) ?? '?';
    final trend  = p.weeklyWeightChange != null
        ? '${p.weeklyWeightChange!.toStringAsFixed(2)}kg/wk'
        : 'no data';
    final eta    = p.estimatedGoalDate != null
        ? '${d(p.estimatedGoalDate!)} ${p.estimatedGoalDate!.year}'
        : 'N/A';
    final tdee   = p.bestTdee != null
        ? '${p.bestTdee!.round()}${p.isTdeeCalibrated ? "*" : ""}kcal'
        : 'N/A';
    final cut    = p.fatLossCalorieTarget?.round().toString() ?? 'N/A';
    final kgLeft = p.kgToGoal?.toStringAsFixed(1) ?? 'N/A';
    final pct    = (p.goalProgress * 100).round();

    final buf = StringBuffer();

    // ── BODY COMPOSITION (only when scale data exists) ─────────────────────
    final sc = p.latestScaleEntry;
    if (sc != null || p.bmi != null) {
      buf.write('BODY:');
      if (p.bmi != null) buf.write(' BMI ${p.bmi!.toStringAsFixed(1)}(${p.bmiCategory})');
      if (sc != null) {
        buf.write(' | Fat ${sc.bodyFatPercent.toStringAsFixed(1)}%'
            ' | Lean ${sc.leanBodyMassKg.toStringAsFixed(1)}kg'
            ' | Muscle ${sc.muscleMassKg.toStringAsFixed(1)}kg');
        if (p.ffmi != null) buf.write(' | FFMI ${p.ffmi!.toStringAsFixed(1)}');
        if (p.waistToHipRatio != null) buf.write(' | WHR ${p.waistToHipRatio!.toStringAsFixed(2)}');
      }
      buf.writeln();
    }

    // ── FOOD — last 3 days with individual items ───────────────────────────
    buf.writeln('FOOD (3d):');
    final mealLabel = {'breakfast': 'B', 'lunch': 'L', 'dinner': 'D', 'snack': 'S', 'other': 'O'};
    final foodHist  = p.foodHistory;
    bool anyFood = false;
    for (int i = 0; i < 3; i++) {
      final day  = now.subtract(Duration(days: i));
      final key  = '${day.year}-${day.month.toString().padLeft(2,'0')}-${day.day.toString().padLeft(2,'0')}';
      final entries = foodHist[key];
      if (entries == null || entries.isEmpty) continue;
      anyFood = true;
      final cal  = entries.fold(0.0, (s, e) => s + e.calories).round();
      final prot = entries.fold(0.0, (s, e) => s + e.protein).round();
      buf.write('${d(day)}: ${cal}kcal ${prot}g');
      final byMeal = <String, List<dynamic>>{};
      for (final e in entries) {
        byMeal.putIfAbsent(e.mealType.toString().split('.').last, () => []).add(e);
      }
      for (final ml in ['breakfast','lunch','dinner','snack','other']) {
        final items = byMeal[ml];
        if (items == null) continue;
        final tag   = mealLabel[ml]!;
        // Limit to 3 items per meal to keep prompt short
        final shown = items.take(3).map((e) => '${e.name}(${e.calories.round()}kcal)').join(' ');
        buf.write(' $tag:$shown');
      }
      buf.writeln();
    }
    if (!anyFood) buf.writeln('No food logged in last 3 days.');

    // ── WORKOUTS — last 5 ─────────────────────────────────────────────────
    buf.writeln('WORKOUTS (5):');
    final allW = [...p.workoutHistory]..sort((a, b) => b.date.compareTo(a.date));
    final rw   = allW.take(5).toList();
    if (rw.isEmpty) {
      buf.writeln('None logged.');
    } else {
      for (final w in rw) {
        // Show exercise name + best set only (most compact)
        final exStr = w.exercises.map((ex) {
          if (ex.sets.isEmpty) return ex.name;
          // Best set = highest weight
          final best = ex.sets.reduce((a, b) => a.weight >= b.weight ? a : b);
          return '${ex.name} ${best.weight.toStringAsFixed(0)}kg×${best.reps}';
        }).join(', ');
        buf.writeln('${d(w.date)}: ${w.name} — $exStr');
      }
    }

    // ── WEIGHT — last 5 entries ────────────────────────────────────────────
    final bodyEntries = p.getRecentBodyEntries(days: 60);
    final last5w = bodyEntries.length > 5 ? bodyEntries.sublist(bodyEntries.length - 5) : bodyEntries;
    if (last5w.isNotEmpty) {
      buf.write('WEIGHT: ');
      buf.writeln(last5w.map((e) => '${d(e.date)} ${e.weightKg.toStringAsFixed(1)}kg').join(', '));
    }

    // ── TOP LIFTS 1RM ─────────────────────────────────────────────────────
    const bigLifts = ['Deadlift', 'Squats', 'Bench Press', 'Overhead Press', 'Barbell Rows'];
    final oneRm = <String>[];
    for (final lift in bigLifts) {
      double best = 0;
      for (final w in p.workoutHistory) {
        for (final ex in w.exercises) {
          if (ex.name == lift) {
            for (final s in ex.sets) {
              final est = s.reps == 1 ? s.weight : s.weight * (1 + s.reps / 30.0);
              if (est > best) best = est;
            }
          }
        }
      }
      if (best > 0) oneRm.add('$lift~${best.toStringAsFixed(0)}kg');
    }
    if (oneRm.isNotEmpty) buf.writeln('1RM: ${oneRm.join(' ')}');

    // ── WATER & SUPPLEMENTS — last 7 days (compact) ───────────────────────
    final waterH = p.waterHistory;
    final suppH  = p.supplementHistory;
    final wsLines = <String>[];
    for (int i = 0; i < 7; i++) {
      final day = now.subtract(Duration(days: i));
      final key = '${day.year}-${day.month.toString().padLeft(2,'0')}-${day.day.toString().padLeft(2,'0')}';
      final ml   = waterH[key] ?? 0;
      final supp = suppH[key];
      if (ml == 0 && supp == null) continue;
      final w  = supp?.whey        == true ? 'W✓' : 'W✗';
      final cr = supp?.creatine    == true ? 'Cr✓' : 'Cr✗';
      final mv = supp?.multivitamin == true ? 'M✓' : 'M✗';
      wsLines.add('${d(day)}:${ml}ml $w$cr$mv');
    }
    if (wsLines.isNotEmpty) buf.writeln('WATER/SUPPS: ${wsLines.join(' | ')}');

    final sex = p.isMale ? 'M' : 'F';

return '''You are ${p.userName}'s fitness AI. ${d(now)} ${now.year}.
PROFILE: ${p.age}y ${sex} ${p.heightCm.toInt()}cm · Indian diet · Goal ${p.goalWeightKg.toStringAsFixed(1)}kg
TODAY: Cal ${p.todayCaloriesTotal.round()}/${p.calorieGoal}kcal(${(p.calorieProgress*100).round()}%) Prot ${p.todayProteinTotal.round()}/${p.proteinGoal}g Water ${p.todayWaterMl}/${p.waterGoalMl}ml Steps ${p.todaySteps}/${p.stepGoal} Workout:${p.todayWorkout != null ? '✓' : '✗'}
METABOLISM: TDEE $tdee(*=calibrated) | Cut target ${cut}kcal/day | Trend $trend | ETA $eta
PROGRESS: ${wt}kg→${p.goalWeightKg.toStringAsFixed(1)}kg ($pct% done, ${kgLeft}kg left) | Wks to goal: ${p.weeksToGoal?.toStringAsFixed(0) ?? 'N/A'}
GOALS: Cal ${p.calorieGoal}kcal Prot ${p.proteinGoal}g Water ${p.waterGoalMl}ml Steps ${p.stepGoal}
HABITS: Score ${p.habitScore}/100 | DefStreak ${p.deficitStreak}d | CalAdhere ${(p.calorieAdherenceRate*100).round()}% | ProtAdhere ${(p.proteinAdherenceRate*100).round()}% | WorkStreak ${p.workoutStreak}d | DietStreak ${p.calorieStreak}d | LateNight:${p.hasLateNightEatingPattern ? 'yes' : 'no'}
${buf}RULES: 2-4 sentences. Reference actual numbers. Indian foods: roti/dal/paneer/eggs/curd/chicken/whey. Be specific & actionable.''';
  }

  /// Exposed for unit tests only.
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
