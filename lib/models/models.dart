import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// A place the user is viewing data for (GPS fix or chosen manually).
class AppLocation {
  final String name;
  final double lat, lon;
  final bool fromGps;
  const AppLocation(this.name, this.lat, this.lon, {this.fromGps = false});

  LatLng get latLng => LatLng(lat, lon);

  Map<String, dynamic> toJson() => {'name': name, 'lat': lat, 'lon': lon, 'gps': fromGps};
  factory AppLocation.fromJson(Map<String, dynamic> j) => AppLocation(
        j['name'] as String,
        (j['lat'] as num).toDouble(),
        (j['lon'] as num).toDouble(),
        fromGps: j['gps'] == true,
      );

  static const bangkok = AppLocation('กรุงเทพมหานคร', 13.7563, 100.5018);
}

class HourPoint {
  final DateTime time;
  final double temp, precip, gust;
  final int precipProb, code;
  const HourPoint(this.time, this.temp, this.precip, this.precipProb, this.code, this.gust);
}

class DayPoint {
  final DateTime date;
  final double tMax, tMin, precipSum, uvMax, gustMax;
  final int precipProbMax, code;
  final DateTime? sunrise, sunset;
  const DayPoint({
    required this.date,
    required this.tMax,
    required this.tMin,
    required this.precipSum,
    required this.precipProbMax,
    required this.code,
    required this.uvMax,
    required this.gustMax,
    this.sunrise,
    this.sunset,
  });
}

class Forecast {
  final double temp, feels, precip, wind, gust;
  final int humidity, code;
  final bool isDay;
  final List<HourPoint> hours; // from the current hour onward
  final List<DayPoint> days;
  final DateTime fetchedAt;

  const Forecast({
    required this.temp,
    required this.feels,
    required this.precip,
    required this.wind,
    required this.gust,
    required this.humidity,
    required this.code,
    required this.isDay,
    required this.hours,
    required this.days,
    required this.fetchedAt,
  });

  static double _d(dynamic v) => v == null ? 0 : (v as num).toDouble();
  static int _i(dynamic v) => v == null ? 0 : (v as num).toInt();

  factory Forecast.fromJson(Map<String, dynamic> j, {DateTime? fetchedAt}) {
    final c = j['current'] as Map<String, dynamic>;
    final h = j['hourly'] as Map<String, dynamic>;
    final d = j['daily'] as Map<String, dynamic>;
    final now = DateTime.now();
    final hourTimes = (h['time'] as List).cast<String>();
    final hours = <HourPoint>[];
    for (var i = 0; i < hourTimes.length; i++) {
      final t = DateTime.parse(hourTimes[i]);
      if (t.isBefore(now.subtract(const Duration(hours: 1)))) continue;
      hours.add(HourPoint(
        t,
        _d((h['temperature_2m'] as List)[i]),
        _d((h['precipitation'] as List)[i]),
        _i((h['precipitation_probability'] as List)[i]),
        _i((h['weather_code'] as List)[i]),
        _d((h['wind_gusts_10m'] as List)[i]),
      ));
    }
    final dayTimes = (d['time'] as List).cast<String>();
    final days = <DayPoint>[];
    for (var i = 0; i < dayTimes.length; i++) {
      final sr = (d['sunrise'] as List)[i];
      final ss = (d['sunset'] as List)[i];
      days.add(DayPoint(
        date: DateTime.parse(dayTimes[i]),
        tMax: _d((d['temperature_2m_max'] as List)[i]),
        tMin: _d((d['temperature_2m_min'] as List)[i]),
        precipSum: _d((d['precipitation_sum'] as List)[i]),
        precipProbMax: _i((d['precipitation_probability_max'] as List)[i]),
        code: _i((d['weather_code'] as List)[i]),
        uvMax: _d((d['uv_index_max'] as List)[i]),
        gustMax: _d((d['wind_gusts_10m_max'] as List)[i]),
        sunrise: sr == null ? null : DateTime.parse(sr as String),
        sunset: ss == null ? null : DateTime.parse(ss as String),
      ));
    }
    return Forecast(
      temp: _d(c['temperature_2m']),
      feels: _d(c['apparent_temperature']),
      precip: _d(c['precipitation']),
      wind: _d(c['wind_speed_10m']),
      gust: _d(c['wind_gusts_10m']),
      humidity: _i(c['relative_humidity_2m']),
      code: _i(c['weather_code']),
      isDay: _i(c['is_day']) == 1,
      hours: hours,
      days: days,
      fetchedAt: fetchedAt ?? DateTime.now(),
    );
  }
}

class AirQuality {
  final double pm25, pm10;
  final int? usAqi;
  final List<double> pm25Next24h;
  const AirQuality(this.pm25, this.pm10, this.usAqi, this.pm25Next24h);

