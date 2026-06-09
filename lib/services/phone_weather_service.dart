import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class WeatherResult {
  final int tempC;
  final int weatherCode;
  final int utcOffsetSeconds;

  const WeatherResult({
    required this.tempC,
    required this.weatherCode,
    required this.utcOffsetSeconds,
  });

  /// JSON sent to watch: {"t":<temp>,"c":<code>,"o":<utc_offset>}
  String toWatchJson() =>
      '{"t":$tempC,"c":$weatherCode,"o":$utcOffsetSeconds}';

  @override
  String toString() =>
      'WeatherResult(temp=$tempC°C, code=$weatherCode, utcOffset=$utcOffsetSeconds)';
}

class PhoneWeatherService {
  static Future<Position?> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('[weather] Location services disabled');
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('[weather] Location permission denied');
        return null;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      print('[weather] Location permission permanently denied');
      return null;
    }

    // Prefer a cached fix — instant and good enough for weather.
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        print('[weather] Using cached location');
        return last;
      }
    } catch (_) {}

    // No cache — request a fresh fix with a generous timeout.
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 30),
        ),
      );
    } on TimeoutException {
      print('[weather] GPS timed out — no location available');
      return null;
    } catch (e) {
      print('[weather] Location error: $e');
      return null;
    }
  }

  static Future<WeatherResult?> fetch() async {
    try {
      return await _fetch();
    } catch (e, st) {
      print('[weather] Unexpected error: $e\n$st');
      return null;
    }
  }

  static Future<WeatherResult?> _fetch() async {
    final position = await _getLocation();
    if (position == null) {
      print('[weather] Could not get device location');
      return null;
    }

    final lat = position.latitude.toStringAsFixed(4);
    final lon = position.longitude.toStringAsFixed(4);
    print('[weather] Location: $lat, $lon');

    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$lat&longitude=$lon'
      '&current=temperature_2m,weather_code'
      '&temperature_unit=celsius&timezone=auto',
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      print('[weather] Open-Meteo error: ${response.statusCode}');
      return null;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final current = data['current'] as Map<String, dynamic>?;
    if (current == null) return null;

    final tempRaw = (current['temperature_2m'] as num).toDouble();
    final code = (current['weather_code'] as num).toInt();
    final offset = (data['utc_offset_seconds'] as num).toInt();
    final tempC = tempRaw >= 0 ? (tempRaw + 0.5).toInt() : (tempRaw - 0.5).toInt();

    final result = WeatherResult(
      tempC: tempC,
      weatherCode: code,
      utcOffsetSeconds: offset,
    );
    print('[weather] Fetched: $result');
    return result;
  }
}

