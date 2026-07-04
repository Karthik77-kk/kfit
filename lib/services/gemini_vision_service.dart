import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// One food/drink item detected in a meal photo, with a portion estimate and
/// the nutrition for THAT portion (not per-100 g). The on-device food resolver
/// (local DB / IFCT / OFF / USDA) can refine a name later; this is the raw
/// vision result the user confirms.
class ScannedFood {
  final String name;
  final double grams;
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
  final double confidence; // 0..1

  const ScannedFood({
    required this.name,
    required this.grams,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.confidence,
  });

  ScannedFood copyWith({
    String? name,
    double? grams,
    double? kcal,
    double? protein,
    double? carbs,
    double? fat,
  }) =>
      ScannedFood(
        name: name ?? this.name,
        grams: grams ?? this.grams,
        kcal: kcal ?? this.kcal,
        protein: protein ?? this.protein,
        carbs: carbs ?? this.carbs,
        fat: fat ?? this.fat,
        confidence: confidence,
      );
}

/// Thrown for user-facing failures (network, quota, config). [message] is safe
/// to show directly in a SnackBar/dialog.
class GeminiException implements Exception {
  final String message;
  const GeminiException(this.message);
  @override
  String toString() => message;
}

/// Sends a meal photo to Gemini (free-tier Flash, vision) and returns the
/// recognised foods with portion + macros. Key is injected at build time via
/// `--dart-define GEMINI_API_KEY=...` (never committed) — mirrors HF_TOKEN.
class GeminiVisionService {
  static const String _key = String.fromEnvironment('GEMINI_API_KEY');
  static const String _model = 'gemini-2.5-flash';
  static const Duration _timeout = Duration(seconds: 30);

  /// True when a key is compiled in. When false the UI hides/disables the scan.
  static bool get isConfigured => _key.isNotEmpty;

  // Tight, structured prompt → accurate names, per-portion macros, and a
  // realistic gram estimate. Indian-food aware. JSON is enforced by
  // response_mime_type so parsing is reliable.
  static const String _prompt = '''
You are a nutrition vision expert analysing a photo of a meal (often Indian food).
Identify EVERY distinct food or drink item visible.
For each item return:
- "name": common name, preferring the common Indian name where it applies
  (e.g. "Dosa", "Sambar", "Chapati", "Paneer Butter Masala", "Curd Rice"). Keep it short and specific.
- "grams": realistic estimate of the EDIBLE portion in grams. Use plate/bowl size,
  utensils, and typical Indian serving sizes as scale references.
- "kcal", "protein_g", "carb_g", "fat_g": nutrition for THAT estimated portion (NOT per 100 g).
- "confidence": 0.0-1.0 for the identification.
Guidelines:
- Merge a single dish into one item (a plate of rice = one "Rice" entry).
- Ignore plates, cutlery, napkins, garnish that is not eaten.
- Be accurate on macros: cross-check kcal against protein*4 + carb*4 + fat*9 for the portion.
- If there is no food in the image, return an empty array.
Output ONLY a JSON array, no prose, no markdown fences.
Schema: [{"name":string,"grams":number,"kcal":number,"protein_g":number,"carb_g":number,"fat_g":number,"confidence":number}]
''';

  /// Analyses [jpegBytes] and returns detected foods (may be empty).
  /// Throws [GeminiException] with a user-safe message on failure.
  static Future<List<ScannedFood>> analyze(Uint8List jpegBytes) async {
    if (!isConfigured) {
      throw const GeminiException('AI photo analysis isn\'t set up in this build.');
    }
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_key',
    );
    final payload = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': _prompt},
            {
              'inline_data': {
                'mime_type': 'image/jpeg',
                'data': base64Encode(jpegBytes),
              }
            },
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.2,
        'response_mime_type': 'application/json',
      },
    });

    final http.Response resp;
    try {
      resp = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: payload)
          .timeout(_timeout);
    } catch (_) {
      throw const GeminiException('No connection — check your internet and try again.');
    }

    if (resp.statusCode == 429) {
      throw const GeminiException('AI is busy right now. Please try again in a minute.');
    }
    if (resp.statusCode == 400 || resp.statusCode == 403) {
      throw const GeminiException('AI photo analysis is unavailable (key/quota issue).');
    }
    if (resp.statusCode != 200) {
      throw GeminiException('Analysis failed (${resp.statusCode}). Try again.');
    }

    final text = _extractText(jsonDecode(resp.body));
    if (text == null || text.trim().isEmpty) return const [];
    return _parseFoods(text);
  }

  /// Test hook — parse a raw model text response into foods.
  @visibleForTesting
  static List<ScannedFood> parseForTest(String modelText) =>
      _parseFoods(modelText);

  static String? _extractText(dynamic decoded) {
    try {
      final cands = (decoded as Map)['candidates'] as List?;
      if (cands == null || cands.isEmpty) return null;
      final parts = (cands.first['content']?['parts']) as List?;
      if (parts == null || parts.isEmpty) return null;
      return parts.first['text'] as String?;
    } catch (_) {
      return null;
    }
  }

  static List<ScannedFood> _parseFoods(String text) {
    var s = text.trim();
    final start = s.indexOf('[');
    final end = s.lastIndexOf(']');
    if (start == -1 || end == -1 || end < start) return const [];
    s = s.substring(start, end + 1);

    final List list;
    try {
      list = jsonDecode(s) as List;
    } catch (_) {
      return const [];
    }

    double num0(dynamic v) => (v is num) ? v.toDouble() : (double.tryParse('$v') ?? 0);
    final out = <ScannedFood>[];
    for (final raw in list) {
      if (raw is! Map) continue;
      final name = (raw['name'] as String?)?.trim() ?? '';
      if (name.isEmpty) continue;
      final kcal = num0(raw['kcal']);
      if (kcal <= 0 || kcal > 5000) continue; // reject junk
      out.add(ScannedFood(
        name: name,
        grams: num0(raw['grams']).clamp(0, 2000).toDouble(),
        kcal: kcal,
        protein: num0(raw['protein_g']).clamp(0, 300).toDouble(),
        carbs: num0(raw['carb_g']).clamp(0, 500).toDouble(),
        fat: num0(raw['fat_g']).clamp(0, 300).toDouble(),
        confidence: num0(raw['confidence']).clamp(0, 1).toDouble(),
      ));
    }
    return out;
  }
}