  /// Thai PCD PM2.5 bands (µg/m³, 24h standard revised 2023).
  int get band {
    if (pm25 <= 15) return 0;
    if (pm25 <= 25) return 1;
    if (pm25 <= 37.5) return 2;
    if (pm25 <= 75) return 3;
    return 4;
  }

  String get bandLabel => const ['ดีมาก', 'ดี', 'ปานกลาง', 'เริ่มมีผลต่อสุขภาพ', 'มีผลต่อสุขภาพ'][band];
  Color get bandColor => const [Color(0xFF3BC9F5), Color(0xFF55D68B), Color(0xFFFFE066), Color(0xFFFF9F43), Color(0xFFFF5D52)][band];
}

class Quake {
  final String id, place, url;
  final double mag, depthKm, lat, lon;
  final DateTime time;
  final bool tsunamiFlag;
  const Quake({
    required this.id,
    required this.place,
    required this.url,
    required this.mag,
    required this.depthKm,
    required this.lat,
    required this.lon,
    required this.time,
    required this.tsunamiFlag,
  });
  LatLng get latLng => LatLng(lat, lon);
}

enum SafePlaceKind { hospital, police, fire, assembly, shelter }

class SafePlace {
  final String name;
  final SafePlaceKind kind;
  final double lat, lon;
  final String? phone;
  const SafePlace(this.name, this.kind, this.lat, this.lon, {this.phone});
  LatLng get latLng => LatLng(lat, lon);

  String get kindLabel => switch (kind) {
        SafePlaceKind.hospital => 'โรงพยาบาล',
        SafePlaceKind.police => 'สถานีตำรวจ',
        SafePlaceKind.fire => 'สถานีดับเพลิง',
        SafePlaceKind.assembly => 'จุดรวมพล',
        SafePlaceKind.shelter => 'ศูนย์พักพิง',
      };

  IconData get icon => switch (kind) {
        SafePlaceKind.hospital => Icons.local_hospital,
        SafePlaceKind.police => Icons.local_police,
        SafePlaceKind.fire => Icons.fire_truck,
        SafePlaceKind.assembly => Icons.groups,
        SafePlaceKind.shelter => Icons.home_work,
      };
}

class RouteOption {
  final List<LatLng> points;
  final double distanceM, durationS;
  const RouteOption(this.points, this.distanceM, this.durationS);
}

/// An item shown in the alert banner / notifications list. These are
/// computed by the app from forecasts, NOT official government warnings.
class RiskAlert {
  final String hazard; // key into guides
  final int level; // 1 = watch, 2 = warning
  final String title, detail;
  final IconData icon;
  final List<String> actions;
  const RiskAlert({
    required this.hazard,
    required this.level,
    required this.title,
    required this.detail,
    required this.icon,
    this.actions = const [],
  });
}

class EmergencyContact {
  final String name, phone, relation;
  const EmergencyContact(this.name, this.phone, this.relation);
  Map<String, dynamic> toJson() => {'name': name, 'phone': phone, 'relation': relation};
  factory EmergencyContact.fromJson(Map<String, dynamic> j) =>
      EmergencyContact(j['name'] as String? ?? '', j['phone'] as String? ?? '', j['relation'] as String? ?? '');
}

class MedicalInfo {
  final String fullName, bloodType, allergies, conditions, medications;
  const MedicalInfo({
    this.fullName = '',
    this.bloodType = '',
    this.allergies = '',
    this.conditions = '',
    this.medications = '',
  });
  bool get isEmpty => [fullName, bloodType, allergies, conditions, medications].every((e) => e.trim().isEmpty);
  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'bloodType': bloodType,
        'allergies': allergies,
        'conditions': conditions,
        'medications': medications,
      };
  factory MedicalInfo.fromJson(Map<String, dynamic> j) => MedicalInfo(
        fullName: j['fullName'] as String? ?? '',
        bloodType: j['bloodType'] as String? ?? '',
        allergies: j['allergies'] as String? ?? '',
        conditions: j['conditions'] as String? ?? '',
        medications: j['medications'] as String? ?? '',
      );

  String toShareText() {
    final parts = <String>[];
    if (fullName.isNotEmpty) parts.add('ชื่อ: $fullName');
    if (bloodType.isNotEmpty) parts.add('กรุ๊ปเลือด: $bloodType');
    if (allergies.isNotEmpty) parts.add('แพ้: $allergies');
    if (conditions.isNotEmpty) parts.add('โรคประจำตัว: $conditions');
    if (medications.isNotEmpty) parts.add('ยาที่ใช้: $medications');
    return parts.join('\n');
  }
}
