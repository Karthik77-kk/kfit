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

/// Cross-layer dedupe + rank for the Add-Food list.
///
/// Ranking: `exact-name-match > curated DB > IFCT > OpenFoodFacts > USDA`.
/// Deduplicates by normalized lowercase name (a curated-vs-IFCT clash keeps the
/// curated row — nicer household serving). Stable within a bucket so the
/// caller's input order is preserved. Caps the result at [cap].
List<UnifiedFoodResult> mergeFoodResults(
  String query,
  List<UnifiedFoodResult> candidates, {
  int cap = 8,
}) {
  final q = query.trim().toLowerCase();

  int rankOf(UnifiedFoodResult r) {
    final exact = r.name.trim().toLowerCase() == q ? 0 : 1;
    // exact (0) always outranks non-exact (10+); source breaks ties within.
    return exact * 10 + sourceRank(r.source);
  }

  final order = List<int>.generate(candidates.length, (i) => i);
  order.sort((a, b) {
    final c = rankOf(candidates[a]).compareTo(rankOf(candidates[b]));
    if (c != 0) return c;
    return a.compareTo(b); // stable tie-break — preserve caller order
  });

  final seen = <String>{};
  final out = <UnifiedFoodResult>[];
  for (final i in order) {
    final r = candidates[i];
    final n = r.name.trim().toLowerCase();
    if (n.isEmpty) continue;
    if (seen.add(n)) out.add(r);
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

  /// LOCAL (offline) text search: curated DB first, then IFCT. Deduplicates by
  /// name keeping the curated row on a clash. Returns up to [cap] [FoodItem]s
  /// (the final cross-layer cap is applied later by [mergeFoodResults]).
  List<FoodItem> searchLocal(String query, {int cap = 40}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    bool matches(FoodItem f) =>
        f.name.toLowerCase().contains(q) || f.category.toLowerCase().contains(q);

    final seen = <String>{};
    final results = <FoodItem>[];

    // Curated: specific categories before 'Popular' (existing specificity rule).
    for (final f in kFoodDatabase) {
      if (f.category == 'Popular') continue;
      if (matches(f) && seen.add(f.name.toLowerCase())) results.add(f);
    }
    for (final f in kFoodDatabase) {
      if (f.category != 'Popular') continue;
      if (matches(f) && seen.add(f.name.toLowerCase())) results.add(f);
    }
    // IFCT only fills gaps — a curated name already seen wins.
    for (final f in _ifct) {
      if (matches(f) && seen.add(f.name.toLowerCase())) results.add(f);
    }

    return results.length > cap ? results.sublist(0, cap) : results;
  }

  static double? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
