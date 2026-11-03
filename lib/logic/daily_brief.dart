import 'dart:math' as math;

import '../models/models.dart';
import 'format.dart';

/// "TV weather presenter" style summary for the home card.
///
/// Pure function of forecast + air + alerts → text, so it is cheap, works
/// offline from the cached forecast, and is easy to unit-test.
class DailyBrief {
  final String greeting;
  final String headline;
  final int level; // 0 normal, 1 watch, 2 warning (copied from top alert)
  final List<String> today;
  final String? tomorrow;
  final List<BriefChip> bring; // what to carry tomorrow (or today if evening)
  final String? lookahead;
  final List<BriefChip> lifestyle;
  final bool serious;

  const DailyBrief({
    required this.greeting,
    required this.headline,
    required this.level,
    required this.today,
    required this.tomorrow,
    required this.bring,
    required this.lookahead,
    required this.lifestyle,
    required this.serious,
  });
}

class BriefChip {
  final String emoji, label;
  final bool good; // for lifestyle chips: true = yes/go, false = no
  const BriefChip(this.emoji, this.label, {this.good = true});
}

class DailyBriefBuilder {
  DailyBriefBuilder({DateTime? now, math.Random? random})
      : now = now ?? DateTime.now(),
        _rnd = random ?? math.Random((now ?? DateTime.now()).day * 31 + (now ?? DateTime.now()).month);

  final DateTime now;
  final math.Random _rnd;

