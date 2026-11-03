import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodru/data/content.dart';
import 'package:rodru/logic/daily_brief.dart';
import 'package:rodru/logic/risk.dart';
import 'package:rodru/models/models.dart';
import 'package:rodru/services/api.dart';

/// Builds a forecast starting at [now] with per-day settings.
Forecast _fc(
  DateTime now, {
  List<double> tMin = const [25, 25, 25, 25, 25, 25, 25],
  List<int> prob = const [10, 10, 10, 10, 10, 10, 10],
  List<double> rainSum = const [0, 0, 0, 0, 0, 0, 0],
  double rainHourToday = 0,
  int rainHourAt = 17,
}) {
  final day0 = DateTime(now.year, now.month, now.day);
  final hours = <HourPoint>[];
  for (var i = 0; i < 24 * 7; i++) {
    final t = day0.add(Duration(hours: i));
    if (t.isBefore(now.subtract(const Duration(hours: 1)))) continue;
    final d = i ~/ 24;
    final isRainHour = d == 0 && t.hour == rainHourAt && rainHourToday > 0;
    final tomorrowRain = d == 1 && rainSum[1] > 0 && t.hour == 15;
    hours.add(HourPoint(
      t,
      30,
      isRainHour ? rainHourToday : (tomorrowRain ? rainSum[1] : 0),
      isRainHour || tomorrowRain ? 80 : 10,
      isRainHour || tomorrowRain ? 63 : 2,
      10,
      humidity: 60,
      feels: 32,
    ));
  }
  return Forecast(
    temp: 30,
    feels: 32,
    precip: 0,
    wind: 5,
    gust: 10,
    humidity: 60,
    code: 2,
    isDay: true,
    hours: hours,
    days: [
      for (var d = 0; d < 7; d++)
        DayPoint(
          date: day0.add(Duration(days: d)),
          tMax: 33,
          tMin: tMin[d],
          precipSum: rainSum[d],
          precipProbMax: prob[d],
          code: rainSum[d] > 0 ? 63 : 2,
          uvMax: 6,
          gustMax: 15,
          sunshineHours: 8,
        ),
    ],
    fetchedAt: now,
  );
}

DailyBriefBuilder _builder(DateTime now) => DailyBriefBuilder(now: now, random: math.Random(1));

void main() {
  final morning = DateTime(2026, 11, 3, 8, 0);

  test('quiet weather: no bring items, laundry ok', () {
    final b = _builder(morning).build(f: _fc(morning));
    expect(b.level, 0);
    expect(b.bring, isEmpty);
    expect(b.lifestyle.first.good, isTrue); // ตากผ้าได้
    expect(b.tomorrow, isNotNull);
  });

  test('rain tomorrow → umbrella chip', () {
    final b = _builder(morning).build(f: _fc(morning, prob: const [10, 80, 10, 10, 10, 10, 10], rainSum: const [0, 12, 0, 0, 0, 0, 0]));
    expect(b.bring.any((c) => c.label.contains('ร่ม')), isTrue);
    expect(b.tomorrow, contains('80%'));
  });

  test('cold snap in 3 days → jacket advice in lookahead', () {
    final b = _builder(morning).build(f: _fc(morning, tMin: const [25, 25, 24, 20, 19, 19, 19]));
    expect(b.lookahead, isNotNull);
    expect(b.lookahead, contains('เสื้อกันหนาว'));
  });

  test('rain during evening commute is called out today', () {
    final b = _builder(morning).build(f: _fc(morning, rainHourToday: 6, rainHourAt: 17));
    expect(b.today.join(), contains('17:00'));
    expect(b.headline, contains('ฝน'));
  });

  test('serious mode when there is a level-2 alert', () {
    const alert = RiskAlert(hazard: 'flood', level: 2, title: 'เตือนน้ำท่วม', detail: 'x', icon: Icons.flood);
    final b = _builder(morning).build(f: _fc(morning), alerts: const [alert]);
    expect(b.serious, isTrue);
    expect(b.headline, 'เตือนน้ำท่วม');
  });

  test('ThaiWater row parses into a station', () {
    final w = WaterStation.fromThaiWater({
      'waterlevel_datetime': '2026-11-03 06:40',
      'waterlevel_msl': '46.00',
      'waterlevel_msl_previous': '45.90',
      'situation_level': 5,
      'diff_wl_bank': '1.70',
      'diff_wl_bank_text': 'ล้นตลิ่ง (ม.)',
      'river_name': 'ห้วยพรมโหด',
      'agency': {'agency_shortname': {'th': 'สสน.'}},
      'geocode': {'province_name': {'th': 'สระแก้ว'}, 'amphoe_name': {'th': 'อรัญประเทศ'}},
      'station': {'id': 200, 'tele_station_name': {'th': 'คลองพรหมโหด'}, 'tele_station_lat': 13.7, 'tele_station_long': 102.48, 'min_bank': 44.3},
    });
    expect(w, isNotNull);
    expect(w!.overflow, isTrue);
    expect(w.trend, 1);
    expect(w.bankText, 'ล้นตลิ่ง 1.70 ม.');
    expect(w.province, 'สระแก้ว');
  });

  test('overflowing station nearby raises a flood warning', () {
    final w = WaterStation(
      id: '1',
      name: 'สถานีทดสอบ',
      river: 'เจ้าพระยา',
      province: 'กรุงเทพมหานคร',
      district: '',
      agency: '',
      lat: 13.76,
      lon: 100.50,
      levelMsl: 2,
      previousMsl: 1.9,
      minBank: 1.8,
      diffBank: .2,
      storagePercent: 110,
      overflow: true,
      situation: 5,
      time: DateTime.now(),
    );
    final a = RiskEngine.evaluate(location: AppLocation.bangkok, waterStations: [w]);
    expect(a.single.level, 2);
    expect(a.single.hazard, 'flood');
  });

  test('Overpass response parses', () {
    final p = Api.parseOverpass({
      'elements': [
        {'type': 'node', 'lat': 13.7, 'lon': 100.5, 'tags': {'amenity': 'hospital', 'name': 'รพ.ทดสอบ', 'phone': '02-000-0000'}},
        {'type': 'way', 'center': {'lat': 13.8, 'lon': 100.6}, 'tags': {'emergency': 'assembly_point'}},
      ],
    });
    expect(p.length, 2);
    expect(p.first.kind, SafePlaceKind.hospital);
    expect(p.last.kind, SafePlaceKind.assembly);
    expect(SafePlace.fromJson(p.first.toJson())!.phone, '02-000-0000');
  });

  test('hotline directory has unique numbers and known categories', () {
    final nums = hotlineDirectory.map((h) => h.number).toList();
    expect(nums.toSet().length, nums.length);
    for (final h in hotlineDirectory) {
      expect(hotlineCategories, contains(h.category));
    }
  });
}
