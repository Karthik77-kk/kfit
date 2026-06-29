import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Nutrition data returned from an external food API, always per 100 g.
class FoodApiResult {
  final String name;
  final double calories100g; // kcal per 100 g
  final double protein100g;  // g per 100 g
  final double carbs100g;    // g per 100 g
  final double fat100g;      // g per 100 g
  final String source;       // 'OpenFoodFacts' | 'USDA' | 'IFCT'
  final String? barcode;     // set for barcode lookups (null for text search)
  final double? servingSizeG; // OFF/USDA declared serving in grams, when known

  const FoodApiResult({
    required this.name,
    required this.calories100g,
    required this.protein100g,
    required this.carbs100g,
    required this.fat100g,
    required this.source,
    this.barcode,
    this.servingSizeG,
  });

  double caloriesForGrams(double g) => calories100g * g / 100;
  double proteinForGrams(double g)  => protein100g  * g / 100;
  double carbsForGrams(double g)    => carbs100g    * g / 100;
  double fatForGrams(double g)      => fat100g      * g / 100;

  Map<String, dynamic> toJson() => {
        'name': name,
        'cal': calories100g,
        'prot': protein100g,
        'carb': carbs100g,
        'fat': fat100g,
        'source': source,
        'barcode': barcode,
        'serving': servingSizeG,
      };

  factory FoodApiResult.fromJson(Map<String, dynamic> j) => FoodApiResult(
        name: (j['name'] as String?) ?? '',
        calories100g: ((j['cal'] as num?) ?? 0).toDouble(),
        protein100g: ((j['prot'] as num?) ?? 0).toDouble(),
        carbs100g: ((j['carb'] as num?) ?? 0).toDouble(),
        fat100g: ((j['fat'] as num?) ?? 0).toDouble(),
        source: (j['source'] as String?) ?? 'OpenFoodFacts',
        barcode: j['barcode'] as String?,
        servingSizeG: (j['serving'] as num?)?.toDouble(),
      );
}

/// Resolves food nutrition from open data sources not covered by the local DB.
///
/// Hierarchy (caller searches the LOCAL set — curated + IFCT — first):
///   text   : OpenFoodFacts → USDA (USDA only when [FDC_API_KEY] is set)
///   barcode: OpenFoodFacts product/{code} → USDA branded-by-UPC → null
///
/// Network errors and timeouts return [] / null silently — callers handle UX.
/// The app builds and runs fully WITHOUT a USDA key (forks / local dev): when
/// the key is empty, every USDA call short-circuits and the other sources still
/// work.
class FoodApiService {
  static const _timeout  = Duration(seconds: 8);
  static const _maxItems = 5;
  static const _ua       = 'KFitness/1.0 (Personal fitness tracker; contact@kfitness.app)';

  /// USDA FoodData Central key — injected at build via
  /// `--dart-define FDC_API_KEY=…`. Empty ⇒ USDA disabled.
  static const String fdcApiKey = String.fromEnvironment('FDC_API_KEY');
  static bool get usdaEnabled => fdcApiKey.isNotEmpty;

  // In-memory caches (process lifetime). Barcodes are also persisted (below).
  static final Map<String, FoodApiResult?> _barcodeMem = {};
  static final Map<String, List<FoodApiResult>> _textMem = {};

  /// OpenFoodFacts-only text search (kept for backward compatibility).
  /// Returns up to [_maxItems] results matching [query], always per 100 g.
  static Future<List<FoodApiResult>> search(String query) async {
    final q = query.trim();
    if (q.length < 2) return [];
    try {
      return await _searchOpenFoodFacts(q);
    } catch (_) {
      return [];
    }
  }

  /// Combined REMOTE text search: races OpenFoodFacts + USDA under one combined
  /// timeout, OFF results ranked ahead of USDA. Returns [] on total failure.
  static Future<List<FoodApiResult>> searchByText(String query) async {
    final q = query.trim();
    if (q.length < 2) return [];
    if (_textMem.containsKey(q.toLowerCase())) return _textMem[q.toLowerCase()]!;
    try {
      // Race both sources; either may fail independently without sinking the other.
      final results = await Future.wait([
        _searchOpenFoodFacts(q).catchError((_) => <FoodApiResult>[]),
        _searchUsdaText(q).catchError((_) => <FoodApiResult>[]),
      ]).timeout(_timeout, onTimeout: () => [<FoodApiResult>[], <FoodApiResult>[]]);
      // OFF first (India market relevance), then USDA — final cross-layer rank
      // happens in food_screen; here we just concatenate in source priority.
      final merged = [...results[0], ...results[1]];
      _textMem[q.toLowerCase()] = merged;
      return merged;
    } catch (_) {
      return [];
    }
  }

