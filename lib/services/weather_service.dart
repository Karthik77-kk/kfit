import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Free Open-Meteo weather API — no key needed.
/// Hardcoded to Bangalore (12.9716°N, 77.5946°E).
class WeatherService {
  static const _lat = 12.9716;
  static const _lon = 77.5946;
  static const _cacheKey = 'weather_cache';
  static const _cacheTimeKey = 'weather_cache_time';
  static const _cacheTtlMs = 30 * 60 * 1000; // 30 min

  Future<WeatherData?> fetchWeather() async {
    try {
      // Return cached data if still fresh
      final prefs = await SharedPreferences.getInstance();
      final cacheTime = prefs.getInt(_cacheTimeKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      if (now - cacheTime < _cacheTtlMs) {
        final cached = prefs.getString(_cacheKey);
        if (cached != null) {
          return WeatherData.fromJson(jsonDecode(cached));
        }
      }

      // Open-Meteo API v1 — IMPORTANT: field names updated Nov 2023:
      // weather_code (not weathercode), relative_humidity_2m, wind_speed_10m
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$_lat&longitude=$_lon'
        '&current=temperature_2m,weather_code,wind_speed_10m,relative_humidity_2m'
        '&timezone=Asia%2FKolkata',
      );

      final response =
          await http.get(url).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        return _loadFromCache(prefs);
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final current = json['current'] as Map<String, dynamic>?;
      if (current == null) return _loadFromCache(prefs);

      final data = WeatherData(
        tempC: (current['temperature_2m'] as num).toDouble(),
        humidity: (current['relative_humidity_2m'] as num).toInt(),
        windKph: (current['wind_speed_10m'] as num).toDouble(),
        code: (current['weather_code'] as num).toInt(),
      );

      // Cache result
      await prefs.setString(_cacheKey, jsonEncode(data.toJson()));
      await prefs.setInt(_cacheTimeKey, now);

      return data;
    } catch (_) {
      // Network error — try returning cached stale data
      try {
        final prefs = await SharedPreferences.getInstance();
        return _loadFromCache(prefs);
      } catch (_) {}
      return null;
    }
  }

  WeatherData? _loadFromCache(SharedPreferences prefs) {
    final cached = prefs.getString(_cacheKey);
    if (cached != null) return WeatherData.fromJson(jsonDecode(cached));
    return null;
  }

  /// Force-clear cache to trigger a fresh fetch next time.
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_cacheTimeKey);
  }
}

class WeatherData {
  final double tempC;
  final int humidity;
  final double windKph;
  final int code; // WMO weather code

  const WeatherData({
    required this.tempC,
    required this.humidity,
    required this.windKph,
    required this.code,
  });

  String get emoji {
    if (code == 0) return '☀️';
    if (code <= 2) return '⛅';
    if (code <= 3) return '☁️';
    if (code <= 49) return '🌫️';
    if (code <= 59) return '🌦️';
    if (code <= 69) return '🌧️';
    if (code <= 79) return '❄️';
    if (code <= 84) return '🌦️';
    if (code <= 94) return '⛈️';
    return '🌩️';
  }

  String get description {
    if (code == 0) return 'Clear sky';
    if (code <= 2) return 'Partly cloudy';
    if (code <= 3) return 'Overcast';
    if (code <= 49) return 'Foggy';
    if (code <= 59) return 'Drizzle';
    if (code <= 69) return 'Rainy';
    if (code <= 79) return 'Snowy';
    if (code <= 84) return 'Showers';
    if (code <= 94) return 'Thunderstorm';
    return 'Storm';
  }

  String get workoutAdvice {
    if (code == 0 || code <= 2) return 'Great day for an outdoor walk! 🚶';
    if (code <= 3) return 'Good conditions for outdoor exercise';
    if (code <= 49) return 'Foggy — gym session recommended';
    if (code <= 69) return 'Rainy — perfect gym day! 🏋️';
    return 'Stay indoors — gym session day';
  }

  Map<String, dynamic> toJson() => {
        'tempC': tempC,
        'humidity': humidity,
        'windKph': windKph,
        'code': code,
      };

  factory WeatherData.fromJson(Map<String, dynamic> j) => WeatherData(
        tempC: (j['tempC'] as num).toDouble(),
        humidity: (j['humidity'] as num).toInt(),
        windKph: (j['windKph'] as num).toDouble(),
        code: (j['code'] as num).toInt(),
      );
}
