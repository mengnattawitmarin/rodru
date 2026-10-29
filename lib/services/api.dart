import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/models.dart';

/// All network access lives here so data sources can be swapped later
/// (e.g. for official Thai feeds) without touching the UI.
class Api {
  Api({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const userAgent = 'RODRU-MVP/0.2 (github.com/rodru; disaster-readiness prototype)';
  static const _timeout = Duration(seconds: 15);

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final res = await _client.get(uri, headers: {'User-Agent': userAgent}).timeout(_timeout);
    if (res.statusCode != 200) throw ApiException('HTTP ${res.statusCode} จาก ${uri.host}');
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  // ---------- Weather (Open-Meteo) ----------
  Future<String> fetchForecastRaw(double lat, double lon) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '$lat',
      'longitude': '$lon',
      'current': 'temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m,wind_gusts_10m',
      'hourly': 'temperature_2m,precipitation_probability,precipitation,weather_code,wind_gusts_10m',
      'daily': 'weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max,sunrise,sunset,uv_index_max,wind_gusts_10m_max',
      'timezone': 'Asia/Bangkok',
      'forecast_days': '7',
    });
    final res = await _client.get(uri, headers: {'User-Agent': userAgent}).timeout(_timeout);
    if (res.statusCode != 200) throw ApiException('โหลดพยากรณ์อากาศไม่สำเร็จ (${res.statusCode})');
    return utf8.decode(res.bodyBytes);
  }

  // ---------- Air quality (Open-Meteo / CAMS) ----------
  Future<AirQuality> fetchAir(double lat, double lon) async {
    final j = await _getJson(Uri.https('air-quality-api.open-meteo.com', '/v1/air-quality', {
      'latitude': '$lat',
      'longitude': '$lon',
      'current': 'pm2_5,pm10,us_aqi',
      'hourly': 'pm2_5',
      'timezone': 'Asia/Bangkok',
      'forecast_days': '2',
    }));
    final c = j['current'] as Map<String, dynamic>;
    final h = j['hourly'] as Map<String, dynamic>;
    final times = (h['time'] as List).cast<String>();
    final vals = h['pm2_5'] as List;
    final now = DateTime.now();
    final next = <double>[];
    for (var i = 0; i < times.length && next.length < 24; i++) {
      if (DateTime.parse(times[i]).isBefore(now.subtract(const Duration(hours: 1)))) continue;
      final v = vals[i];
      if (v != null) next.add((v as num).toDouble());
    }
    return AirQuality(
      (c['pm2_5'] as num?)?.toDouble() ?? 0,
      (c['pm10'] as num?)?.toDouble() ?? 0,
      (c['us_aqi'] as num?)?.toInt(),
      next,
    );
  }

  // ---------- Sea level / tide model (Open-Meteo Marine) ----------
  /// Returns hourly modelled sea level (m, relative to MSL) for ~2 days, or
  /// null when the point is inland / not covered.
  Future<List<MapEntry<DateTime, double>>?> fetchSeaLevel(double lat, double lon) async {
    final j = await _getJson(Uri.https('marine-api.open-meteo.com', '/v1/marine', {
      'latitude': '$lat',
      'longitude': '$lon',
      'hourly': 'sea_level_height_msl',
      'timezone': 'Asia/Bangkok',
      'forecast_days': '3',
      'cell_selection': 'sea',
    }));
    final h = j['hourly'] as Map<String, dynamic>?;
    if (h == null || h['sea_level_height_msl'] == null) return null;
    final times = (h['time'] as List).cast<String>();
    final vals = h['sea_level_height_msl'] as List;
    final out = <MapEntry<DateTime, double>>[];
    for (var i = 0; i < times.length; i++) {
      if (vals[i] == null) continue;
      out.add(MapEntry(DateTime.parse(times[i]), (vals[i] as num).toDouble()));
    }
    return out.length < 6 ? null : out;
  }

  // ---------- Earthquakes (USGS) ----------
  /// Quakes M≥[minMag] in mainland SE Asia + Andaman Sea for the last [days].
  Future<List<Quake>> fetchQuakes({int days = 7, double minMag = 3.0}) async {
    final start = DateTime.now().toUtc().subtract(Duration(days: days));
    final j = await _getJson(Uri.https('earthquake.usgs.gov', '/fdsnws/event/1/query', {
      'format': 'geojson',
      'starttime': start.toIso8601String(),
      'minlatitude': '-2',
      'maxlatitude': '28',
      'minlongitude': '88',
      'maxlongitude': '110',
      'minmagnitude': '$minMag',
      'orderby': 'time',
      'limit': '100',
    }));
    final feats = (j['features'] as List).cast<Map<String, dynamic>>();
    return feats.map((f) {
      final p = f['properties'] as Map<String, dynamic>;
      final g = (f['geometry'] as Map<String, dynamic>)['coordinates'] as List;
      return Quake(
        id: f['id'] as String,
        place: p['place'] as String? ?? 'ไม่ระบุตำแหน่ง',
        url: p['url'] as String? ?? 'https://earthquake.usgs.gov',
        mag: (p['mag'] as num?)?.toDouble() ?? 0,
        lon: (g[0] as num).toDouble(),
        lat: (g[1] as num).toDouble(),
        depthKm: g.length > 2 && g[2] != null ? (g[2] as num).toDouble() : 0,
        time: DateTime.fromMillisecondsSinceEpoch((p['time'] as num).toInt()),
        tsunamiFlag: p['tsunami'] == 1,
      );
    }).toList();
  }

  // ---------- Rain radar (RainViewer) ----------
  /// Returns a tile URL template for the latest radar frame and its time.
  Future<(String, DateTime)?> fetchRadarTemplate() async {
    final j = await _getJson(Uri.https('api.rainviewer.com', '/public/weather-maps.json'));
    final host = j['host'] as String? ?? 'https://tilecache.rainviewer.com';
    final past = ((j['radar'] as Map<String, dynamic>?)?['past'] as List?) ?? const [];
    if (past.isEmpty) return null;
    final last = past.last as Map<String, dynamic>;
    final path = last['path'] as String;
    final time = DateTime.fromMillisecondsSinceEpoch((last['time'] as num).toInt() * 1000);
    return ('$host$path/256/{z}/{x}/{y}/2/1_1.png', time);
  }

  // ---------- Safe places (OpenStreetMap / Overpass) ----------
  Future<List<SafePlace>> fetchSafePlaces(double lat, double lon, {int radiusM = 15000}) async {
    final q = '[out:json][timeout:25];('
        'nwr["amenity"~"^(hospital|police|fire_station)\$"](around:$radiusM,$lat,$lon);'
        'nwr["emergency"="assembly_point"](around:$radiusM,$lat,$lon);'
        'nwr["social_facility"="shelter"](around:$radiusM,$lat,$lon);'
        'nwr["emergency"="shelter"](around:$radiusM,$lat,$lon);'
        ');out center 150;';
    final res = await _client.post(
      Uri.https('overpass-api.de', '/api/interpreter'),
      headers: {'User-Agent': userAgent},
      body: {'data': q},
    ).timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) throw ApiException('โหลดข้อมูลสถานที่ไม่สำเร็จ (${res.statusCode})');
    final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final out = <SafePlace>[];
    for (final e in (j['elements'] as List).cast<Map<String, dynamic>>()) {
      final tags = (e['tags'] as Map?)?.cast<String, dynamic>() ?? const {};
      final la = (e['lat'] ?? (e['center'] as Map?)?['lat']) as num?;
      final lo = (e['lon'] ?? (e['center'] as Map?)?['lon']) as num?;
      if (la == null || lo == null) continue;
      final amenity = tags['amenity'];
      final kind = amenity == 'hospital'
          ? SafePlaceKind.hospital
          : amenity == 'police'
              ? SafePlaceKind.police
              : amenity == 'fire_station'
                  ? SafePlaceKind.fire
                  : tags['emergency'] == 'assembly_point'
                      ? SafePlaceKind.assembly
                      : SafePlaceKind.shelter;
      final name = (tags['name:th'] ?? tags['name'] ?? tags['name:en']) as String?;
      out.add(SafePlace(
        name ?? 'ไม่ระบุชื่อ',
        kind,
        la.toDouble(),
        lo.toDouble(),
        phone: (tags['phone'] ?? tags['contact:phone']) as String?,
      ));
    }
    return out;
  }

  // ---------- Routing (OSRM demo server) ----------
  Future<List<RouteOption>> fetchRoutes(LatLng from, LatLng to) async {
    final j = await _getJson(Uri.https(
      'router.project-osrm.org',
      '/route/v1/driving/${from.longitude},${from.latitude};${to.longitude},${to.latitude}',
      {'overview': 'full', 'geometries': 'geojson', 'alternatives': 'true'},
    ));
    if (j['code'] != 'Ok') throw ApiException('หาเส้นทางไม่ได้');
    return (j['routes'] as List).cast<Map<String, dynamic>>().map((r) {
      final coords = ((r['geometry'] as Map<String, dynamic>)['coordinates'] as List).cast<List>();
      return RouteOption(
        coords.map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList(),
        (r['distance'] as num).toDouble(),
        (r['duration'] as num).toDouble(),
      );
    }).toList();
  }

  // ---------- Geocoding ----------
  Future<List<AppLocation>> searchPlaces(String query) async {
    final j = await _getJson(Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': query,
      'count': '15',
      'language': 'th',
      'countryCode': 'TH',
    }));
    final results = (j['results'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    return results.map((r) {
      final admin = r['admin1'] as String?;
      final n = r['name'] as String;
      return AppLocation(
        admin != null && admin != n ? '$n, $admin' : n,
        (r['latitude'] as num).toDouble(),
        (r['longitude'] as num).toDouble(),
      );
    }).toList();
  }

  /// Best-effort place name for GPS coordinates (Nominatim, low volume only).
  Future<String?> reverseGeocode(double lat, double lon) async {
    try {
      final j = await _getJson(Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': '$lat',
        'lon': '$lon',
        'zoom': '12',
        'accept-language': 'th',
      }));
      final a = (j['address'] as Map?)?.cast<String, dynamic>() ?? const {};
      final local = a['suburb'] ?? a['town'] ?? a['city_district'] ?? a['district'] ?? a['county'] ?? a['city'];
      final prov = a['state'] ?? a['province'] ?? a['city'];
      if (local != null && prov != null && local != prov) return '$local, $prov';
      return (local ?? prov) as String?;
    } catch (_) {
      return null;
    }
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}
