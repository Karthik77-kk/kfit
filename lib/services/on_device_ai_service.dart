import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/fitness_provider.dart';

/// States the AI model can be in.
enum AiModelState {
  notInstalled, // model file not on device yet
  downloading,  // actively downloading
  loading,      // file exists, loading into NPU/GPU memory
  ready,        // model in memory, chat available
  error,        // something went wrong
}

/// Manages the on-device Gemma 3 1B INT4 model lifecycle and chat sessions.
///
/// Model: Gemma 3 1B IT INT4 .litertlm (~600 MB)
/// Backend: Snapdragon 8 Gen 2 Hexagon NPU via LiteRT-LM (PreferredBackend.npu)
/// Framework: flutter_gemma 0.16.x
class OnDeviceAiService extends ChangeNotifier {
  static const _prefToken = 'hf_token_ai_chat';

  // Gemma 3 1B IT INT4 LiteRT-LM format — smallest capable model (~550 MB).
  // Requires a free HuggingFace account + accepting the Gemma 3 license on
  // litert-community/Gemma3-1B-IT before download.
  // NOTE: filename is `gemma3-1b-it-int4` (no hyphen after "gemma") — the
  // hyphenated form 404s. Verified against the HF repo file listing.
  static const _modelUrl =
      'https://huggingface.co/litert-community/Gemma3-1B-IT'
      '/resolve/main/gemma3-1b-it-int4.litertlm';

  AiModelState _state      = AiModelState.notInstalled;
  double       _dlProgress = 0.0; // 0.0–1.0
  String       _error      = '';
  String       _hfToken    = '';

  InferenceModel? _model;
  InferenceChat?  _chat;

  // ── Public getters ──────────────────────────────────────────────────────────
  AiModelState get state        => _state;
  double       get dlProgress   => _dlProgress;
  String       get errorMessage => _error;
  String       get hfToken      => _hfToken;
  bool         get isReady      => _state == AiModelState.ready;
  bool         get hasToken     => _hfToken.isNotEmpty;

  /// Call once at app startup. Tries to pick up an already-installed model.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _hfToken = prefs.getString(_prefToken) ?? '';

