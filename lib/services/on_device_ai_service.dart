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
  bool         _autoLoad   = true;
  bool         _sending    = false;    // prevents concurrent sendMessage() calls
  int          _lastNotifiedPct = -1; // throttles download progress notifications

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
  bool         get isSending    => _sending;
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
  Future<void> init() async {
    if (_state == AiModelState.ready    ||
        _state == AiModelState.loading  ||
        _state == AiModelState.downloading) return;

    final prefs = await SharedPreferences.getInstance();
    _autoLoad = prefs.getBool(_prefAutoLoad) ?? true;

    if (!_autoLoad) {
      _installed = (prefs.getString(_prefInstalledModel) ?? '') == _installedId;
      _setState(AiModelState.notInstalled);
      return;
    }

    await _doInit(prefs);
  }

  // ── initForChat — always loads, ignores auto-load setting ───────────────────
  Future<void> initForChat() async {
    if (_state == AiModelState.ready    ||
        _state == AiModelState.loading  ||
        _state == AiModelState.downloading) return;
    // Claim the loading slot immediately so a concurrent call that arrives
    // before the first await doesn't also slip through the guard above.
    _setState(AiModelState.loading);
    final prefs = await SharedPreferences.getInstance();
    await _doInit(prefs);
  }

  Future<void> _doInit(SharedPreferences prefs) async {
    await saveToken(_enterpriseToken);
    _installed = (prefs.getString(_prefInstalledModel) ?? '') == _installedId;

    if (!_installed) {
      _setState(AiModelState.notInstalled);
      return;
    }

    try {
      await FlutterGemma.initialize(huggingFaceToken: _enterpriseToken);

      // installModel().install() is idempotent: skips download if file exists on disk,
      // just calls manager.setActiveModel() (fast). This is required before
      // getActiveModel() can succeed in a new session.
      // foreground:true = Android foreground service → OS won't kill 600MB download.
      bool redownloading = false;
      _lastNotifiedPct = -1;
      await FlutterGemma.installModel(
        modelType: _modelType,
        fileType:  _modelFile,
      )
          .fromNetwork(_modelUrl, token: _enterpriseToken, foreground: true)
          .withProgress((pct) {
            // Only fire if actually downloading AND pct changed by ≥1%
            final intPct = pct.clamp(0, 100);
            if (intPct == _lastNotifiedPct) return;
            _lastNotifiedPct = intPct;
            if (!redownloading) {
              redownloading = true;
              _dlProgress = 0;
              _setState(AiModelState.downloading);
            }
            _dlProgress = (intPct / 100.0).clamp(0.0, 1.0);
            notifyListeners();
          })
          .install();

      await _loadModel();
    } catch (e) {
      // Model was marked installed but file is gone (e.g. fresh reinstall with
      // imported backup that had the installed flag). Clear the stale flag and
      // auto-trigger a fresh download so the user doesn't have to tap anything.
      _installed = false;
      await prefs.remove(_prefInstalledModel);
      if (_autoLoad) {
        // Auto-download: show progress bar, no user action needed
        await downloadAndLoad();
      } else {
        _setState(AiModelState.notInstalled);
      }
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
      _lastNotifiedPct = -1;
      _setState(AiModelState.downloading);

      await FlutterGemma.initialize(huggingFaceToken: _enterpriseToken);
      await FlutterGemma.installModel(
        modelType: _modelType,
        fileType:  _modelFile,
      )
          .fromNetwork(_modelUrl, token: _enterpriseToken, foreground: true)
          .withProgress((pct) {
            // Throttle: only notify when integer percentage changes
            final intPct = pct.clamp(0, 100);
            if (intPct == _lastNotifiedPct) return;
            _lastNotifiedPct = intPct;
            _dlProgress = (intPct / 100.0).clamp(0.0, 1.0);
            notifyListeners();
          })
          .install();

      // Persist FIRST — if the app crashes between write and flag, the flag
      // stays false and the download retries cleanly on next launch.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefInstalledModel, _installedId);
      _installed = true;

      await _loadModel();
    } catch (e) {
      final msg = e.toString();
      // "no longer installed" / "modelManager" errors mean the model registry is
      // out of sync with the actual file on disk. Clear the flag so the next
      // download starts fresh rather than getting stuck in a bad state.
      _installed = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefInstalledModel);
      if (msg.contains('no longer installed') || msg.contains('modelManager')) {
        _setState(AiModelState.notInstalled);
      } else {
        _setState(AiModelState.error,
            error: msg.length > 200 ? '${msg.substring(0, 200)}…' : msg);
      }
    }
  }

  // NPU → GPU → CPU fallback so the model loads even on devices without a
  // qualified NPU. The first backend that succeeds wins.
  Future<void> _loadModel() async {
    if (_model != null) {
      _setState(AiModelState.ready);
      return;
    }
    _setState(AiModelState.loading);
    final backends = [PreferredBackend.npu, PreferredBackend.gpu, PreferredBackend.cpu];
    for (int i = 0; i < backends.length; i++) {
      try {
        _model = await FlutterGemma.getActiveModel(
          maxTokens:        _maxTokens,
          preferredBackend: backends[i],
        );
        _setState(AiModelState.ready);
        return;
      } catch (e) {
        if (i == backends.length - 1) rethrow; // all backends failed
        // else try next backend
      }
    }
  }

  void resetConversation() {
    _chat = null;
    notifyListeners();
  }

  // ── Chat ────────────────────────────────────────────────────────────────────
  /// Sends [userMessage] to the model.
  ///
  /// On the FIRST message, context-relevant history is injected into the system
  /// prompt (not the user message) so the KV-cache stays stable across turns.
  ///
  /// A `_sending` guard prevents concurrent calls — only one stream at a time.
  Stream<String> sendMessage(String userMessage, FitnessProvider provider) async* {
    if (_model == null) {
      yield 'Model not loaded. Please go back and reopen the chat.';
      return;
    }
    // Service-layer guard: prevents concurrent sendMessage calls even if the UI
    // guard (_thinking) somehow fails.
    if (_sending) return;
    _sending = true;
    try {
      if (_chat == null) {
        final sysPrompt = _buildRichSystemPrompt(userMessage, provider);
        _chat = await _model!.createChat(
          systemInstruction: sysPrompt,
          temperature:  0.3,  // lower = more reliable number citation (was 0.7)
          topK:         40,
          // No fixed seed — allow natural variation per session
          tokenBuffer:  256,
        );
      }
      await _chat!.addQueryChunk(Message(text: userMessage, isUser: true));
      await for (final r in _chat!.generateChatResponseAsync()) {
        if (r is TextResponse) yield r.token;
      }
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('token') || msg.contains('exceed') || msg.contains('context length')) {
        _chat = null;
        yield '\n\n⚠️ Conversation got too long. Starting fresh — please ask your question again.';
      } else {
        yield '\n\n[Error: $e]';
      }
    } finally {
      _sending = false;
    }
  }

  // ── Prompt builders ─────────────────────────────────────────────────────────

  String _buildRichSystemPrompt(String firstMessage, FitnessProvider p) {
    final q    = firstMessage.toLowerCase();
    final base = _systemPrompt(p);
    final ctx  = _buildContextForQuery(q, p);
    if (ctx.isEmpty) return base;
    const anchor = 'Start your reply immediately with specific advice using the actual numbers above.';
    return base.replaceFirst(
      anchor,
      'EXTRA DATA (deeper history — reference only):\n$ctx\n\n$anchor',
    );
  }

  String _buildContextForQuery(String query, FitnessProvider p) {
    final mo = ['Jan','Feb','Mar','Apr','May','Jun',
                'Jul','Aug','Sep','Oct','Nov','Dec'];
    // Include year so the model can tell "3 months ago" from "last week"
    String fd(DateTime dt) => '${dt.day} ${mo[dt.month - 1]} ${dt.year}';

    final parts = <String>[];

    // Weight (last 14 entries, 1-line CSV) — ~70 tokens
    if (_has(query, ['weight', 'kg', 'progress', 'trend', 'losing', 'gaining'])) {
      final entries = p.getRecentBodyEntries(days: 60);
      final slice   = entries.length > 14 ? entries.sublist(entries.length - 14) : entries;
      if (slice.isNotEmpty) {
        parts.add('WeightLog: ${slice.map((e) => '${fd(e.date)}:${e.weightKg.toStringAsFixed(1)}kg').join(', ')}');
      }
    }

    // Food (last 5 days, max 2 items/meal) — ~130 tokens
    if (_has(query, ['food', 'eat', 'diet', 'calorie', 'protein', 'carb', 'meal', 'breakfast', 'lunch', 'dinner', 'snack', 'what did'])) {
      final hist  = p.foodHistory;
      final lines = <String>[];
      const mealAbbr = {'breakfast': 'Breakfast', 'lunch': 'Lunch', 'dinner': 'Dinner', 'snack': 'Snack', 'other': 'Other'};
      for (int i = 0; i < 5; i++) {
        final day  = DateTime.now().subtract(Duration(days: i));
        final key  = '${day.year}-${day.month.toString().padLeft(2,'0')}-${day.day.toString().padLeft(2,'0')}';
        final ents = hist[key];
        if (ents == null || ents.isEmpty) continue;
        final cal  = ents.fold(0.0, (s, e) => s + e.calories).round();
        final prot = ents.fold(0.0, (s, e) => s + e.protein).round();
        final items = ents.take(2).map((e) {
          final ml = mealAbbr[e.mealType.toString().split('.').last] ?? 'Other';
          final safeFoodName = _sanitizeInput(e.name);
          return '$ml:$safeFoodName(${e.calories.round()})';
        }).join(' ');
        final extra = ents.length > 2 ? '+${ents.length - 2}more' : '';
        lines.add('${fd(day)}:${cal}kcal ${prot}g $items$extra');
      }
      if (lines.isNotEmpty) parts.add('FoodLog:\n${lines.join('\n')}');
    }

    // Workouts (last 5, best-set only) — ~80 tokens
    if (_has(query, ['workout', 'exercise', 'lift', 'bench', 'deadlift', 'squat', 'gym', 'train', 'strength', 'muscle', 'reps', 'sets'])) {
      final all  = [...p.workoutHistory]..sort((a, b) => b.date.compareTo(a.date));
      final last = all.take(5);
      if (last.isNotEmpty) {
        final lines = last.map((w) {
          final safeWorkoutName = _sanitizeInput(w.name);
          final exs = w.exercises.map((ex) {
            final safeExName = _sanitizeInput(ex.name);
            if (ex.sets.isEmpty) return safeExName;
            final best = ex.sets.reduce((a, b) => a.weight >= b.weight ? a : b);
            return '$safeExName ${best.weight.toStringAsFixed(0)}kg×${best.reps}';
          }).join(', ');
          return '${fd(w.date)}:$safeWorkoutName—$exs';
        }).join('\n');
        parts.add('Workouts:\n$lines');
      }
    }

    // Measurements (latest entry only) — ~30 tokens
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

    // Scale / body composition (last 3) — ~60 tokens
    if (_has(query, ['body fat', 'lean', 'muscle mass', 'body comp', 'scale', 'visceral', 'composition'])) {
      final scales = p.scaleHistory;
      final last3  = scales.length > 3 ? scales.sublist(scales.length - 3) : scales;
      if (last3.isNotEmpty) {
        final lines = last3.reversed.map((e) =>
          '${fd(e.date)}:${e.weightKg.toStringAsFixed(1)}kg fat${e.bodyFatPercent.toStringAsFixed(1)}% muscle${e.muscleMassKg.toStringAsFixed(1)}kg lean${e.leanBodyMassKg.toStringAsFixed(1)}kg'
        ).join(', ');
        parts.add('ScaleHistory: $lines');
      }
    }

    // Water / supplements (last 7 days) — ~50 tokens
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

  /// Word-boundary keyword matching — prevents false positives like "seafood"
  /// matching the "food" keyword or "reps" missing "repetitions".
  static bool _has(String query, List<String> keywords) {
    return keywords.any((k) {
      try {
        return RegExp(r'\b' + RegExp.escape(k) + r'\b', caseSensitive: false)
            .hasMatch(query);
      } catch (_) {
        return query.contains(k); // fallback if regex construction fails
      }
    });
  }

  /// Sanitize user input to prevent prompt injection attacks.
  /// Removes/escapes special markers and delimiters that could be used for jailbreaks.
  static String _sanitizeInput(String input) {
    return input
        .replaceAll(RegExp(r'===+'), '==')  // Collapse markers like === or ====
        .replaceAll(RegExp(r'\[SYSTEM:', caseSensitive: false), '[system:')
        .replaceAll(RegExp(r'\[INSTRUCTIONS', caseSensitive: false), '[note')
        .replaceAll(RegExp(r'Ignore all previous'), 'ignore prior')
        .replaceAll('\n\n', '\n')  // Remove blank lines (common jailbreak separator)
        .trim();
  }

  String _systemPrompt(FitnessProvider p) {
    final now = DateTime.now();
    final mo  = ['Jan','Feb','Mar','Apr','May','Jun',
                 'Jul','Aug','Sep','Oct','Nov','Dec'];
    // Include year in all dates so the model can reason about recency
    String d(DateTime dt) => '${dt.day} ${mo[dt.month - 1]} ${dt.year}';

    final wt     = p.latestWeightKg?.toStringAsFixed(1) ?? '?';
    final trend  = p.weeklyWeightChange != null
        ? '${p.weeklyWeightChange!.toStringAsFixed(2)}kg/wk'
        : 'no data';
    final eta    = p.estimatedGoalDate != null
        ? '${d(p.estimatedGoalDate!)}'
        : 'N/A';
    final tdee   = p.bestTdee != null
        ? '${p.bestTdee!.round()}${p.isTdeeCalibrated ? "*" : ""}kcal'
        : 'N/A';
    final cut    = p.fatLossCalorieTarget?.round().toString() ?? 'N/A';
    final kgLeft = p.kgToGoal?.toStringAsFixed(1) ?? 'N/A';
    final pct    = (p.goalProgress * 100).round();

    final buf = StringBuffer();

    // Body composition (only when data exists)
    final sc = p.latestScaleEntry;
    if (sc != null || p.bmi != null) {
      buf.write('Body:');
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

    // Food — last 3 days with individual items (spelled-out meal names)
    buf.writeln('Recent food (3 days):');
    const mealLabel = {'breakfast': 'Breakfast', 'lunch': 'Lunch', 'dinner': 'Dinner', 'snack': 'Snack', 'other': 'Other'};
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
      buf.write('${d(day)}: ${cal}kcal ${prot}g protein');
      final byMeal = <String, List<dynamic>>{};
      for (final e in entries) {
        byMeal.putIfAbsent(e.mealType.toString().split('.').last, () => []).add(e);
      }
      for (final ml in ['breakfast','lunch','dinner','snack','other']) {
        final items = byMeal[ml];
        if (items == null) continue;
        final tag   = mealLabel[ml]!;
        final shown = items.take(3).map((e) => '${e.name}(${e.calories.round()}kcal)').join(' ');
        buf.write(' | $tag: $shown');
      }
      buf.writeln();
    }
    if (!anyFood) buf.writeln('No food logged in last 3 days.');

    // Workouts — last 5
    buf.writeln('Recent workouts (last 5):');
    final allW = [...p.workoutHistory]..sort((a, b) => b.date.compareTo(a.date));
    final rw   = allW.take(5).toList();
    if (rw.isEmpty) {
      buf.writeln('None logged.');
    } else {
      for (final w in rw) {
        final exStr = w.exercises.map((ex) {
          if (ex.sets.isEmpty) return ex.name;
          final best = ex.sets.reduce((a, b) => a.weight >= b.weight ? a : b);
          return '${ex.name} ${best.weight.toStringAsFixed(0)}kg×${best.reps}';
        }).join(', ');
        buf.writeln('${d(w.date)}: ${w.name} — $exStr');
      }
    }

    // Weight — last 5 entries
    final bodyEntries = p.getRecentBodyEntries(days: 60);
    final last5w = bodyEntries.length > 5 ? bodyEntries.sublist(bodyEntries.length - 5) : bodyEntries;
    if (last5w.isNotEmpty) {
      buf.write('Weight log: ');
      buf.writeln(last5w.map((e) => '${d(e.date)} ${e.weightKg.toStringAsFixed(1)}kg').join(', '));
    }

    // Top lifts 1RM — uses cached getter (O(1) after first call)
    final oneRm = p.topLiftsOneRm.entries
        .map((e) => '${e.key} ~${e.value.toStringAsFixed(0)}kg')
        .toList();
    if (oneRm.isNotEmpty) buf.writeln('Best lifts (estimated 1RM): ${oneRm.join(' | ')}');

    // Water & supplements — last 7 days
    final waterH = p.waterHistory;
    final suppH  = p.supplementHistory;
    final wsLines = <String>[];
    for (int i = 0; i < 7; i++) {
      final day = now.subtract(Duration(days: i));
      final key = '${day.year}-${day.month.toString().padLeft(2,'0')}-${day.day.toString().padLeft(2,'0')}';
      final ml   = waterH[key] ?? 0;
      final supp = suppH[key];
      if (ml == 0 && supp == null) continue;
      final w  = supp?.whey        == true ? 'Whey✓' : 'Whey✗';
      final cr = supp?.creatine    == true ? 'Creatine✓' : 'Creatine✗';
      final mv = supp?.multivitamin == true ? 'Multivit✓' : 'Multivit✗';
      wsLines.add('${d(day)}:${ml}ml $w $cr $mv');
    }
    if (wsLines.isNotEmpty) buf.writeln('Water & supplements: ${wsLines.join(' | ')}');

    final sex = p.isMale ? 'Male' : 'Female';
    final safeName = _sanitizeInput(p.userName);

// ── Prompt: rules-first, positive framing, no trailing fragments ──────────
return '''You are $safeName's personal fitness AI coach. Give specific, data-driven advice using the numbers from the reference section below. Start your answer directly — cite $safeName's actual numbers. Keep it concise (2-4 sentences).

=== ${safeName.toUpperCase()}'S REFERENCE DATA (reference only — use to personalise your advice) ===
Profile: ${p.age}y $sex ${p.heightCm.toInt()}cm | Goal weight: ${p.goalWeightKg.toStringAsFixed(1)}kg | Indian diet
Today (${d(now)}): Calories ${p.todayCaloriesTotal.round()}/${p.calorieGoal}kcal | Protein ${p.todayProteinTotal.round()}/${p.proteinGoal}g | Water ${p.todayWaterMl}/${p.waterGoalMl}ml | Steps ${p.todaySteps}/${p.stepGoal} | Gym today: ${p.todayWorkout != null ? 'done' : 'not yet'}
Weight journey: ${wt}kg → ${p.goalWeightKg.toStringAsFixed(1)}kg ($pct% done, ${kgLeft}kg remaining) | Weekly trend: $trend | ETA: $eta
Metabolism: TDEE $tdee | Daily cut target: ${cut}kcal | Habit score: ${p.habitScore}/100 | Workout streak: ${p.workoutStreak}d
${buf.toString().trim()}
=== END REFERENCE DATA ===

Food suggestions: prioritise Indian foods — roti, dal, paneer, eggs, curd, chicken, fish, whey protein.
Start your reply immediately with specific advice using the actual numbers above.''';
  }

  // ── Test hooks ──────────────────────────────────────────────────────────────
  @visibleForTesting
  String buildSystemPromptForTest(FitnessProvider p) => _systemPrompt(p);

  @visibleForTesting
  String buildContextForQueryTest(String query, FitnessProvider p) =>
      _buildContextForQuery(query, p);

  @visibleForTesting
  String buildRichPromptForTest(String firstMessage, FitnessProvider p) =>
      _buildRichSystemPrompt(firstMessage, p);

  @visibleForTesting
  static bool hasKeywordTest(String query, List<String> keywords) =>
      _has(query, keywords);

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