  /// Barcode resolution: memory cache → SharedPreferences → OFF → USDA-by-UPC.
  /// Returns one [FoodApiResult] (per 100 g) or null when nothing matches.
  /// A found result is cached (memory + prefs) so repeat scans are instant and
  /// work offline.
  static Future<FoodApiResult?> lookupByBarcode(String code) async {
    final c = code.trim();
    if (c.isEmpty) return null;

    if (_barcodeMem.containsKey(c)) return _barcodeMem[c];

    // Persistent cache (offline-friendly for previously-scanned products).
    final cached = await _readBarcodeCache(c);
    if (cached != null) {
      _barcodeMem[c] = cached;
      return cached;
    }

    FoodApiResult? result;
    try {
      result = await _lookupOffBarcode(c).timeout(_timeout, onTimeout: () => null);
    } catch (_) {
      result = null;
    }
    if (result == null && usdaEnabled) {
      try {
        result = await _lookupUsdaBarcode(c).timeout(_timeout, onTimeout: () => null);
      } catch (_) {
        result = null;
      }
    }

    _barcodeMem[c] = result;
    if (result != null) await _writeBarcodeCache(c, result);
    return result;
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
      '&fields=product_name,nutriments,serving_quantity',
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

      final parsed = _parseOffNutriments(n, name: name,
          servingSizeG: _num(raw['serving_quantity']));
      if (parsed != null) results.add(parsed);
    }

