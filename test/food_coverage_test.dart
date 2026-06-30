import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:kfit/models/models.dart';
import 'package:kfit/services/food_api_service.dart';
import 'package:kfit/services/food_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Food coverage overhaul — IFCT (offline) + OpenFoodFacts barcode + USDA.
/// Covers: IFCT load + per-100g mapping, cross-layer dedupe/rank, OFF barcode
/// & search mappers, USDA nutrient-number mapping & UPC fallback, the empty-key
/// USDA gate, and the offline barcode cache.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── Task 0: IFCT load + per-100g mapping ───────────────────────────────────
  group('IFCT parse', () {
    const raw = '''
    [
      {"code":"A003","name":"Bajra","group":"Cereals and Millets","kcal":348,"protein":11.0,"carb":61.8,"fat":5.4},
      {"code":"S010","name":"Tiger prawns","group":"Fresh Water Fish and Shellfish","kcal":68,"protein":14.2,"carb":0.0,"fat":0.7},
      {"code":"BAD1","name":"Zero food","group":"X","kcal":0,"protein":0,"carb":0,"fat":0},
      {"code":"BAD2","name":"Impossible","group":"X","kcal":9999,"protein":0,"carb":0,"fat":0},
      {"code":"BAD3","name":"","group":"X","kcal":100,"protein":1,"carb":1,"fat":1}
    ]''';

    test('maps kcal directly (no second ÷4.184) with per-100g serving + source',
        () {
      final items = FoodRepository.parseIfct(raw);
      final bajra = items.firstWhere((f) => f.name == 'Bajra');
      expect(bajra.calories, 348); // read straight from the asset
      expect(bajra.protein, 11.0);
      expect(bajra.carbs, 61.8);
      expect(bajra.fat, 5.4);
      expect(bajra.serving, '100 g');
      expect(bajra.source, 'IFCT');
      expect(bajra.category, 'Cereals and Millets');
    });

    test('drops rows failing the cal<1 / cal>900 / empty-name guard', () {
      final items = FoodRepository.parseIfct(raw);
      final names = items.map((f) => f.name).toList();
      expect(names, contains('Bajra'));
      expect(names, contains('Tiger prawns'));
      expect(names, isNot(contains('Zero food'))); // kcal 0
      expect(names, isNot(contains('Impossible'))); // kcal 9999
      expect(items.where((f) => f.name.isEmpty), isEmpty); // empty name
      expect(items.length, 2);
    });

    test('searchLocal surfaces an IFCT food absent from the curated DB', () {
      final repo = FoodRepository.instance;
      repo.loadFromJsonString(raw);
      // "Bajra" is not in the curated kFoodDatabase but IS in IFCT.
      expect(kFoodDatabase.any((f) => f.name.toLowerCase() == 'bajra'), isFalse);
      final hits = repo.searchLocal('bajra');
      expect(hits.any((f) => f.name == 'Bajra' && f.source == 'IFCT'), isTrue);
    });
  });

  // ── Task 4: cross-layer dedupe + rank ──────────────────────────────────────
  group('mergeFoodResults', () {
    FoodItem curated(String n) =>
        FoodItem(name: n, calories: 100, protein: 5, category: 'Popular', emoji: '🍚');
    FoodItem ifct(String n) => FoodItem(
        name: n, calories: 120, protein: 6, category: 'IFCT', emoji: '🇮🇳',
        serving: '100 g', source: 'IFCT');
    FoodApiResult off(String n) => FoodApiResult(
        name: n, calories100g: 90, protein100g: 4, carbs100g: 10, fat100g: 1,
        source: 'OpenFoodFacts');
    FoodApiResult usda(String n) => FoodApiResult(
        name: n, calories100g: 95, protein100g: 4, carbs100g: 9, fat100g: 1,
        source: 'USDA');

    test('orders exact > curated > IFCT > OFF > USDA', () {
      final merged = mergeFoodResults('dal', [
        UnifiedFoodResult.fromRemote(usda('Dal makhani')),
        UnifiedFoodResult.fromRemote(off('Dal tadka')),
        UnifiedFoodResult.fromLocal(ifct('Dal cooked')),
        UnifiedFoodResult.fromLocal(curated('Dal paneer')),
        UnifiedFoodResult.fromLocal(curated('Dal')), // exact match
      ]);
      expect(merged.first.name, 'Dal'); // exact wins outright
      expect(merged.map((r) => r.source).toList(),
          ['curated', 'curated', 'IFCT', 'OpenFoodFacts', 'USDA']);
    });

    test('curated-vs-IFCT name clash keeps the curated row', () {
      final merged = mergeFoodResults('roti', [
        UnifiedFoodResult.fromLocal(ifct('Roti')),
        UnifiedFoodResult.fromLocal(curated('Roti')),
      ]);
      expect(merged.length, 1);
      expect(merged.single.source, 'curated');
    });

    test('dedupes by normalized name and caps the list', () {
      final candidates = [
        for (var i = 0; i < 12; i++)
          UnifiedFoodResult.fromRemote(off('Food $i')),
        UnifiedFoodResult.fromRemote(off('FOOD 0')), // case-insensitive dup
      ];
      final merged = mergeFoodResults('food', candidates, cap: 8);
      expect(merged.length, 8); // 12 distinct names, capped at 8
      expect(merged.map((r) => r.name.toLowerCase()).toSet().length, 8);
    });

    test('case-insensitive dedupe drops the duplicate', () {
      final merged = mergeFoodResults('milk', [
        UnifiedFoodResult.fromRemote(off('Milk')),
        UnifiedFoodResult.fromRemote(usda('MILK')),
      ]);
      expect(merged.length, 1);
      expect(merged.single.source, 'OpenFoodFacts'); // OFF outranks USDA
    });
  });

  // ── Task 2: OpenFoodFacts mappers ──────────────────────────────────────────
  group('OpenFoodFacts mapping', () {
    test('barcode product (status 1) → per-100g + serving_quantity', () {
      final body = jsonDecode('''
      {
        "status": 1,
        "product": {
          "product_name": "Parle-G Biscuits",
          "brands": "Parle",
          "serving_quantity": 18.4,
          "nutriments": {
            "energy-kcal_100g": 456,
            "proteins_100g": 7.2,
            "carbohydrates_100g": 75.5,
            "fat_100g": 13.1
          }
        }
      }''') as Map<String, dynamic>;
      final r = FoodApiService.parseOffProductBody(body, '8901234567890');
      expect(r, isNotNull);
      expect(r!.name, 'Parle-G Biscuits');
      expect(r.calories100g, 456);
      expect(r.protein100g, 7.2);
      expect(r.carbs100g, 75.5);
      expect(r.fat100g, 13.1);
      expect(r.source, 'OpenFoodFacts');
      expect(r.barcode, '8901234567890');
      expect(r.servingSizeG, 18.4);
      // Per-gram scaling for the declared serving.
      expect(r.caloriesForGrams(18.4), closeTo(456 * 18.4 / 100, 0.001));
    });

    test('barcode not found (status 0) → null', () {
      final body = jsonDecode('{"status":0,"status_verbose":"not found"}')
          as Map<String, dynamic>;
      expect(FoodApiService.parseOffProductBody(body, '0000'), isNull);
    });

    test('search body maps, dedupes by name, drops zero / implausible kcal', () {
      final body = jsonDecode('''
      {"products":[
        {"product_name":"Boiled Chicken","nutriments":{"energy-kcal_100g":165,"proteins_100g":31,"carbohydrates_100g":0,"fat_100g":3.6}},
        {"product_name":"Boiled Chicken","nutriments":{"energy-kcal_100g":160,"proteins_100g":30}},
        {"product_name":"Water","nutriments":{"energy-kcal_100g":0}},
        {"product_name":"Broken","nutriments":{"energy-kcal_100g":5000}},
        {"product_name":"","nutriments":{"energy-kcal_100g":100}}
      ]}''') as Map<String, dynamic>;
      final results = FoodApiService.parseOffSearchBody(body);
      expect(results.length, 1); // dup name + zero + 5000 + empty all dropped
      expect(results.single.name, 'Boiled Chicken');
      expect(results.single.calories100g, 165);
    });

    test('clamps out-of-range macros to 0..100', () {
      final body = jsonDecode('''
      {"status":1,"product":{"product_name":"X","nutriments":{
        "energy-kcal_100g":200,"proteins_100g":-5,"carbohydrates_100g":250,"fat_100g":10}}}''')
          as Map<String, dynamic>;
      final r = FoodApiService.parseOffProductBody(body, '1');
      expect(r!.protein100g, 0); // -5 clamped up
      expect(r.carbs100g, 100); // 250 clamped down
    });
  });

  // ── Task 3: USDA mappers (nutrient numbers) ────────────────────────────────
  group('USDA mapping', () {
    test('search body maps nutrientNumber 208/203/204/205 per 100 g', () {
      final body = jsonDecode('''
      {"foods":[{
        "description":"Chicken, broilers, roasted",
        "foodNutrients":[
          {"nutrientNumber":"208","value":190},
          {"nutrientNumber":"203","value":28.9},
          {"nutrientNumber":"204","value":7.4},
          {"nutrientNumber":"205","value":0}
        ]
      }]}''') as Map<String, dynamic>;
      final results = FoodApiService.parseUsdaSearchBody(body);
      expect(results.length, 1);
      final r = results.single;
      expect(r.name, 'Chicken, broilers, roasted');
      expect(r.calories100g, 190);
      expect(r.protein100g, 28.9);
      expect(r.fat100g, 7.4);
      expect(r.carbs100g, 0);
      expect(r.source, 'USDA');
    });

    test('food missing energy (208) is dropped', () {
      final body = jsonDecode('''
      {"foods":[{"description":"No energy","foodNutrients":[
        {"nutrientNumber":"203","value":10}]}]}''') as Map<String, dynamic>;
      expect(FoodApiService.parseUsdaSearchBody(body), isEmpty);
    });

    test('UPC fallback matches gtinUpc exactly', () {
      final body = jsonDecode('''
      {"foods":[
        {"description":"Other brand","gtinUpc":"111","foodNutrients":[{"nutrientNumber":"208","value":100}]},
        {"description":"My Cereal","gtinUpc":"012345678905","foodNutrients":[
          {"nutrientNumber":"208","value":379},
          {"nutrientNumber":"203","value":7.5}]}
      ]}''') as Map<String, dynamic>;
      final r = FoodApiService.parseUsdaBarcodeBody(body, '012345678905');
      expect(r, isNotNull);
      expect(r!.name, 'My Cereal');
      expect(r.calories100g, 379);
      expect(r.barcode, '012345678905');
    });

    test('UPC fallback returns null when no gtinUpc matches', () {
      final body = jsonDecode('''
      {"foods":[{"description":"X","gtinUpc":"999","foodNutrients":[{"nutrientNumber":"208","value":100}]}]}''')
          as Map<String, dynamic>;
      expect(FoodApiService.parseUsdaBarcodeBody(body, '123'), isNull);
    });
  });

  // ── USDA gate + key handling ───────────────────────────────────────────────
  group('USDA gate', () {
    test('with no --dart-define, the key is empty and USDA is disabled', () {
      // Tests run without FDC_API_KEY → app must work key-unset.
      expect(FoodApiService.fdcApiKey, '');
      expect(FoodApiService.usdaEnabled, isFalse);
    });
  });

  // ── Caching + offline barcode + manual gap-fill ────────────────────────────
  group('barcode cache', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('FoodApiResult round-trips through JSON (cache integrity)', () {
      const r = FoodApiResult(
        name: 'Cached', calories100g: 250, protein100g: 5, carbs100g: 30,
        fat100g: 12, source: 'OpenFoodFacts', barcode: '42', servingSizeG: 25);
      final back = FoodApiResult.fromJson(jsonDecode(jsonEncode(r.toJson()))
          as Map<String, dynamic>);
      expect(back.name, 'Cached');
      expect(back.calories100g, 250);
      expect(back.barcode, '42');
      expect(back.servingSizeG, 25);
      expect(back.source, 'OpenFoodFacts');
    });

    test('a previously-cached barcode resolves offline (no network)', () async {
      const code = 'OFFLINE_TEST_555';
      const cached = FoodApiResult(
        name: 'Seeded', calories100g: 120, protein100g: 3, carbs100g: 20,
        fat100g: 2, source: 'OpenFoodFacts', barcode: code, servingSizeG: 30);
      SharedPreferences.setMockInitialValues(
          {'food_cache_$code': jsonEncode(cached.toJson())});
      final r = await FoodApiService.lookupByBarcode(code);
      expect(r, isNotNull);
      expect(r!.name, 'Seeded');
      expect(r.calories100g, 120);
    });

    test('cacheManualBarcode stores a per-100g/100g-serving result', () async {
      const code = 'MANUAL_TEST_777';
      await FoodApiService.cacheManualBarcode(
          barcode: code, name: 'Homemade Ladoo', calories: 410, protein: 6);
      final r = await FoodApiService.lookupByBarcode(code);
      expect(r, isNotNull);
      expect(r!.name, 'Homemade Ladoo');
      expect(r.calories100g, 410);
      expect(r.source, 'Manual');
      expect(r.servingSizeG, 100); // default serving = entered value
      expect(r.caloriesForGrams(100), 410);
    });

    test('empty barcode → null without touching the network', () async {
      expect(await FoodApiService.lookupByBarcode('  '), isNull);
    });
  });
}
