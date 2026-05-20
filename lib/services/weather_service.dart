import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WeatherData {
  final double tempC;
  final int weatherCode;
  final double humidity;
  final double windKph;
  final DateTime fetchedAt;

  const WeatherData({
    required this.tempC,
    required this.weatherCode,
    required this.humidity,
    required this.windKph,
    required this.fetchedAt,
  });

  String get emoji {
    if (weatherCode == 0) return '☀️';
    if (weatherCode <= 2) return '🌤️';
    if (weatherCode <= 3) return '☁️';
    if (weatherCode <= 48) return '🌫️';
    if (weatherCode <= 57) return '🌦️';
    if (weatherCode <= 67) return '🌧️';
    if (weatherCode <= 77) return '🌨️';
    if (weatherCode <= 82) return '🌦️';
    if (weatherCode <= 86) return '🌨️';
    if (weatherCode <= 99) return '⛈️';
    return '🌡️';
  }

  String get description {
    if (weatherCode == 0) return 'Clear sky';
    if (weatherCode <= 2) return 'Partly cloudy';
    if (weatherCode <= 3) return 'Overcast';
    if (weatherCode <= 48) return 'Foggy';
    if (weatherCode <= 57) return 'Drizzle';
    if (weatherCode <= 67) return 'Rainy';
    if (weatherCode <= 77) return 'Snowy';
    if (weatherCode <= 82) return 'Rain showers';
    if (weatherCode <= 86) return 'Snow showers';
    if (weatherCode <= 99) return 'Thunderstorm';
    return 'Unknown';
  }

  String get workoutAdvice {
    if (weatherCode == 0 && tempC >= 18 && tempC <= 30) {
      return '🏃 Perfect weather for an outdoor run!';
    }
    if (weatherCode <= 2 && tempC >= 15 && tempC <= 32) {
      return '🚴 Great day for outdoor training';
    }
    if (tempC > 35) return '🌡️ Too hot — indoor workout recommended';
    if (tempC < 15) return '🥶 Cool morning — perfect for a brisk walk';
    if (weatherCode >= 51 && weatherCode <= 82) {
      return '🏠 Rainy day — crush it indoors!';
    }
    if (weatherCode >= 83) return '⛈️ Stay safe indoors today';
    return '💪 Good day to hit the gym';
  }

  Map<String, dynamic> toJson() => {
        'tempC': tempC,
        'weatherCode': weatherCode,
        'humidity': humidity,
        'windKph': windKph,
        'fetchedAt': fetchedAt.toIso8601String(),
      };

  factory WeatherData.fromJson(Map<String, dynamic> j) => WeatherData(
        tempC: (j['tempC'] as num).toDouble(),
        weatherCode: j['weatherCode'] as int,
        humidity: (j['humidity'] as num).toDouble(),
        windKph: (j['windKph'] as num).toDouble(),
        fetchedAt: DateTime.parse(j['fetchedAt'] as String),
      );
}

class WeatherService {
  static const double _lat = 12.9716;
  static const double _lon = 77.5946;
  static const String _cacheKey = 'weather_cache';
  static const Duration _cacheDuration = Duration(minutes: 30);

  Future<WeatherData?> fetchWeather() async {
    // Try cache first
    final cached = await _loadCache();
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _cacheDuration) {
      return cached;
    }

    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$_lat&longitude=$_lon'
        '&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m'
        '&wind_speed_unit=kmh',
      );
      final response =
          await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return cached;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final current = json['current'] as Map<String, dynamic>;

      final data = WeatherData(
        tempC: (current['temperature_2m'] as num).toDouble(),
        weatherCode: (current['weather_code'] as num).toInt(),
        humidity: (current['relative_humidity_2m'] as num).toDouble(),
        windKph: (current['wind_speed_10m'] as num).toDouble(),
        fetchedAt: DateTime.now(),
      );

      await _saveCache(data);
      return data;
    } catch (_) {
      return cached; // return stale cache on error
    }
  }

  Future<WeatherData?> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return null;
      return WeatherData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveCache(WeatherData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(data.toJson()));
    } catch (_) {}
  }
}