  String _pick(List<String> options) => options[_rnd.nextInt(options.length)];

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  DailyBrief build({required Forecast f, AirQuality? air, List<RiskAlert> alerts = const []}) {
    final top = alerts.isEmpty ? null : alerts.first;
    final serious = (top?.level ?? 0) >= 2;
    final h = now.hour;
    final greeting = h < 5
        ? 'ดึกแล้วนะ'
        : h < 11
            ? 'อรุณสวัสดิ์'
            : h < 16
                ? 'บ่ายนี้'
                : h < 19
                    ? 'เย็นนี้'
                    : 'คืนนี้';
    final evening = h >= 17;

    final todayHours = f.hours.where((x) => _sameDay(x.time, now) && !x.time.isBefore(now.subtract(const Duration(hours: 1)))).toList();
    final tomorrowDate = DateTime(now.year, now.month, now.day + 1);
    final tomorrowHours = f.hours.where((x) => _sameDay(x.time, tomorrowDate)).toList();
    final days = f.days.where((d) => !d.date.isBefore(DateTime(now.year, now.month, now.day))).toList();
    final today = days.isNotEmpty ? days.first : null;
    final tomorrow = days.length > 1 ? days[1] : null;

    // ---------- today ----------
    final todayLines = <String>[];
    final rainWin = _rainWindow(todayHours);
    if (rainWin != null) {
      final commute = _hitsCommute(rainWin.$1, rainWin.$2);
      todayLines.add(serious
          ? 'ฝนช่วง ${hhmm(rainWin.$1)}–${hhmm(rainWin.$2.add(const Duration(hours: 1)))} น. (สูงสุด ${rainWin.$3} มม./ชม.)'
          : commute
              ? _pick([
                  'ฝนจ่อคิวช่วง ${hhmm(rainWin.$1)} ตรงเวลาเดินทางพอดี ออกเร็วหน่อยหรือรอให้ซาก่อน ☔',
                  'ฝนมาช่วง ${hhmm(rainWin.$1)}–${hhmm(rainWin.$2.add(const Duration(hours: 1)))} ชนเวลากลับบ้าน พกร่มไว้เลย',
                ])
              : _pick([
                  'ฝนมาช่วง ${hhmm(rainWin.$1)}–${hhmm(rainWin.$2.add(const Duration(hours: 1)))} มีร่มติดตัวไว้อุ่นใจ',
                  'แอบมีฝนช่วง ${hhmm(rainWin.$1)} นะ อย่าเพิ่งตากผ้าไว้นอกบ้าน',
                ]));
    } else if (todayHours.isNotEmpty) {
      todayLines.add(serious ? 'ไม่มีฝนในชั่วโมงที่เหลือของวันนี้' : _pick(['ที่เหลือของวันนี้ฟ้าโล่ง ไม่มีฝนมากวน ✌️', 'วันนี้ไม่มีฝนแล้ว เดินทางสบาย ๆ']));
    }
    final feelsMax = todayHours.isEmpty ? f.feels : todayHours.map((x) => x.feels).reduce(math.max);
    if (feelsMax >= 39) {
      todayLines.add(serious
          ? 'อุณหภูมิที่รู้สึกได้สูงถึง ${feelsMax.round()}°C'
          : _pick(['ร้อนตับแลบ รู้สึกเหมือน ${feelsMax.round()}° จิบน้ำบ่อย ๆ เลี่ยงแดดเที่ยง–บ่ายสาม 🥵', 'แดดเดือดปุด ๆ ${feelsMax.round()}° อยู่ในร่มได้อยู่เถอะ']));
    }
    if (air != null && air.pm25 > 37.5) {
      todayLines.add(serious
          ? 'PM2.5 ${air.pm25.round()} µg/m³ เกินมาตรฐาน'
          : _pick(['ฝุ่นมาอีกแล้ว PM2.5 ~${air.pm25.round()} ใส่ N95 ก่อนออกไปข้างนอกนะ 😷', 'ฝุ่นหนา ~${air.pm25.round()} µg/m³ ลดเวลาอยู่กลางแจ้งหน่อย']));
    }
    if ((today?.uvMax ?? 0) >= 8 && h < 15) {
      todayLines.add(serious ? 'UV สูง ${today!.uvMax.round()}' : 'UV แรงจัด (${today!.uvMax.round()}) ทากันแดดก่อนออกจากบ้านด้วยนะ 🧴');
    }

    // ---------- tomorrow + bring ----------
    String? tomorrowText;
    final bring = <BriefChip>[];
    if (tomorrow != null) {
      final rainy = tomorrow.precipProbMax >= 60 || tomorrow.precipSum >= 5;
      final maybeRain = !rainy && (tomorrow.precipProbMax >= 40 || tomorrow.precipSum >= 1);
      final cold = (today != null && today.tMin - tomorrow.tMin >= 3) || tomorrow.tMin <= 20;
      final hot = tomorrow.feelsMax >= 39;
      final parts = <String>[];
      if (rainy) {
        final w = _rainWindow(tomorrowHours);
        parts.add(serious
            ? 'ฝน ${tomorrow.precipProbMax}% (${tomorrow.precipSum.toStringAsFixed(0)} มม.)${w != null ? ' ช่วง ${hhmm(w.$1)}' : ''}'
            : _pick([
                'พรุ่งนี้ฝนมาแน่ ${tomorrow.precipProbMax}%${w != null ? ' ช่วง ${hhmm(w.$1)}' : ''} พกร่มติดกระเป๋าไว้เลย ☂️',
                'พรุ่งนี้มีฝน ${tomorrow.precipProbMax}%${w != null ? ' แถว ${hhmm(w.$1)}' : ''} อย่าลืมร่มนะ',
              ]));
        bring.add(const BriefChip('☂️', 'ร่ม'));
      } else if (maybeRain) {
        parts.add(serious ? 'อาจมีฝน ${tomorrow.precipProbMax}%' : 'พรุ่งนี้อาจมีฝนนิดหน่อย ${tomorrow.precipProbMax}% ร่มพับเล็ก ๆ ก็พอ');
        bring.add(const BriefChip('☂️', 'ร่มพับ'));
      }
      if (cold) {
        parts.add(serious ? 'ต่ำสุด ${tomorrow.tMin.round()}°' : 'เช้าพรุ่งนี้เย็นลง ต่ำสุด ${tomorrow.tMin.round()}° หยิบเสื้อคลุมไปด้วย 🧥');
        bring.add(const BriefChip('🧥', 'เสื้อกันหนาว'));
      }
      if (hot) {
        parts.add(serious ? 'ร้อน รู้สึกเหมือน ${tomorrow.feelsMax.round()}°' : 'พรุ่งนี้ร้อนจัด รู้สึกเหมือน ${tomorrow.feelsMax.round()}°');
        bring.add(const BriefChip('💧', 'น้ำเยอะ ๆ'));
      }
      if (tomorrow.uvMax >= 8) bring.add(const BriefChip('🧴', 'กันแดด'));
      final pmTomorrow = air == null || air.pm25Next24h.isEmpty ? null : air.pm25Next24h.reduce(math.max);
      if ((pmTomorrow ?? 0) > 37.5) bring.add(const BriefChip('😷', 'N95'));
      if (tomorrow.gustMax >= 50) parts.add(serious ? 'ลมกระโชก ${tomorrow.gustMax.round()} กม./ชม.' : 'ลมแรง ${tomorrow.gustMax.round()} กม./ชม. ระวังป้าย/กิ่งไม้');
      if (parts.isEmpty) {
        parts.add(serious
            ? '${weatherText(tomorrow.code)} ${tomorrow.tMin.round()}–${tomorrow.tMax.round()}°'
            : _pick([
                'พรุ่งนี้${weatherText(tomorrow.code)} ${tomorrow.tMin.round()}–${tomorrow.tMax.round()}° ชิล ๆ ใช้ชีวิตได้ตามปกติ ✌️',
                'พรุ่งนี้อากาศโอเค ${tomorrow.tMin.round()}–${tomorrow.tMax.round()}° ไม่ต้องพกอะไรพิเศษ',
              ]));
      }
      tomorrowText = parts.join(' · ');
    }

    // ---------- look ahead (day 2..6) ----------
    String? lookahead;
    if (days.length > 2 && today != null) {
      final later = days.sublist(2);
      DayPoint? coldDay;
      for (final d in later) {
        if (today.tMin - d.tMin >= 3 || (d.tMin <= 20 && today.tMin > 20)) {
          coldDay = d;
          break;
        }
      }
      final firstRain = later.cast<DayPoint?>().firstWhere((d) => d!.precipProbMax >= 60 || d.precipSum >= 5, orElse: () => null);
      final dryAll = later.every((d) => d.precipProbMax < 40 && d.precipSum < 1);
      final bits = <String>[];
      if (coldDay != null) {
        final n = _daysFrom(coldDay.date);
        bits.add(serious
            ? '${_when(coldDay.date)} อุณหภูมิลดลง ต่ำสุด ${coldDay.tMin.round()}°'
            : _pick([
                'อีก $n วัน (${_when(coldDay.date)}) อากาศเย็นลง ต่ำสุด ${coldDay.tMin.round()}° ซักเสื้อกันหนาวรอได้แล้ว 🧥',
                'ลมเย็นมา${_when(coldDay.date)} ต่ำสุด ${coldDay.tMin.round()}° เตรียมเสื้อกันหนาวให้พร้อม',
              ]));
      }
      if (firstRain != null) {
        bits.add(serious
            ? 'ฝน${_when(firstRain.date)} ${firstRain.precipProbMax}%'
            : '${_when(firstRain.date)}ฝนกลับมา ${firstRain.precipProbMax}% วางแผนเดินทางไว้หน่อย');
      } else if (dryAll) {
        bits.add(serious ? 'ไม่มีฝนต่อเนื่องหลายวัน' : 'อีกหลายวันไม่มีฝน ฟ้าใส ๆ ยาว ๆ ☀️');
      }
      if (bits.isNotEmpty) lookahead = bits.join(' · ');
    }

    // ---------- lifestyle chips ----------
    final lifestyle = <BriefChip>[];
    if (today != null) {
      final humid = todayHours.isEmpty ? f.humidity.toDouble() : todayHours.map((x) => x.humidity).reduce((a, b) => a + b) / todayHours.length;
      final restRain = todayHours.fold<double>(0, (s, x) => s + x.precip);
      final laundryOk = !evening && restRain < 0.5 && humid < 75 && (today.sunshineHours >= 5 || today.code <= 2);
      lifestyle.add(laundryOk ? const BriefChip('👕', 'ตากผ้าได้') : const BriefChip('👕', 'ตากผ้าในร่มดีกว่า', good: false));
      final next3 = days.take(3).fold<double>(0, (s, d) => s + d.precipSum);
      lifestyle.add(next3 < 2 ? const BriefChip('🚗', 'ล้างรถได้') : const BriefChip('🚗', 'ยังไม่ต้องล้างรถ', good: false));
      final run = _bestRunHour(evening ? tomorrowHours : todayHours, air);
      if (run != null) lifestyle.add(BriefChip('🏃', 'วิ่ง/ออกกำลังกาย ${evening ? 'พรุ่งนี้ ' : ''}${hhmm(run)}'));
    }

    // ---------- headline ----------
    String headline;
    if (top != null) {
      headline = top.title;
    } else if (rainWin != null) {
      headline = 'วันนี้มีฝนช่วง ${hhmm(rainWin.$1)}';
    } else if (tomorrow != null && (tomorrow.precipProbMax >= 60 || tomorrow.precipSum >= 5)) {
      headline = evening ? 'คืนนี้สบาย พรุ่งนี้ฝนมา' : 'วันนี้ฟ้าโอเค พรุ่งนี้ฝนมา';
    } else {
      headline = '${weatherText(f.code)} ${f.temp.round()}°';
    }

    return DailyBrief(
      greeting: greeting,
      headline: headline,
      level: top?.level ?? 0,
      today: todayLines.take(3).toList(),
      tomorrow: tomorrowText,
      bring: bring,
      lookahead: lookahead,
      lifestyle: lifestyle,
      serious: serious,
    );
  }

