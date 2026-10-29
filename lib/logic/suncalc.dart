// Dart port of the core of SunCalc (c) Vladimir Agafonkin, BSD-2-Clause.
// https://github.com/mourner/suncalc
// Works fully offline from coordinates + date.

import 'dart:math';

const _rad = pi / 180;
const _dayMs = 1000 * 60 * 60 * 24;
const _j1970 = 2440588.0;
const _j2000 = 2451545.0;
const _e = _rad * 23.4397;

double _toJulian(DateTime d) => d.millisecondsSinceEpoch / _dayMs - 0.5 + _j1970;
DateTime _fromJulian(double j) => DateTime.fromMillisecondsSinceEpoch(((j + 0.5 - _j1970) * _dayMs).round());
double _toDays(DateTime d) => _toJulian(d) - _j2000;

double _rightAscension(double l, double b) => atan2(sin(l) * cos(_e) - tan(b) * sin(_e), cos(l));
double _declination(double l, double b) => asin(sin(b) * cos(_e) + cos(b) * sin(_e) * sin(l));
double _azimuth(double h, double phi, double dec) => atan2(sin(h), cos(h) * sin(phi) - tan(dec) * cos(phi));
double _altitude(double h, double phi, double dec) => asin(sin(phi) * sin(dec) + cos(phi) * cos(dec) * cos(h));
double _siderealTime(double d, double lw) => _rad * (280.16 + 360.9856235 * d) - lw;

double _astroRefraction(double h) {
  if (h < 0) h = 0;
  return 0.0002967 / tan(h + 0.00312536 / (h + 0.08901179));
}

double _solarMeanAnomaly(double d) => _rad * (357.5291 + 0.98560028 * d);

double _eclipticLongitude(double m) {
  final c = _rad * (1.9148 * sin(m) + 0.02 * sin(2 * m) + 0.0003 * sin(3 * m));
  const p = _rad * 102.9372;
  return m + c + p + pi;
}

({double dec, double ra}) _sunCoords(double d) {
  final m = _solarMeanAnomaly(d);
  final l = _eclipticLongitude(m);
  return (dec: _declination(l, 0), ra: _rightAscension(l, 0));
}

/// Sky position. [azimuth] is a compass bearing in degrees (0 = N, 90 = E),
/// [altitude] is degrees above the horizon.
class SkyPosition {
  final double azimuth, altitude;
  const SkyPosition(this.azimuth, this.altitude);
}

double _toCompass(double suncalcAzimuthRad) => (suncalcAzimuthRad / _rad + 180) % 360;

SkyPosition sunPosition(DateTime date, double lat, double lng) {
  final lw = _rad * -lng, phi = _rad * lat, d = _toDays(date);
  final c = _sunCoords(d);
  final h = _siderealTime(d, lw) - c.ra;
  return SkyPosition(_toCompass(_azimuth(h, phi, c.dec)), _altitude(h, phi, c.dec) / _rad);
}

// ---- sun times ----
const _j0 = 0.0009;
double _julianCycle(double d, double lw) => (d - _j0 - lw / (2 * pi)).roundToDouble();
double _approxTransit(double ht, double lw, double n) => _j0 + (ht + lw) / (2 * pi) + n;
double _solarTransitJ(double ds, double m, double l) => _j2000 + ds + 0.0053 * sin(m) - 0.0069 * sin(2 * l);
double _hourAngle(double h, double phi, double d) => acos((sin(h) - sin(phi) * sin(d)) / (cos(phi) * cos(d)));

class SunTimes {
  final DateTime? sunrise, sunset, solarNoon, goldenMorningEnd, goldenEveningStart, dawn, dusk;
  const SunTimes({this.sunrise, this.sunset, this.solarNoon, this.goldenMorningEnd, this.goldenEveningStart, this.dawn, this.dusk});
  Duration? get dayLength => sunrise != null && sunset != null ? sunset!.difference(sunrise!) : null;
}

SunTimes sunTimes(DateTime date, double lat, double lng) {
  // Use local noon of the given day so the Julian cycle picks the right date.
  final noonish = DateTime(date.year, date.month, date.day, 12);
  final lw = _rad * -lng, phi = _rad * lat;
  final d = _toDays(noonish);
  final n = _julianCycle(d, lw);
  final ds = _approxTransit(0, lw, n);
  final m = _solarMeanAnomaly(ds);
  final l = _eclipticLongitude(m);
  final dec = _declination(l, 0);
  final jNoon = _solarTransitJ(ds, m, l);

  (DateTime?, DateTime?) pair(double angleDeg) {
    final w = _hourAngle(angleDeg * _rad, phi, dec);
    if (w.isNaN) return (null, null);
    final jSet = _solarTransitJ(_approxTransit(w, lw, n), m, l);
    final jRise = jNoon - (jSet - jNoon);
    return (_fromJulian(jRise).toLocal(), _fromJulian(jSet).toLocal());
  }

  final rs = pair(-0.833);
  final civil = pair(-6);
  final golden = pair(6);
  return SunTimes(
    sunrise: rs.$1,
    sunset: rs.$2,
    solarNoon: _fromJulian(jNoon).toLocal(),
    dawn: civil.$1,
    dusk: civil.$2,
    goldenMorningEnd: golden.$1,
    goldenEveningStart: golden.$2,
  );
}