    return results;
  }

  /// OFF barcode endpoint (v2 product API).
  static Future<FoodApiResult?> _lookupOffBarcode(String barcode) async {
    final uri = Uri.parse(
      'https://world.openfoodfacts.org/api/v2/product/$barcode.json'
      '?fields=product_name,brands,nutriments,serving_quantity',
    );
    final response = await http
        .get(uri, headers: {'User-Agent': _ua})
        .timeout(_timeout);
    if (response.statusCode != 200) return null;

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if ((body['status'] as num?)?.toInt() != 1) return null;

    final product = body['product'] as Map<String, dynamic>?;
    if (product == null) return null;

    var name = (product['product_name'] as String?)?.trim() ?? '';
    final brand = (product['brands'] as String?)?.trim() ?? '';
    if (name.isEmpty) name = brand;
    if (name.isEmpty) return null;

    final n = product['nutriments'] as Map<String, dynamic>?;
    if (n == null) return null;

    return _parseOffNutriments(n, name: name, barcode: barcode,
        servingSizeG: _num(product['serving_quantity']));
  }

  /// Shared OFF nutriment parsing + clamps (identical for text + barcode).
  /// Returns null for missing/zero-calorie or implausible entries.
  static FoodApiResult? _parseOffNutriments(
    Map<String, dynamic> n, {
    required String name,
    String? barcode,
    double? servingSizeG,
  }) {
    // OpenFoodFacts uses hyphens in keys: "energy-kcal_100g"
    final cal  = _num(n['energy-kcal_100g']);
    final prot = _num(n['proteins_100g']) ?? 0.0;
    final carb = _num(n['carbohydrates_100g']) ?? 0.0;
    final fat  = _num(n['fat_100g']) ?? 0.0;

    // Skip entries with missing or zero-calorie data (corrupt entries)
    if (cal == null || cal < 1) return null;
    // Sanity clamp — no real food exceeds 9 kcal/g (pure fat ≈ 9 kcal/g)
    if (cal > 900) return null;

    return FoodApiResult(
      name:          name,
      calories100g:  cal,
      protein100g:   prot.clamp(0, 100),
      carbs100g:     carb.clamp(0, 100),
      fat100g:       fat.clamp(0, 100),
      source:        'OpenFoodFacts',
      barcode:       barcode,
      servingSizeG:  (servingSizeG != null && servingSizeG > 0) ? servingSizeG : null,
    );
  }

  // ── USDA FoodData Central ────────────────────────────────────────────────────
  // Only ever called when [usdaEnabled]. Nutrient numbers (per 100 g):
  //   208 = energy (kcal), 203 = protein, 204 = total fat, 205 = carbohydrate.
  static const _usdaBase = 'https://api.nal.usda.gov/fdc/v1';

  static Future<List<FoodApiResult>> _searchUsdaText(String query) async {
    if (!usdaEnabled) return [];
    final uri = Uri.parse(
      '$_usdaBase/foods/search'
      '?api_key=$fdcApiKey'
      '&query=${Uri.encodeComponent(query)}'
      '&pageSize=5'
      '&dataType=${Uri.encodeComponent('Foundation,SR Legacy,Branded')}',
    );
    final response = await http
        .get(uri, headers: {'User-Agent': _ua})
        .timeout(_timeout);
    if (response.statusCode != 200) return [];

    final body  = jsonDecode(response.body) as Map<String, dynamic>;
    final foods = (body['foods'] as List?) ?? [];
    final out   = <FoodApiResult>[];
    final seen  = <String>{};
    for (final raw in foods) {
      if (out.length >= _maxItems) break;
      final r = _parseUsdaFood(raw as Map<String, dynamic>);
      if (r == null) continue;
      if (!seen.add(r.name.toLowerCase())) continue;
      out.add(r);
    }
    return out;
  }

  /// USDA UPC fallback — match exact `gtinUpc` against the scanned barcode.
  static Future<FoodApiResult?> _lookupUsdaBarcode(String barcode) async {
    if (!usdaEnabled) return null;
    final uri = Uri.parse(
      '$_usdaBase/foods/search'
      '?api_key=$fdcApiKey'
      '&query=${Uri.encodeComponent(barcode)}'
      '&dataType=Branded',
    );
    final response = await http
        .get(uri, headers: {'User-Agent': _ua})
        .timeout(_timeout);
    if (response.statusCode != 200) return null;

    final body  = jsonDecode(response.body) as Map<String, dynamic>;
    final foods = (body['foods'] as List?) ?? [];
    for (final raw in foods) {
      final m = raw as Map<String, dynamic>;
      final upc = (m['gtinUpc'] as String?)?.trim();
      if (upc != barcode) continue;
      final r = _parseUsdaFood(m, barcode: barcode);
      if (r != null) return r;
    }
    return null;
  }

  /// Maps one USDA food object → per-100g [FoodApiResult] via nutrient numbers.
  static FoodApiResult? _parseUsdaFood(Map<String, dynamic> m, {String? barcode}) {
    final name = (m['description'] as String?)?.trim() ?? '';
    if (name.isEmpty) return null;

    final nutrients = (m['foodNutrients'] as List?) ?? [];
    double? cal;
    double prot = 0, fat = 0, carb = 0;
    for (final raw in nutrients) {
      final n = raw as Map<String, dynamic>;
      // Search results expose `nutrientNumber` + `value`.
      final number = (n['nutrientNumber'] ?? n['number'])?.toString();
      final value = _num(n['value'] ?? n['amount']);
      if (number == null || value == null) continue;
      switch (number) {
        case '208':
          cal = value;
          break;
        case '203':
          prot = value;
          break;
        case '204':
          fat = value;
          break;
        case '205':
          carb = value;
          break;
      }
    }

    if (cal == null || cal < 1) return null;
    if (cal > 900) return null;

    return FoodApiResult(
      name:          name,
      calories100g:  cal,
      protein100g:   prot.clamp(0, 100),
      carbs100g:     carb.clamp(0, 100),
      fat100g:       fat.clamp(0, 100),
      source:        'USDA',
      barcode:       barcode,
      servingSizeG:  _num(m['servingSize']),
    );
  }

  // ── Barcode cache (SharedPreferences) ────────────────────────────────────────
  static String _cacheKey(String barcode) => 'food_cache_$barcode';

  static Future<FoodApiResult?> _readBarcodeCache(String barcode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_cacheKey(barcode));
      if (json == null) return null;
      return FoodApiResult.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeBarcodeCache(String barcode, FoodApiResult r) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey(barcode), jsonEncode(r.toJson()));
    } catch (_) {/* cache write is best-effort */}
  }

  static double? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
