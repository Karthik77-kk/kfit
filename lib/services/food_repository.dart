import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/models.dart';
import 'food_api_service.dart';

/// One row in the unified, cross-layer food search list. Wraps either a LOCAL
/// [FoodItem] (curated DB or bundled IFCT) or a REMOTE [FoodApiResult]
/// (OpenFoodFacts / USDA) so a single ranked list can span all four sources
/// while each row still routes to the correct add flow.
class UnifiedFoodResult {
  final FoodItem? local;       // curated or IFCT
  final FoodApiResult? remote; // OpenFoodFacts or USDA

  const UnifiedFoodResult.fromLocal(FoodItem this.local) : remote = null;
  const UnifiedFoodResult.fromRemote(FoodApiResult this.remote) : local = null;

  String get name => local?.name ?? remote!.name;
  String get source => local?.source ?? remote!.source;
  bool get isLocal => local != null;
}

/// Source ranking — lower is better: curated DB > IFCT > OFF > USDA.
int sourceRank(String source) {
  switch (source) {
    case 'curated':
      return 0;
    case 'IFCT':
      return 1;
    case 'OpenFoodFacts':
      return 2;
    case 'USDA':
      return 3;
    default:
      return 4;
  }
}

/// Collapses a food name/query to a comparison key: lowercase, with every
/// non-alphanumeric char (spaces, hyphens, punctuation) removed. So "Ice-cream",
/// "ice cream" and "  icecream " all map to "icecream".
String normalizeFood(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');

/// Levenshtein edit distance (two-row, small strings).
int _levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  var curr = List<int>.filled(b.length + 1, 0);
  for (var i = 0; i < a.length; i++) {
    curr[0] = i + 1;
    for (var j = 0; j < b.length; j++) {
      final cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
      final del = prev[j + 1] + 1, ins = curr[j] + 1, sub = prev[j] + cost;
      curr[j + 1] =
          del < ins ? (del < sub ? del : sub) : (ins < sub ? ins : sub);
    }
    final tmp = prev;
    prev = curr;
    curr = tmp;
  }
  return prev[b.length];
}

/// Relevance of [name] to a pre-normalized query [qNorm]; lower is better,
/// `null` = no match. Punctuation/space-insensitive with token-level fuzzy
/// matching, so "icecream" ranks "Ice-cream" and "palov" still finds "Pulav".
///   0   exact (normalized)   1   name prefix   1.5 word prefix
///   2   substring            3+d fuzzy (edit distance d)   8 category only
double? foodMatchScore(String name, String qNorm, {String? category}) {
  if (qNorm.isEmpty) return null;
  final n = normalizeFood(name);
  if (n.isEmpty) return null;
  if (n == qNorm) return 0;
  if (n.startsWith(qNorm)) return 1;

  final tokens = name.toLowerCase().split(RegExp(r'[^a-z0-9]+'))
    ..removeWhere((t) => t.isEmpty);
  for (final t in tokens) {
    if (t.startsWith(qNorm)) return 1.5;
  }
  if (n.contains(qNorm)) return 2;

  // Fuzzy — tolerance grows with query length (catches typos/transpositions).
  final tol = qNorm.length <= 4 ? 1 : (qNorm.length <= 7 ? 2 : 3);
  var best = double.infinity;
  void note(int d) {
    if (d <= tol && 3 + d < best) best = 3 + d.toDouble();
  }
  note(_levenshtein(n, qNorm));
  for (final t in tokens) {
    note(_levenshtein(t, qNorm));
  }
  if (best.isFinite) return best;

  if (category != null && normalizeFood(category).contains(qNorm)) return 8;
  return null;
}

/// Cross-layer dedupe + rank for the Add-Food list.
///
/// Orders by relevance to [query] (see [foodMatchScore]) first, then source
/// (`curated > IFCT > OpenFoodFacts > USDA`). Deduplicates by normalized name
/// (a curated-vs-IFCT clash keeps the curated row — nicer household serving).
/// Stable within a tie so the caller's input order is preserved. Caps at [cap].
List<UnifiedFoodResult> mergeFoodResults(
  String query,
  List<UnifiedFoodResult> candidates, {
  int cap = 8,
}) {
  final qNorm = normalizeFood(query);

  double scoreOf(UnifiedFoodResult r) => foodMatchScore(r.name, qNorm) ?? 50.0;

  final order = List<int>.generate(candidates.length, (i) => i);
  order.sort((a, b) {
    final sa = scoreOf(candidates[a]), sb = scoreOf(candidates[b]);
    if (sa != sb) return sa.compareTo(sb);
    final ra = sourceRank(candidates[a].source);
    final rb = sourceRank(candidates[b].source);
    if (ra != rb) return ra.compareTo(rb);
    return a.compareTo(b); // stable tie-break — preserve caller order
  });

  final seen = <String>{};
  final out = <UnifiedFoodResult>[];
  for (final i in order) {
    final r = candidates[i];
    final key = normalizeFood(r.name);
    if (key.isEmpty) continue;
    if (seen.add(key)) out.add(r);
    if (out.length >= cap) break;
  }
  return out;
}