// ---- moon ----
({double ra, double dec, double dist}) _moonCoords(double d) {
  final l = _rad * (218.316 + 13.176396 * d);
  final m = _rad * (134.963 + 13.064993 * d);
  final f = _rad * (93.272 + 13.229350 * d);
  final lon = l + _rad * 6.289 * sin(m);
  final b = _rad * 5.128 * sin(f);
  final dt = 385001 - 20905 * cos(m);
  return (ra: _rightAscension(lon, b), dec: _declination(lon, b), dist: dt);
}

SkyPosition moonPosition(DateTime date, double lat, double lng) {
  final lw = _rad * -lng, phi = _rad * lat, d = _toDays(date);
  final c = _moonCoords(d);
  final h = _siderealTime(d, lw) - c.ra;
  var alt = _altitude(h, phi, c.dec);
  alt = alt + _astroRefraction(alt);
  return SkyPosition(_toCompass(_azimuth(h, phi, c.dec)), alt / _rad);
}

class MoonIllumination {
  /// 0..1 illuminated fraction.
  final double fraction;

  /// 0 = new, 0.25 = first quarter, 0.5 = full, 0.75 = last quarter.
  final double phase;
  const MoonIllumination(this.fraction, this.phase);

  /// Approximate days since new moon.
  double get age => phase * 29.530588;

  String get phaseName {
    if (phase < 0.03 || phase > 0.97) return 'จันทร์ดับ';
    if (phase < 0.22) return 'ข้างขึ้น เสี้ยว';
    if (phase < 0.28) return 'ขึ้นครึ่งดวง';
    if (phase < 0.47) return 'ข้างขึ้น เกือบเต็มดวง';
    if (phase < 0.53) return 'จันทร์เต็มดวง';
    if (phase < 0.72) return 'ข้างแรม เกือบเต็มดวง';
    if (phase < 0.78) return 'แรมครึ่งดวง';
    return 'ข้างแรม เสี้ยว';
  }

  /// Approximate Thai lunar day label (ขึ้น/แรม n ค่ำ). Astronomical estimate only.
  String get thaiLunarDay {
    final a = age;
    if (a < 14.765) return 'ขึ้น ${min(15, a.floor() + 1)} ค่ำ (โดยประมาณ)';
    return 'แรม ${min(15, (a - 14.765).floor() + 1)} ค่ำ (โดยประมาณ)';
  }
}

MoonIllumination moonIllumination(DateTime date) {
  final d = _toDays(date);
  final s = _sunCoords(d);
  final m = _moonCoords(d);
  const sdist = 149598000.0;
  final phi = acos(sin(s.dec) * sin(m.dec) + cos(s.dec) * cos(m.dec) * cos(s.ra - m.ra));
  final inc = atan2(sdist * sin(phi), m.dist - sdist * cos(phi));
  final angle = atan2(cos(s.dec) * sin(s.ra - m.ra), sin(s.dec) * cos(m.dec) - cos(s.dec) * sin(m.dec) * cos(s.ra - m.ra));
  return MoonIllumination((1 + cos(inc)) / 2, 0.5 + 0.5 * inc * (angle < 0 ? -1 : 1) / pi);
}

class MoonTimes {
  final DateTime? rise, set;
  const MoonTimes(this.rise, this.set);
}

MoonTimes moonTimes(DateTime date, double lat, double lng) {
  final t = DateTime(date.year, date.month, date.day);
  DateTime later(double h) => t.add(Duration(milliseconds: (h * 3600000).round()));
  const hc = 0.133 * _rad;
  double alt(double h) => moonPosition(later(h), lat, lng).altitude * _rad - hc;

  var h0 = alt(0);
  double? rise, set;
  for (var i = 1; i <= 24; i += 2) {
    final h1 = alt(i.toDouble());
    final h2 = alt(i + 1.0);
    final a = (h0 + h2) / 2 - h1;
    final b = (h2 - h0) / 2;
    final xe = -b / (2 * a);
    final ye = (a * xe + b) * xe + h1;
    final d = b * b - 4 * a * h1;
    var roots = 0;
    var x1 = 0.0, x2 = 0.0;
    if (d >= 0) {
      final dx = sqrt(d) / (a.abs() * 2);
      x1 = xe - dx;
      x2 = xe + dx;
      if (x1.abs() <= 1) roots++;
      if (x2.abs() <= 1) roots++;
      if (x1 < -1) x1 = x2;
    }
    if (roots == 1) {
      if (h0 < 0) {
        rise = i + x1;
      } else {
        set = i + x1;
      }
    } else if (roots == 2) {
      rise = i + (ye < 0 ? x2 : x1);
      set = i + (ye < 0 ? x1 : x2);
    }
    if (rise != null && set != null) break;
    h0 = h2;
  }
  return MoonTimes(rise == null ? null : later(rise), set == null ? null : later(set));
}
