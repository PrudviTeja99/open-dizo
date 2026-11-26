import 'dart:convert';
import 'dart:io';

class WeatherForecastDay {
  final int lowTempC;
  final int highTempC;
  final int wmoCode;
  final int watchWeatherCode;

  const WeatherForecastDay({
    required this.lowTempC,
    required this.highTempC,
    required this.wmoCode,
    required this.watchWeatherCode,
  });
}

class WeatherSnapshot {
  final String city;
  final int currentTempC;
  final int lowTempC;
  final int highTempC;
  final int wmoCode;
  final int watchWeatherCode;
  final int pressureHpa;
  final List<WeatherForecastDay> forecasts;
  final DateTime fetchedAt;

  const WeatherSnapshot({
    required this.city,
    required this.currentTempC,
    required this.lowTempC,
    required this.highTempC,
    required this.wmoCode,
    required this.watchWeatherCode,
    required this.pressureHpa,
    required this.forecasts,
    required this.fetchedAt,
  });

  String get conditionLabel {
    switch (watchWeatherCode) {
      case 1:
        return 'Sunny';
      case 2:
        return 'Partly Cloudy';
      case 3:
        return 'Cloudy';
      case 4:
        return 'Rain';
      case 5:
        return 'Snow';
      case 6:
        return 'Thunderstorm';
      default:
        return 'Clear';
    }
  }
}

/// Fetches live weather & 7-day forecast using free Open-Meteo APIs (no API key required)
class WeatherService {
  /// Maps WMO weather codes to HTSmart watch icon codes
  static int mapWmoToWatchCode(int wmo) {
    if (wmo == 0) return 1; // Clear / Sunny
    if (wmo == 1 || wmo == 2) return 2; // Partly Cloudy
    if (wmo == 3 || wmo == 45 || wmo == 48) return 3; // Overcast / Fog
    if ((wmo >= 51 && wmo <= 67) || (wmo >= 80 && wmo <= 82)) return 4; // Rain
    if ((wmo >= 71 && wmo <= 77) || wmo == 85 || wmo == 86) return 5; // Snow
    if (wmo >= 95) return 6; // Thunderstorm
    return 1;
  }

  /// Fetches weather directly from GPS coordinates, reverse-geocoding the city name
  /// via Nominatim (OpenStreetMap), then pulling the forecast from Open-Meteo.
  static Future<WeatherSnapshot> fetchWeatherForCoords(double lat, double lon) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    try {
      // 1. Reverse-geocode lat/lon → human-readable city name
      final revUri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json&zoom=10&addressdetails=1',
      );
      final revReq = await client.getUrl(revUri);
      revReq.headers.set('User-Agent', 'OpenDizoApp/1.3');
      final revResp = await revReq.close();
      String resolvedCity = 'My Location';
      if (revResp.statusCode == 200) {
        final revJson = jsonDecode(await revResp.transform(utf8.decoder).join()) as Map<String, dynamic>;
        final address = revJson['address'] as Map<String, dynamic>?;
        resolvedCity = (address?['city'] as String?) ??
            (address?['town'] as String?) ??
            (address?['village'] as String?) ??
            (revJson['display_name'] as String?)?.split(',').first.trim() ??
            'My Location';
      }

