import 'package:flutter_test/flutter_test.dart';
import 'package:rodru/logic/format.dart';
import 'package:rodru/logic/risk.dart';
import 'package:rodru/logic/suncalc.dart';
import 'package:rodru/models/models.dart';

Forecast _forecast({double rainPerHour = 0, int code = 3, double gust = 10, double feels = 30}) {
  final now = DateTime.now();
  return Forecast(
    temp: 30,
    feels: feels,
    precip: rainPerHour,
    wind: 5,
    gust: gust,
    humidity: 70,
    code: code,
    isDay: true,
    hours: [for (var i = 0; i < 24; i++) HourPoint(now.add(Duration(hours: i)), 30, rainPerHour, 80, code, gust)],
    days: [DayPoint(date: now, tMax: 33, tMin: 25, precipSum: rainPerHour * 24, precipProbMax: 80, code: code, uvMax: 8, gustMax: gust)],
    fetchedAt: now,
  );
}

void main() {
  group('geo', () {
    test('Bangkok → Chiang Mai is ~580 km', () {
      final d = haversine(13.7563, 100.5018, 18.7883, 98.9853) / 1000;
      expect(d, inInclusiveRange(560, 600));
    });
    test('bearing north is ~0°', () {
      expect(bearing(13, 100, 14, 100), closeTo(0, 0.5));
    });
  });

  group('suncalc', () {
    test('Bangkok sunrise/sunset are plausible', () {
      // Use UTC-based comparison so the test does not depend on the CI timezone.
      final t = sunTimes(DateTime(2026, 3, 21), 13.7563, 100.5018);
      final rise = t.sunrise!.toUtc();
      final set = t.sunset!.toUtc();
      // Bangkok equinox: ~06:20 / ~18:25 local (UTC+7) → ~23:20 / ~11:25 UTC
      final riseLocalHour = (rise.hour + 7) % 24 + rise.minute / 60;
      final setLocalHour = (set.hour + 7) % 24 + set.minute / 60;
      expect(riseLocalHour, inInclusiveRange(5.9, 6.7));
      expect(setLocalHour, inInclusiveRange(18.0, 18.8));
      expect(t.dayLength!.inHours, inInclusiveRange(11, 12));
    });

    test('sun rises roughly in the east', () {
      final t = sunTimes(DateTime(2026, 3, 21), 13.7563, 100.5018);
      final az = sunPosition(t.sunrise!, 13.7563, 100.5018).azimuth;
      expect(az, inInclusiveRange(80, 100));
    });

    test('moon illumination within 0..1 and full moon detected', () {
      // 2026-03-03 was a full moon (lunar eclipse)
      final m = moonIllumination(DateTime.utc(2026, 3, 3, 11));
      expect(m.fraction, greaterThan(0.95));
      expect(m.phase, inInclusiveRange(0.45, 0.55));
    });
  });

  group('risk engine', () {
    test('dry weather gives no alerts', () {
      expect(RiskEngine.evaluate(forecast: _forecast()), isEmpty);
    });

    test('heavy rain gives a watch', () {
      final a = RiskEngine.evaluate(forecast: _forecast(rainPerHour: 2));
      expect(a.first.hazard, 'rain');
      expect(a.first.level, 1);
    });

    test('very heavy rain gives a flood warning', () {
      final a = RiskEngine.evaluate(forecast: _forecast(rainPerHour: 5));
      expect(a.first.hazard, 'flood');
      expect(a.first.level, 2);
    });

    test('thunderstorm code triggers storm alert', () {
      final a = RiskEngine.evaluate(forecast: _forecast(code: 95));
      expect(a.any((e) => e.hazard == 'storm'), isTrue);
    });

    test('PM2.5 above Thai standard triggers alert', () {
      final a = RiskEngine.evaluate(air: const AirQuality(80, 100, 150, []));
      expect(a.single.level, 2);
    });

    test('nearby recent quake triggers alert', () {
      final q = Quake(
        id: 'x',
        place: 'test',
        url: '',
        mag: 5.5,
        depthKm: 10,
        lat: 15,
        lon: 100,
        time: DateTime.now().subtract(const Duration(hours: 1)),
        tsunamiFlag: false,
      );
      final a = RiskEngine.evaluate(quakes: [q], location: AppLocation.bangkok);
      expect(a.single.hazard, 'earthquake');
    });
  });

  test('PM2.5 Thai bands', () {
    expect(const AirQuality(10, 0, null, []).band, 0);
    expect(const AirQuality(30, 0, null, []).band, 2);
    expect(const AirQuality(50, 0, null, []).band, 3);
  });
}