  /// First contiguous block of rainy hours: (start, end, max mm/h).
  (DateTime, DateTime, int)? _rainWindow(List<HourPoint> hours) {
    DateTime? start, end;
    var maxMm = 0.0;
    for (final x in hours) {
      final wet = x.precip >= 0.5 || (x.precipProb >= 60 && x.precip >= 0.1);
      if (wet) {
        start ??= x.time;
        end = x.time;
        maxMm = math.max(maxMm, x.precip);
      } else if (start != null) {
        break;
      }
    }
    if (start == null || end == null) return null;
    return (start, end, maxMm.round());
  }

  bool _hitsCommute(DateTime a, DateTime b) {
    bool overlap(int s, int e) => a.hour <= e && b.hour >= s;
    return overlap(7, 9) || overlap(16, 19);
  }

  DateTime? _bestRunHour(List<HourPoint> hours, AirQuality? air) {
    if (air != null && air.pm25 > 50) return null;
    HourPoint? best;
    for (final x in hours) {
      final hr = x.time.hour;
      if (!((hr >= 5 && hr <= 8) || (hr >= 17 && hr <= 19))) continue;
      if (x.precip >= 0.2 || x.precipProb >= 50) continue;
      if (best == null || x.feels < best.feels) best = x;
    }
    return best?.time;
  }

  int _daysFrom(DateTime d) => DateTime(d.year, d.month, d.day).difference(DateTime(now.year, now.month, now.day)).inDays;

  String _when(DateTime d) {
    final n = _daysFrom(d);
    if (n == 0) return 'วันนี้';
    if (n == 1) return 'พรุ่งนี้';
    if (n == 2) return 'มะรืนนี้';
    return 'วัน${_dayName(d)}';
  }

  static String _dayName(DateTime d) => const ['จันทร์', 'อังคาร', 'พุธ', 'พฤหัสฯ', 'ศุกร์', 'เสาร์', 'อาทิตย์'][d.weekday - 1];
}