      // 2. Fetch weather forecast from coordinates (timezone auto-detected)
      final weatherUri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon'
        '&current=temperature_2m,weather_code,surface_pressure'
        '&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto',
      );
      final wReq = await client.getUrl(weatherUri);
      final wResp = await wReq.close();
      if (wResp.statusCode != 200) {
        throw Exception('Weather fetch failed (${wResp.statusCode})');
      }
      final wJson = jsonDecode(await wResp.transform(utf8.decoder).join()) as Map<String, dynamic>;

      final current = wJson['current'] as Map<String, dynamic>;
      final currentTemp = (current['temperature_2m'] as num).round();
      final currentWmo = (current['weather_code'] as num).toInt();
      final pressure = ((current['surface_pressure'] as num?) ?? 1013).round();

      final daily = wJson['daily'] as Map<String, dynamic>;
      final minList = (daily['temperature_2m_min'] as List<dynamic>).cast<num>();
      final maxList = (daily['temperature_2m_max'] as List<dynamic>).cast<num>();
      final codeList = (daily['weather_code'] as List<dynamic>).cast<num>();

      final todayLow = minList.isNotEmpty ? minList[0].round() : currentTemp - 3;
      final todayHigh = maxList.isNotEmpty ? maxList[0].round() : currentTemp + 4;

      final forecasts = <WeatherForecastDay>[];
      for (int i = 1; i < minList.length && forecasts.length < 6; i++) {
        final wmo = codeList[i].toInt();
        forecasts.add(WeatherForecastDay(
          lowTempC: minList[i].round(),
          highTempC: maxList[i].round(),
          wmoCode: wmo,
          watchWeatherCode: mapWmoToWatchCode(wmo),
        ));
      }

      return WeatherSnapshot(
        city: resolvedCity,
        currentTempC: currentTemp,
        lowTempC: todayLow,
        highTempC: todayHigh,
        wmoCode: currentWmo,
        watchWeatherCode: mapWmoToWatchCode(currentWmo),
        pressureHpa: pressure,
        forecasts: forecasts,
        fetchedAt: DateTime.now(),
      );
    } finally {
      client.close();
    }
  }

  static Future<WeatherSnapshot> fetchWeatherForCity(String cityQuery) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    try {
      // 1. Geocode city name
      final geoUri = Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(cityQuery.trim())}&count=1&language=en&format=json',
      );
      final geoReq = await client.getUrl(geoUri);
      final geoResp = await geoReq.close();
      if (geoResp.statusCode != 200) {
        throw Exception('Geocoding failed (${geoResp.statusCode})');
      }
      final geoJson = jsonDecode(await geoResp.transform(utf8.decoder).join()) as Map<String, dynamic>;
      final results = geoJson['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) {
        throw Exception('City "$cityQuery" not found');
      }
      final loc = results.first as Map<String, dynamic>;
      final lat = (loc['latitude'] as num).toDouble();
      final lon = (loc['longitude'] as num).toDouble();
      final resolvedName = loc['name'] as String? ?? cityQuery;

      // 2. Fetch forecast
      final weatherUri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,weather_code,surface_pressure&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto',
      );
      final wReq = await client.getUrl(weatherUri);
      final wResp = await wReq.close();
      if (wResp.statusCode != 200) {
        throw Exception('Weather fetch failed (${wResp.statusCode})');
      }
      final wJson = jsonDecode(await wResp.transform(utf8.decoder).join()) as Map<String, dynamic>;

      final current = wJson['current'] as Map<String, dynamic>;
      final currentTemp = (current['temperature_2m'] as num).round();
      final currentWmo = (current['weather_code'] as num).toInt();
      final pressure = ((current['surface_pressure'] as num?) ?? 1013).round();

      final daily = wJson['daily'] as Map<String, dynamic>;
      final minList = (daily['temperature_2m_min'] as List<dynamic>).cast<num>();
      final maxList = (daily['temperature_2m_max'] as List<dynamic>).cast<num>();
      final codeList = (daily['weather_code'] as List<dynamic>).cast<num>();

      final todayLow = minList.isNotEmpty ? minList[0].round() : currentTemp - 3;
      final todayHigh = maxList.isNotEmpty ? maxList[0].round() : currentTemp + 4;

      final forecasts = <WeatherForecastDay>[];
      for (int i = 1; i < minList.length && forecasts.length < 6; i++) {
        final wmo = codeList[i].toInt();
        forecasts.add(WeatherForecastDay(
          lowTempC: minList[i].round(),
          highTempC: maxList[i].round(),
          wmoCode: wmo,
          watchWeatherCode: mapWmoToWatchCode(wmo),
        ));
      }

      return WeatherSnapshot(
        city: resolvedName,
        currentTempC: currentTemp,
        lowTempC: todayLow,
        highTempC: todayHigh,
        wmoCode: currentWmo,
        watchWeatherCode: mapWmoToWatchCode(currentWmo),
        pressureHpa: pressure,
        forecasts: forecasts,
        fetchedAt: DateTime.now(),
      );
    } finally {
      client.close();
    }
  }
}
