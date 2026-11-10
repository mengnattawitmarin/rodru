import 'dart:math' as math;

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
  final int humidity;
  final double feels;

  /// Mid-level (700 hPa) "steering" wind that moves rain cells. Direction is
  /// where the wind blows FROM (meteorological convention), km/h.
  final double? wind700Speed, wind700Dir;
  const HourPoint(this.time, this.temp, this.precip, this.precipProb, this.code, this.gust,
      {this.humidity = 0, double? feels, this.wind700Speed, this.wind700Dir})
      : feels = feels ?? temp;
}

class DayPoint {
  final DateTime date;
  final double tMax, tMin, precipSum, uvMax, gustMax;
  final double feelsMax, sunshineHours;
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
    double? feelsMax,
    this.sunshineHours = 0,
    this.sunrise,
    this.sunset,
  }) : feelsMax = feelsMax ?? tMax;
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

  /// Safe array access: returns null when the series is missing (e.g. an
  /// older cached response) or the value is null.
  static num? _at(Map<String, dynamic> m, String key, int i) {
    final l = m[key];
    if (l is! List || i >= l.length) return null;
    return l[i] as num?;
  }

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
        _d(_at(h, 'temperature_2m', i)),
        _d(_at(h, 'precipitation', i)),
        _i(_at(h, 'precipitation_probability', i)),
        _i(_at(h, 'weather_code', i)),
        _d(_at(h, 'wind_gusts_10m', i)),
        humidity: _i(_at(h, 'relative_humidity_2m', i)),
        feels: _at(h, 'apparent_temperature', i)?.toDouble(),
        wind700Speed: _at(h, 'wind_speed_700hPa', i)?.toDouble(),
        wind700Dir: _at(h, 'wind_direction_700hPa', i)?.toDouble(),
      ));
    }
    final dayTimes = (d['time'] as List).cast<String>();
    final days = <DayPoint>[];
    for (var i = 0; i < dayTimes.length; i++) {
      final sr = (d['sunrise'] as List?)?[i];
      final ss = (d['sunset'] as List?)?[i];
      days.add(DayPoint(
        date: DateTime.parse(dayTimes[i]),
        tMax: _d(_at(d, 'temperature_2m_max', i)),
        tMin: _d(_at(d, 'temperature_2m_min', i)),
        precipSum: _d(_at(d, 'precipitation_sum', i)),
        precipProbMax: _i(_at(d, 'precipitation_probability_max', i)),
        code: _i(_at(d, 'weather_code', i)),
        uvMax: _d(_at(d, 'uv_index_max', i)),
        gustMax: _d(_at(d, 'wind_gusts_10m_max', i)),
        feelsMax: _at(d, 'apparent_temperature_max', i)?.toDouble(),
        sunshineHours: _d(_at(d, 'sunshine_duration', i)) / 3600,
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

  /// Steering wind for the next few hours (average of first 3 hours that have it).
  ({double speed, double fromDir})? get steeringWind {
    final pts = hours.where((h) => h.wind700Speed != null && h.wind700Dir != null).take(3).toList();
    if (pts.isEmpty) return null;
    // vector average
    var u = 0.0, v = 0.0;
    for (final p in pts) {
      final r = p.wind700Dir! * math.pi / 180;
      u += p.wind700Speed! * math.sin(r);
      v += p.wind700Speed! * math.cos(r);
    }
    u /= pts.length;
    v /= pts.length;
    final speed = math.sqrt(u * u + v * v);
    final dir = (math.atan2(u, v) * 180 / math.pi + 360) % 360;
    return (speed: speed, fromDir: dir);
  }
}

class AirQuality {
  final double pm25, pm10;
  final int? usAqi;
  final List<double> pm25Next24h;
  const AirQuality(this.pm25, this.pm10, this.usAqi, this.pm25Next24h);

  Map<String, dynamic> toJson() => {'pm25': pm25, 'pm10': pm10, 'aqi': usAqi, 'next': pm25Next24h};
  static AirQuality? fromJson(Map<String, dynamic> j) {
    try {
      return AirQuality((j['pm25'] as num).toDouble(), (j['pm10'] as num).toDouble(), (j['aqi'] as num?)?.toInt(),
          [for (final v in (j['next'] as List? ?? const [])) (v as num).toDouble()]);
    } catch (_) {
      return null;
    }
  }

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

  Map<String, dynamic> toJson() => {
        'id': id, 'place': place, 'url': url, 'mag': mag, 'depth': depthKm, 'lat': lat, 'lon': lon,
        't': time.millisecondsSinceEpoch, 'ts': tsunamiFlag,
      };
  static Quake? fromJson(Map<String, dynamic> j) {
    try {
      return Quake(
        id: j['id'] as String,
        place: j['place'] as String,
        url: j['url'] as String,
        mag: (j['mag'] as num).toDouble(),
        depthKm: (j['depth'] as num).toDouble(),
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        time: DateTime.fromMillisecondsSinceEpoch((j['t'] as num).toInt()),
        tsunamiFlag: j['ts'] == true,
      );
    } catch (_) {
      return null;
    }
  }
}

enum SafePlaceKind { hospital, police, fire, assembly, shelter }

class SafePlace {
  final String name;
  final SafePlaceKind kind;
  final double lat, lon;
  final String? phone;
  const SafePlace(this.name, this.kind, this.lat, this.lon, {this.phone});
  LatLng get latLng => LatLng(lat, lon);

  Map<String, dynamic> toJson() => {'n': name, 'k': kind.index, 'a': lat, 'o': lon, if (phone != null) 'p': phone};
  static SafePlace? fromJson(Map<String, dynamic> j) {
    try {
      return SafePlace(j['n'] as String, SafePlaceKind.values[(j['k'] as num).toInt()], (j['a'] as num).toDouble(),
          (j['o'] as num).toDouble(),
          phone: j['p'] as String?);
    } catch (_) {
      return null;
    }
  }

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


// ---------------- water levels (ThaiWater / HII) ----------------

/// A telemetry water-level station from the National Hydroinformatics Data
/// Center (ThaiWater, สสน.). [situation]: 1 น้ำน้อยวิกฤต · 2 น้ำน้อย · 3 ปกติ ·
/// 4 น้ำมาก · 5 ล้นตลิ่ง.
class WaterStation {
  final String id, name, river, province, district, agency;
  final double lat, lon;
  final double? levelMsl, previousMsl, minBank, diffBank, storagePercent;
  final bool overflow;
  final int situation;
  final DateTime time;
  const WaterStation({
    required this.id,
    required this.name,
    required this.river,
    required this.province,
    required this.district,
    required this.agency,
    required this.lat,
    required this.lon,
    required this.levelMsl,
    required this.previousMsl,
    required this.minBank,
    required this.diffBank,
    required this.storagePercent,
    required this.overflow,
    required this.situation,
    required this.time,
  });
  LatLng get latLng => LatLng(lat, lon);

  Map<String, dynamic> toJson() => {
        'id': id, 'n': name, 'r': river, 'p': province, 'd': district, 'a': agency, 'la': lat, 'lo': lon,
        'l': levelMsl, 'pl': previousMsl, 'b': minBank, 'db': diffBank, 'sp': storagePercent, 'o': overflow,
        's': situation, 't': time.millisecondsSinceEpoch,
      };
  static WaterStation? fromJson(Map<String, dynamic> j) {
    double? n(String k) => (j[k] as num?)?.toDouble();
    try {
      return WaterStation(
        id: j['id'] as String,
        name: j['n'] as String,
        river: j['r'] as String,
        province: j['p'] as String,
        district: j['d'] as String,
        agency: j['a'] as String,
        lat: n('la')!,
        lon: n('lo')!,
        levelMsl: n('l'),
        previousMsl: n('pl'),
        minBank: n('b'),
        diffBank: n('db'),
        storagePercent: n('sp'),
        overflow: j['o'] == true,
        situation: (j['s'] as num).toInt(),
        time: DateTime.fromMillisecondsSinceEpoch((j['t'] as num).toInt()),
      );
    } catch (_) {
      return null;
    }
  }

  /// +1 rising, -1 falling, 0 steady/unknown.
  int get trend {
    if (levelMsl == null || previousMsl == null) return 0;
    final d = levelMsl! - previousMsl!;
    if (d > 0.01) return 1;
    if (d < -0.01) return -1;
    return 0;
  }

  String get situationLabel => switch (situation) {
        5 => 'ล้นตลิ่ง',
        4 => 'น้ำมาก',
        3 => 'ปกติ',
        2 => 'น้ำน้อย',
        1 => 'น้ำน้อยวิกฤต',
        _ => 'ไม่ทราบ',
      };

  Color get color => switch (situation) {
        5 => const Color(0xFFFF5D52),
        4 => const Color(0xFFFF9F43),
        3 => const Color(0xFF55D68B),
        2 => const Color(0xFFFFE066),
        1 => const Color(0xFFB08850),
        _ => Colors.white54,
      };

  /// "ต่ำกว่าตลิ่ง 1.20 ม." / "ล้นตลิ่ง 0.30 ม."
  String? get bankText {
    if (diffBank == null) return null;
    return '${overflow ? 'ล้นตลิ่ง' : 'ต่ำกว่าตลิ่ง'} ${diffBank!.abs().toStringAsFixed(2)} ม.';
  }

  static double? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse('$v');
  }

  static String _th(dynamic m) {
    if (m is Map) return (m['th'] ?? m['en'] ?? '').toString();
    return m?.toString() ?? '';
  }

  /// Parses one row of `waterlevel_load` → `waterlevel_data.data[]`.
  static WaterStation? fromThaiWater(Map<String, dynamic> r) {
    final st = r['station'];
    if (st is! Map) return null;
    final lat = _num(st['tele_station_lat']);
    final lon = _num(st['tele_station_long']);
    final t = DateTime.tryParse('${r['waterlevel_datetime'] ?? ''}');
    if (lat == null || lon == null || t == null || lat == 0 || lon == 0) return null;
    final geo = r['geocode'] is Map ? r['geocode'] as Map : const {};
    final agency = r['agency'] is Map ? (r['agency'] as Map)['agency_shortname'] : null;
    final diffText = '${r['diff_wl_bank_text'] ?? ''}';
    final situation = (_num(r['situation_level']) ?? 0).toInt();
    return WaterStation(
      id: '${st['id']}',
      name: _th(st['tele_station_name']).trim().isEmpty ? '${st['tele_station_oldcode'] ?? 'สถานี'}' : _th(st['tele_station_name']).trim(),
      river: '${r['river_name'] ?? ''}',
      province: _th(geo['province_name']),
      district: _th(geo['amphoe_name']),
      agency: _th(agency),
      lat: lat,
      lon: lon,
      levelMsl: _num(r['waterlevel_msl']),
      previousMsl: _num(r['waterlevel_msl_previous']),
      minBank: _num(st['min_bank']),
      diffBank: _num(r['diff_wl_bank']),
      storagePercent: _num(r['storage_percent']),
      overflow: situation == 5 || diffText.contains('ล้น'),
      situation: situation,
      time: t,
    );
  }
}

/// One frame of the rain radar animation.
class RadarFrame {
  final String urlTemplate;
  final DateTime time;
  final bool nowcast;
  const RadarFrame(this.urlTemplate, this.time, {this.nowcast = false});
}

/// A ShakeMap intensity contour (Modified Mercalli Intensity).
class MmiContour {
  final double mmi;
  final List<List<LatLng>> lines;
  const MmiContour(this.mmi, this.lines);
}

/// Wind sample for the wind layer.
class WindSample {
  final double lat, lon, speed, fromDir;
  const WindSample(this.lat, this.lon, this.speed, this.fromDir);
}

/// บัตรข้อมูลสมาชิกครอบครัว (เด็ก ผู้สูงอายุ ผู้ป่วย) — แสดง/แคปหน้าจอให้เจ้าหน้าที่ได้
class FamilyMember {
  final String id, name, nickname, age, bloodType, allergies, conditions, medications, guardianPhone, note;
  const FamilyMember({
    required this.id,
    this.name = '',
    this.nickname = '',
    this.age = '',
    this.bloodType = '',
    this.allergies = '',
    this.conditions = '',
    this.medications = '',
    this.guardianPhone = '',
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'nickname': nickname,
        'age': age,
        'bloodType': bloodType,
        'allergies': allergies,
        'conditions': conditions,
        'medications': medications,
        'guardianPhone': guardianPhone,
        'note': note,
      };

  factory FamilyMember.fromJson(Map<String, dynamic> j) => FamilyMember(
        id: j['id'] as String? ?? '${DateTime.now().microsecondsSinceEpoch}',
        name: j['name'] as String? ?? '',
        nickname: j['nickname'] as String? ?? '',
        age: j['age'] as String? ?? '',
        bloodType: j['bloodType'] as String? ?? '',
        allergies: j['allergies'] as String? ?? '',
        conditions: j['conditions'] as String? ?? '',
        medications: j['medications'] as String? ?? '',
        guardianPhone: j['guardianPhone'] as String? ?? '',
        note: j['note'] as String? ?? '',
      );

  String toShareText() => [
        'บัตรข้อมูลฉุกเฉิน',
        if (name.isNotEmpty) 'ชื่อ: $name${nickname.isNotEmpty ? ' ($nickname)' : ''}',
        if (age.isNotEmpty) 'อายุ: $age',
        if (bloodType.isNotEmpty) 'กรุ๊ปเลือด: $bloodType',
        if (allergies.isNotEmpty) 'แพ้: $allergies',
        if (conditions.isNotEmpty) 'โรคประจำตัว: $conditions',
        if (medications.isNotEmpty) 'ยาที่ใช้: $medications',
        if (guardianPhone.isNotEmpty) 'ติดต่อผู้ปกครอง: $guardianPhone',
        if (note.isNotEmpty) 'หมายเหตุ: $note',
      ].join('\n');
}

// ---------------- radiation (ปส.) ----------------

class RadStation {
  final int id;
  final String name, province, status;
  final double lat, lon;
  final double? value, err;
  final bool underwater;
  const RadStation({
    required this.id,
    required this.name,
    required this.province,
    required this.status,
    required this.lat,
    required this.lon,
    this.value,
    this.err,
    this.underwater = false,
  });
  LatLng get latLng => LatLng(lat, lon);

  factory RadStation.fromJson(Map<String, dynamic> j) => RadStation(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String? ?? '',
        province: j['province'] as String? ?? '',
        status: j['status'] as String? ?? '',
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        value: (j['value'] as num?)?.toDouble(),
        err: (j['err'] as num?)?.toDouble(),
        underwater: j['underwater'] == true,
      );
}

class RadiationReport {
  final String source, sourceUrl, period, unit;
  final double normalMin, normalMax;
  final DateTime? updated;
  final List<RadStation> stations;
  const RadiationReport({
    required this.source,
    required this.sourceUrl,
    required this.period,
    required this.unit,
    required this.normalMin,
    required this.normalMax,
    required this.updated,
    required this.stations,
  });

  factory RadiationReport.fromJson(Map<String, dynamic> j) => RadiationReport(
        source: j['source'] as String? ?? 'ปส.',
        sourceUrl: j['source_url'] as String? ?? 'https://www.oap.go.th',
        period: j['period'] as String? ?? '',
        unit: j['unit'] as String? ?? 'µSv/h',
        normalMin: (j['normal_min'] as num?)?.toDouble() ?? 0.01,
        normalMax: (j['normal_max'] as num?)?.toDouble() ?? 0.3,
        updated: DateTime.tryParse(j['updated'] as String? ?? ''),
        stations: [for (final s in (j['stations'] as List? ?? const [])) RadStation.fromJson(s as Map<String, dynamic>)],
      );

  List<RadStation> get withValue => stations.where((s) => s.value != null).toList();
  bool get allNormal => withValue.every((s) => s.value! <= normalMax);
}

// ---------------- admin announcements ----------------

/// A notice posted by the app owner in data/announcements.json (B2).
class Notice {
  final String id, title, body;
  final int level; // 0 info, 1 watch, 2 warning
  final String? link;
  final DateTime? expires;
  final List<String> areas; // province names; empty or "*" = everywhere
  const Notice({
    required this.id,
    required this.title,
    required this.body,
    required this.level,
    this.link,
    this.expires,
    this.areas = const [],
  });

  static Notice? fromJson(Map<String, dynamic> j) {
    final id = j['id'] as String?;
    final title = j['title'] as String?;
    if (id == null || title == null) return null;
    return Notice(
      id: id,
      title: title,
      body: j['body'] as String? ?? '',
      level: ((j['level'] as num?)?.toInt() ?? 0).clamp(0, 2).toInt(),
      link: j['link'] as String?,
      expires: DateTime.tryParse(j['expires'] as String? ?? ''),
      areas: [for (final a in (j['areas'] as List? ?? const [])) '$a'],
    );
  }

  bool activeFor(String placeName, DateTime now) {
    if (expires != null && now.isAfter(expires!)) return false;
    if (areas.isEmpty || areas.contains('*')) return true;
    return areas.any((a) => a.isNotEmpty && placeName.contains(a));
  }
}