/// Holds the bundled offline Indian food source (IFCT 2017) loaded once at
/// startup, and provides the LOCAL (offline) search that merges it with the
/// curated [kFoodDatabase].
class FoodRepository {
  FoodRepository._();
  static final FoodRepository instance = FoodRepository._();

  List<FoodItem> _ifct = const [];
  bool _loaded = false;

  /// All IFCT foods (per 100 g), empty until [ensureLoaded] completes.
  List<FoodItem> get ifctFoods => _ifct;
  bool get isLoaded => _loaded;

  /// Loads `assets/data/ifct_2017.json` once. Failures leave [ifctFoods] empty
  /// (the app still works with the curated DB + remote sources).
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString('assets/data/ifct_2017.json');
      _ifct = parseIfct(raw);
    } catch (_) {
      _ifct = const [];
    }
    _loaded = true;
  }

  /// Test seam — parse a raw JSON string directly (no asset bundle).
  void loadFromJsonString(String raw) {
    _ifct = parseIfct(raw);
    _loaded = true;
  }

  /// Maps the IFCT asset rows → per-100g [FoodItem]s (source 'IFCT').
  ///
  /// kcal in the asset is ALREADY converted from kJ (÷4.184 happens in the
  /// one-off generation script) — read it directly. The `cal<1` / `cal>900`
  /// clamp is re-applied here as a guard against any bad row.
  static List<FoodItem> parseIfct(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    final out = <FoodItem>[];
    for (final e in decoded) {
      if (e is! Map) continue;
      final name = (e['name'] as String?)?.trim() ?? '';
      if (name.isEmpty) continue;
      final kcal = _num(e['kcal']);
      if (kcal == null || kcal < 1 || kcal > 900) continue; // guard bad rows
      final group = (e['group'] as String?)?.trim();
      out.add(FoodItem(
        name: name,
        calories: kcal,
        protein: (_num(e['protein']) ?? 0).clamp(0, 100),
        carbs: (_num(e['carb']) ?? 0).clamp(0, 100),
        fat: (_num(e['fat']) ?? 0).clamp(0, 100),
        category: (group == null || group.isEmpty) ? 'IFCT' : group,
        emoji: '🇮🇳',
        serving: '100 g',
        source: 'IFCT',
      ));
    }
    return out;
  }

  /// LOCAL (offline) text search: curated DB first, then IFCT, fuzzy-matched and
  /// sorted by relevance (see [foodMatchScore]). Deduplicates by normalized name
  /// keeping the curated row on a clash. Returns up to [cap] [FoodItem]s (the
  /// final cross-layer cap is applied later by [mergeFoodResults]).
  List<FoodItem> searchLocal(String query, {int cap = 40}) {
    final qNorm = normalizeFood(query);
    if (qNorm.isEmpty) return const [];

    final seen = <String>{};
    final scored = <(double, int, FoodItem)>[]; // (score, insertion order, item)
    var order = 0;

    void consider(FoodItem f) {
      final s = foodMatchScore(f.name, qNorm, category: f.category);
      if (s == null) return;
      final key = normalizeFood(f.name);
      // Non-matches never consume the key, so curated (added first) wins a clash.
      if (key.isEmpty || !seen.add(key)) return;
      scored.add((s, order++, f));
    }

    // Curated: specific categories before 'Popular' (existing specificity rule).
    for (final f in kFoodDatabase) {
      if (f.category != 'Popular') consider(f);
    }
    for (final f in kFoodDatabase) {
      if (f.category == 'Popular') consider(f);
    }
    // IFCT only fills gaps — a curated name already seen wins.
    for (final f in _ifct) {
      consider(f);
    }

    scored.sort((a, b) {
      if (a.$1 != b.$1) return a.$1.compareTo(b.$1);
      return a.$2.compareTo(b.$2); // stable — preserve curated-first order
    });
    final out = [for (final e in scored) e.$3];
    return out.length > cap ? out.sublist(0, cap) : out;
  }

  static double? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