    try {
      await FlutterGemma.initialize(huggingFaceToken: _hfToken);
      if (FlutterGemma.hasActiveModel()) {
        await _loadModel();
      }
    } catch (e) {
      _state = AiModelState.notInstalled;
      notifyListeners();
    }
  }

  Future<void> saveToken(String token) async {
    _hfToken = token.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefToken, _hfToken);
    notifyListeners();
  }

  /// Download Gemma 3 1B INT4 from HuggingFace, then load it.
  Future<void> downloadAndLoad() async {
    if (_hfToken.isEmpty) {
      _setState(AiModelState.error, error: 'Enter your HuggingFace token first.');
      return;
    }
    try {
      _dlProgress = 0;
      _setState(AiModelState.downloading);

      await FlutterGemma.initialize(huggingFaceToken: _hfToken);
      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
        fileType:  ModelFileType.litertlm,
      )
          .fromNetwork(_modelUrl, token: _hfToken)
          .withProgress((pct) {
            _dlProgress = (pct / 100.0).clamp(0.0, 1.0);
            notifyListeners();
          })
          .install();

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
        maxTokens:        1024,
        preferredBackend: PreferredBackend.npu, // Snapdragon 8 Gen 2 Hexagon NPU
      );
      _setState(AiModelState.ready);
    } catch (e) {
      _setState(AiModelState.error, error: 'Failed to load model: $e');
    }
  }

  /// Clear conversation so the next message starts a fresh session.
  void resetConversation() {
    _chat = null;
    notifyListeners();
  }

  /// Send [userMessage] and stream the AI response token-by-token.
  /// The system prompt is rebuilt from live [provider] data on each new conversation.
  Stream<String> sendMessage(String userMessage, FitnessProvider provider) async* {
    if (_model == null) {
      yield 'Model is not loaded. Please reopen the chat.';
      return;
    }
    try {
      // New chat session on first message or after reset.
      _chat ??= await _model!.createChat(
        systemInstruction: _systemPrompt(provider),
        temperature:       0.7,
        topK:              40,
        randomSeed:        42,
        tokenBuffer:       256,
      );

      await _chat!.addQueryChunk(
        Message(text: userMessage, isUser: true),
      );

      await for (final response in _chat!.generateChatResponseAsync()) {
        if (response is TextResponse) yield response.token;
      }
    } catch (e) {
      yield '\n\n[Error: $e]';
    }
  }

  // ── System prompt ───────────────────────────────────────────────────────────

  String _systemPrompt(FitnessProvider p) {
    final now    = DateTime.now();
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    final date   = '${now.day} ${months[now.month - 1]} ${now.year}';

    final weight = p.latestWeightKg?.toStringAsFixed(1) ?? 'not logged';
    final trend  = p.weeklyWeightChange != null
        ? '${p.weeklyWeightChange!.toStringAsFixed(2)} kg/week'
        : 'no trend yet';
    final eta    = p.estimatedGoalDate != null
        ? '${p.estimatedGoalDate!.day} ${months[p.estimatedGoalDate!.month - 1]} ${p.estimatedGoalDate!.year}'
        : 'no ETA yet';
    final kgLeft = p.kgToGoal?.toStringAsFixed(1) ?? 'N/A';
    final tdee   = p.bestTdee != null
        ? '${p.bestTdee!.round()} kcal/day${p.isTdeeCalibrated ? " (calibrated from real data)" : " (estimated)"}'
        : 'not enough data';
    final cutTarget = p.fatLossCalorieTarget != null
        ? '${p.fatLossCalorieTarget!.round()} kcal/day'
        : 'N/A';

    return '''You are ${p.userName}'s personal on-device fitness AI coach. Today is $date.

PROFILE
Age ${p.age} · ${p.heightCm.toInt()} cm · Goal: lose fat to ${p.goalWeightKg.toStringAsFixed(1)} kg · Indian diet

TODAY
Calories  ${p.todayCaloriesTotal.round()} / ${p.calorieGoal} kcal (${(p.calorieProgress * 100).round()}%)
Protein   ${p.todayProteinTotal.round()} / ${p.proteinGoal} g  (${(p.proteinProgress * 100).round()}%)
Water     ${p.todayWaterMl} / ${p.waterGoalMl} ml (${(p.waterProgress * 100).round()}%)
Steps     ${p.todaySteps} / ${p.stepGoal}  (${(p.stepProgress * 100).round()}%)
Workout   ${p.todayWorkout != null ? 'done' : 'not done'}

METABOLISM
Maintenance (TDEE)  $tdee
Fat-loss target     $cutTarget (for ~0.5 kg/week loss)

7-DAY AVERAGES
Calories  ${p.avgCaloriesForDays(1, 7).round()} kcal/day
Protein   ${p.avgProteinForDays(1, 7).round()} g/day
Weight trend  $trend

BODY
Current weight  $weight kg
Goal weight     ${p.goalWeightKg.toStringAsFixed(1)} kg
Remaining       $kgLeft kg
Estimated goal date  $eta

HABITS (last 30 days)
Habit score       ${p.habitScore}/100
Deficit streak    ${p.deficitStreak} days
Calorie adherence ${(p.calorieAdherenceRate * 100).round()}%
Protein adherence ${(p.proteinAdherenceRate * 100).round()}%
Late-night eating ${p.hasLateNightEatingPattern ? 'pattern detected (>9 PM)' : 'none'}
Days since last workout  ${p.daysSinceLastWorkout == 999 ? 'never' : p.daysSinceLastWorkout == 0 ? 'today' : '${p.daysSinceLastWorkout}d ago'}

RULES
- Answer in 2-4 sentences unless more detail is explicitly asked.
- Reference his actual numbers above — never make up data.
- Suggest Indian foods: rotis, dal, paneer, eggs, sabji, rice, curd, whey shake.
- Be direct, specific, and actionable.''';
  }

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
