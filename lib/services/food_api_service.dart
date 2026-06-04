import 'dart:convert';
import 'package:http/http.dart' as http;

/// Nutrition data returned from an external food API, always per 100 g.
class FoodApiResult {
  final String name;
  final double calories100g; // kcal per 100 g
  final double protein100g;  // g per 100 g
  final double carbs100g;    // g per 100 g
  final double fat100g;      // g per 100 g
  final String source;       // e.g. 'OpenFoodFacts'

  const FoodApiResult({
    required this.name,
    required this.calories100g,
    required this.protein100g,
    required this.carbs100g,
    required this.fat100g,
    required this.source,
  });

  double caloriesForGrams(double g) => calories100g * g / 100;
  double proteinForGrams(double g)  => protein100g  * g / 100;
  double carbsForGrams(double g)    => carbs100g    * g / 100;
  double fatForGrams(double g)      => fat100g      * g / 100;
}

/// Searches OpenFoodFacts for food items not found in the local database.
///
/// Priority: local DB first (caller responsibility), then this service.
/// Network errors and timeouts return [] silently — callers handle UX.
class FoodApiService {
  static const _timeout  = Duration(seconds: 8);
  static const _maxItems = 5;
  static const _ua       = 'KFitness/1.0 (Personal fitness tracker; contact@kfitness.app)';

  /// Returns up to [_maxItems] results matching [query], always per 100 g.
  /// Returns [] on network failure, timeout, or parse error.
  static Future<List<FoodApiResult>> search(String query) async {
    final q = query.trim();
    if (q.length < 2) return [];
    try {
      return await _searchOpenFoodFacts(q);
    } catch (_) {
      return [];
    }
  }

  // ── OpenFoodFacts ───────────────────────────────────────────────────────────
  // Endpoint: stable cgi/search.pl JSON API — no key required.
  // cc=in prioritises Indian market products; lc=en requests English names.
  static Future<List<FoodApiResult>> _searchOpenFoodFacts(String query) async {
    final encoded = Uri.encodeComponent(query);
    final uri = Uri.parse(
      'https://world.openfoodfacts.org/cgi/search.pl'
      '?search_terms=$encoded&search_simple=1&action=process'
      '&json=1&page_size=8&cc=in&lc=en'
      '&fields=product_name,nutriments',
    );

    final response = await http
        .get(uri, headers: {'User-Agent': _ua})
        .timeout(_timeout);

    if (response.statusCode != 200) return [];

    final body    = jsonDecode(response.body) as Map<String, dynamic>;
    final products = (body['products'] as List?) ?? [];
    final results  = <FoodApiResult>[];
    final seen     = <String>{};

    for (final raw in products) {
      if (results.length >= _maxItems) break;

      final name = (raw['product_name'] as String?)?.trim() ?? '';
      if (name.isEmpty) continue;

      // Deduplicate by case-insensitive name
      if (!seen.add(name.toLowerCase())) continue;

      final n = raw['nutriments'] as Map<String, dynamic>?;
      if (n == null) continue;

      // OpenFoodFacts uses hyphens in keys: "energy-kcal_100g"
      final cal  = _num(n['energy-kcal_100g']);
      final prot = _num(n['proteins_100g']) ?? 0.0;
      final carb = _num(n['carbohydrates_100g']) ?? 0.0;
      final fat  = _num(n['fat_100g']) ?? 0.0;

      // Skip entries with missing or zero-calorie data (corrupt entries)
      if (cal == null || cal < 1) continue;
      // Sanity clamp — no real food exceeds 9 kcal/g (pure fat ≈ 9 kcal/g)
      if (cal > 900) continue;

      results.add(FoodApiResult(
        name:          name,
        calories100g:  cal,
        protein100g:   prot.clamp(0, 100),
        carbs100g:     carb.clamp(0, 100),
        fat100g:       fat.clamp(0, 100),
        source:        'OpenFoodFacts',
      ));
    }

    return results;
  }

  static double? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
