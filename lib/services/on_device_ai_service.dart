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
  static const _prefAutoLoad       = 'ai_auto_load';
  static const _installedId        = 'gemma3_1b';

  // ── State ───────────────────────────────────────────────────────────────────
  AiModelState _state      = AiModelState.notInstalled;
  double       _dlProgress = 0.0;
  String       _error      = '';
  String       _hfToken    = '';
  bool         _installed  = false;
  bool         _autoLoad   = true; // cached from prefs; true = load at app start

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
  bool         get autoLoad     => _autoLoad;
  String       get modelName    => _modelName;
  String       get modelSize    => _modelSize;

  // ── Auto-load setting ────────────────────────────────────────────────────────
  Future<void> saveAutoLoad(bool value) async {
    _autoLoad = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefAutoLoad, value);
    notifyListeners();
  }

  // ── Init — called at app start (lazy:false) ──────────────────────────────────
  // Respects the ai_auto_load setting: if disabled, skips loading entirely.
  // The guard also prevents double-loading if init() is called more than once.
  Future<void> init() async {
    if (_state == AiModelState.ready    ||
        _state == AiModelState.loading  ||
        _state == AiModelState.downloading) return;

    final prefs = await SharedPreferences.getInstance();
    _autoLoad = prefs.getBool(_prefAutoLoad) ?? true;

    // Auto-load disabled — don't touch the model until user opens AI Coach.
    if (!_autoLoad) {
      _installed = (prefs.getString(_prefInstalledModel) ?? '') == _installedId;
      notifyListeners();
      return;
    }

    await _doInit(prefs);
  }

  // ── initForChat — always loads, ignores the auto-load setting ───────────────
  // Called by ChatScreen when the user explicitly opens AI Coach.
  Future<void> initForChat() async {
    if (_state == AiModelState.ready    ||
        _state == AiModelState.loading  ||
        _state == AiModelState.downloading) return;
    final prefs = await SharedPreferences.getInstance();
    await _doInit(prefs);
  }

  Future<void> _doInit(SharedPreferences prefs) async {
    await saveToken(_enterpriseToken);
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
    // Model already in memory — just surface the ready state without reloading.
    // This is the key guard that prevents re-loading when user navigates back
    // to an existing chat while the app is still running.
    if (_model != null) {
      _setState(AiModelState.ready);
      return;
    }
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
  /// Sends [userMessage] to the model.
  ///
  /// On the FIRST message of a conversation, context-relevant history is
  /// injected into the SYSTEM PROMPT (not the user message). This keeps the
  /// KV-cache stable across turns and prevents token overflow.
  ///
  /// On subsequent messages, plain text is sent — no per-turn context
  /// injection. This is the key fix for the "exceeded maximum tokens" error.
  Stream<String> sendMessage(String userMessage, FitnessProvider provider) async* {
    if (_model == null) {
      yield 'Model not loaded. Please go back and reopen the chat.';
      return;
    }
    try {
      if (_chat == null) {
        // First message — build context-enriched system prompt for this topic.
        // Context is injected ONCE here and stays in the system instruction.
        // Never injected per-turn so conversation tokens stay bounded.
        final sysPrompt = _buildRichSystemPrompt(userMessage, provider);
        _chat = await _model!.createChat(
          systemInstruction: sysPrompt,
          temperature:  0.7,
          topK:         40,
          randomSeed:   42,
          tokenBuffer:  256, // tokens reserved for model output per turn
        );
      }
      // Plain user message — no context appended (it's already in the system prompt).
      await _chat!.addQueryChunk(Message(text: userMessage, isUser: true));
      await for (final r in _chat!.generateChatResponseAsync()) {
        if (r is TextResponse) yield r.token;
      }
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('token') || msg.contains('exceed') || msg.contains('context length')) {
        // Conversation hit the token limit — reset so next message starts fresh.
        _chat = null;
        yield '\n\n⚠️ Conversation got too long. Starting fresh — please ask your question again.';
      } else {
        yield '\n\n[Error: $e]';
      }
    }
  }

  /// Builds the system prompt for a new conversation, injecting only the
  /// context sections relevant to [firstMessage] keywords.
  /// Sections are strictly capped to stay within the 2048-token KV cache.
  String _buildRichSystemPrompt(String firstMessage, FitnessProvider p) {
    final q    = firstMessage.toLowerCase();
    final base = _systemPrompt(p); // ~500-700 tokens
    final ctx  = _buildContextForQuery(q, p); // 0-400 tokens, keyword-gated
    if (ctx.isEmpty) return base;
    // Append context before RULES so model always reads it before answering.
    return base.replaceFirst(
      'RULES:',
      'EXTRA DATA:\n$ctx\nRULES:',
    );
  }

  /// Builds keyword-triggered context for injection into the system prompt.
  /// STRICT token caps per section — total must stay under ~400 tokens so the
  /// full system prompt (base ~600t + context ~400t = ~1000t) leaves ~800t
  /// for conversation turns before hitting the 2048 KV-cache limit.
  String _buildContextForQuery(String query, FitnessProvider p) {
    final mo = ['Jan','Feb','Mar','Apr','May','Jun',
                'Jul','Aug','Sep','Oct','Nov','Dec'];
    String fd(DateTime dt) => '${dt.day} ${mo[dt.month - 1]}';

    final parts = <String>[];

    // ── Weight (last 14 entries, 1-line CSV) — ~60 tokens ─────────────────
    if (_has(query, ['weight', 'kg', 'progress', 'trend', 'losing', 'gaining'])) {
      final entries = p.getRecentBodyEntries(days: 60);
      final slice   = entries.length > 14 ? entries.sublist(entries.length - 14) : entries;
      if (slice.isNotEmpty) {
        parts.add('WeightLog: ${slice.map((e) => '${fd(e.date)}:${e.weightKg.toStringAsFixed(1)}kg').join(', ')}');
      }
    }

    // ── Food (last 5 days, max 2 items/meal, totals only for older) — ~120t ─
    if (_has(query, ['food', 'eat', 'diet', 'calorie', 'protein', 'carb', 'meal', 'breakfast', 'lunch', 'dinner', 'snack', 'what did'])) {
      final hist  = p.foodHistory;
      final lines = <String>[];
      for (int i = 0; i < 5; i++) {
        final day  = DateTime.now().subtract(Duration(days: i));
        final key  = '${day.year}-${day.month.toString().padLeft(2,'0')}-${day.day.toString().padLeft(2,'0')}';
        final ents = hist[key];
        if (ents == null || ents.isEmpty) continue;
        final cal  = ents.fold(0.0, (s, e) => s + e.calories).round();
        final prot = ents.fold(0.0, (s, e) => s + e.protein).round();
        // Compact: show 2 items max, then "..." if more
        final items = ents.take(2).map((e) {
          final ml = e.mealType.toString().split('.').last[0].toUpperCase();
          return '$ml:${e.name}(${e.calories.round()})';
        }).join(' ');
        final extra = ents.length > 2 ? '+${ents.length - 2}more' : '';
        lines.add('${fd(day)}:${cal}kcal ${prot}g $items$extra');
      }
      if (lines.isNotEmpty) parts.add('FoodLog:\n${lines.join('\n')}');
    }

    // ── Workouts (last 5, best-set only) — ~80 tokens ─────────────────────
    if (_has(query, ['workout', 'exercise', 'lift', 'bench', 'deadlift', 'squat', 'gym', 'train', 'strength', 'muscle', 'reps', 'sets'])) {
      final all  = [...p.workoutHistory]..sort((a, b) => b.date.compareTo(a.date));
      final last = all.take(5);
      if (last.isNotEmpty) {
        final lines = last.map((w) {
          final exs = w.exercises.map((ex) {
            if (ex.sets.isEmpty) return ex.name;
            final best = ex.sets.reduce((a, b) => a.weight >= b.weight ? a : b);
            return '${ex.name} ${best.weight.toStringAsFixed(0)}×${best.reps}';
          }).join(', ');
          return '${fd(w.date)}:${w.name}—$exs';
        }).join('\n');
        parts.add('Workouts:\n$lines');
      }
    }

    // ── Measurements (latest entry only) — ~30 tokens ─────────────────────
    if (_has(query, ['measurement', 'waist', 'chest', 'arm', 'thigh', 'hip', 'size'])) {
      final latest = p.latestMeasurements;
      if (latest != null) {
        final ps = <String>[];
        if (latest.chestCm     != null) ps.add('chest ${latest.chestCm!.toStringAsFixed(0)}cm');
        if (latest.waistCm     != null) ps.add('waist ${latest.waistCm!.toStringAsFixed(0)}cm');
        if (latest.hipsCm      != null) ps.add('hips ${latest.hipsCm!.toStringAsFixed(0)}cm');
        if (latest.leftArmCm   != null) ps.add('arm ${latest.leftArmCm!.toStringAsFixed(0)}cm');
        if (latest.leftThighCm != null) ps.add('thigh ${latest.leftThighCm!.toStringAsFixed(0)}cm');
        if (ps.isNotEmpty) parts.add('Measurements: ${ps.join(', ')}');
      }
    }

    // ── Scale / body composition (last 3) — ~60 tokens ────────────────────
    if (_has(query, ['body fat', 'fat%', 'lean', 'muscle mass', 'body comp', 'scale', 'visceral', 'bmr', 'composition'])) {
      final scales = p.scaleHistory;
      final last3  = scales.length > 3 ? scales.sublist(scales.length - 3) : scales;
      if (last3.isNotEmpty) {
        final lines = last3.reversed.map((e) =>
          '${fd(e.date)}:${e.weightKg.toStringAsFixed(1)}kg fat${e.bodyFatPercent.toStringAsFixed(1)}% muscle${e.muscleMassKg.toStringAsFixed(1)}kg lean${e.leanBodyMassKg.toStringAsFixed(1)}kg'
        ).join(', ');
        parts.add('ScaleHistory: $lines');
      }
    }

    // ── Water/supplements (last 7 days, 1-line) — ~50 tokens ──────────────
    if (_has(query, ['water', 'hydrat', 'supplement', 'whey', 'creatine', 'multi'])) {
      final waterH = p.waterHistory;
      final suppH  = p.supplementHistory;
      final ws     = <String>[];
      for (int i = 0; i < 7; i++) {
        final day = DateTime.now().subtract(Duration(days: i));
        final key = '${day.year}-${day.month.toString().padLeft(2,'0')}-${day.day.toString().padLeft(2,'0')}';
        final ml   = waterH[key] ?? 0;
        final supp = suppH[key];
        if (ml == 0 && supp == null) continue;
        final s = [
          if (supp?.whey         == true) 'W✓' else 'W✗',
          if (supp?.creatine     == true) 'Cr✓' else 'Cr✗',
          if (supp?.multivitamin == true) 'M✓' else 'M✗',
        ].join('');
        ws.add('${fd(day)}:${ml}ml$s');
      }
      if (ws.isNotEmpty) parts.add('Water: ${ws.join(' ')}');
    }

    return parts.join('\n');
  }

  static bool _has(String query, List<String> keywords) =>
      keywords.any((k) => query.contains(k));

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
${buf}RULES: Think step by step, then give a concise answer (2-5 sentences). Always cite the user's ACTUAL numbers. For food suggestions use Indian foods: roti/dal/paneer/eggs/curd/chicken/fish/whey. Be direct and specific — no generic advice.''';
  }

  /// Exposed for unit tests only.
  @visibleForTesting
  String buildSystemPromptForTest(FitnessProvider p) => _systemPrompt(p);

  @visibleForTesting
  String buildContextForQueryTest(String query, FitnessProvider p) =>
      _buildContextForQuery(query, p);

  @visibleForTesting
  String buildRichPromptForTest(String firstMessage, FitnessProvider p) =>
      _buildRichSystemPrompt(firstMessage, p);

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
