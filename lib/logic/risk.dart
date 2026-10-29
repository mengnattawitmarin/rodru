import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/models.dart';
import 'format.dart';

/// Simple, transparent rules that turn forecasts into "watch" / "warning"
/// cards. Thresholds follow common Thai Meteorological Department (TMD)
/// rainfall classes and Pollution Control Department (PCD) PM2.5 bands.
///
/// IMPORTANT: these are app-computed estimates, not official warnings.
class RiskEngine {
  // TMD 24h rainfall classes (mm): moderate 10.1–35, heavy 35.1–90, very heavy > 90
  static const heavyRain24h = 35.0;
  static const veryHeavyRain24h = 90.0;
  static const heavyRain6h = 20.0;
  static const intenseHourly = 10.0;
  static const gustWatch = 50.0; // km/h
  static const gustWarning = 75.0;
  static const heatWatch = 39.0; // feels-like °C
  static const heatWarning = 41.0;
  static const pmWatch = 37.5; // µg/m³
  static const pmWarning = 75.0;

  static List<RiskAlert> evaluate({
    Forecast? forecast,
    AirQuality? air,
    List<Quake> quakes = const [],
    AppLocation? location,
  }) {
    final out = <RiskAlert>[];
    if (forecast != null) {
      final h6 = forecast.hours.take(6).toList();
      final h24 = forecast.hours.take(24).toList();
      final rain6 = h6.fold<double>(0, (s, h) => s + h.precip);
      final rain24 = h24.fold<double>(0, (s, h) => s + h.precip);
      final maxHourly = h6.isEmpty ? 0.0 : h6.map((h) => h.precip).reduce(math.max);
      final storm6 = h6.any((h) => h.code >= 95);
      final gust24 = h24.isEmpty ? forecast.gust : h24.map((h) => h.gust).reduce(math.max);

      if (rain24 >= veryHeavyRain24h || rain6 >= 50) {
        out.add(RiskAlert(
          hazard: 'flood',
          level: 2,
          title: 'เตือนฝนตกหนักมาก เสี่ยงน้ำท่วมฉับพลัน',
          detail: 'คาดฝนสะสม ${rain24.toStringAsFixed(0)} มม. ใน 24 ชม. (${rain6.toStringAsFixed(0)} มม. ใน 6 ชม.)',
          icon: Icons.flood,
          actions: const [
            'ติดตามประกาศจากกรมอุตุฯ และ ปภ. อย่างใกล้ชิด',
            'ยกของมีค่า เอกสาร และยาไว้ที่สูง',
            'เตรียมกระเป๋าฉุกเฉินและพร้อมอพยพเมื่อมีคำสั่ง',
            'หลีกเลี่ยงทางลอดและถนนเลียบลำน้ำ',
          ],
        ));
      } else if (rain24 >= heavyRain24h || rain6 >= heavyRain6h || maxHourly >= intenseHourly) {
        out.add(RiskAlert(
          hazard: 'rain',
          level: 1,
          title: 'เฝ้าระวังฝนหนัก',
          detail: rain6 >= 1
              ? 'ฝนตกหนักถึงหนักมาก ใน 6 ชม. ข้างหน้า (~${rain6.toStringAsFixed(0)} มม.)'
              : 'คาดฝนสะสม ~${rain24.toStringAsFixed(0)} มม. ใน 24 ชม.',
          icon: Icons.thunderstorm,
          actions: const [
            'ติดตามประกาศเตือนภัยอย่างใกล้ชิด',
            'เก็บของสำคัญไว้ในที่ปลอดภัย',
            'เตรียมพร้อมอพยพหากมีคำสั่ง',
          ],
        ));
      }

      if (storm6) {
        out.add(const RiskAlert(
          hazard: 'storm',
          level: 1,
          title: 'มีพายุฝนฟ้าคะนองใน 6 ชม.',
          detail: 'ระวังฟ้าผ่า ลมกระโชกแรง และต้นไม้/ป้ายล้ม',
          icon: Icons.flash_on,
          actions: [
            'งดกิจกรรมกลางแจ้งและทางน้ำ',
            'อยู่ในอาคารแข็งแรง ห่างต้นไม้ใหญ่และป้ายโฆษณา',
            'ถอดปลั๊กเครื่องใช้ไฟฟ้าที่ไม่จำเป็น',
          ],
        ));
      }

      if (gust24 >= gustWatch) {
        out.add(RiskAlert(
          hazard: 'storm',
          level: gust24 >= gustWarning ? 2 : 1,
          title: gust24 >= gustWarning ? 'เตือนลมกระโชกแรงมาก' : 'เฝ้าระวังลมแรง',
          detail: 'ลมกระโชกสูงสุด ~${gust24.round()} กม./ชม. ใน 24 ชม.',
          icon: Icons.air,
          actions: const ['ผูกยึดสิ่งของนอกบ้าน', 'หลีกเลี่ยงการเดินเรือเล็ก', 'ระวังต้นไม้และเสาไฟล้ม'],
        ));
      }

      final maxFeels = math.max(forecast.feels, forecast.days.isEmpty ? 0.0 : forecast.days.first.tMax);
      if (maxFeels >= heatWatch) {
        out.add(RiskAlert(
          hazard: 'heat',
          level: maxFeels >= heatWarning ? 2 : 1,
          title: maxFeels >= heatWarning ? 'อากาศร้อนอันตราย' : 'เฝ้าระวังอากาศร้อนจัด',
          detail: 'อุณหภูมิที่รู้สึกได้สูงถึง ~${maxFeels.round()}°C',
          icon: Icons.thermostat,
          actions: const ['ดื่มน้ำบ่อย ๆ แม้ไม่กระหาย', 'เลี่ยงแดดช่วง 11:00–15:00', 'สังเกตอาการฮีทสโตรก: ตัวร้อน สับสน ไม่มีเหงื่อ'],
        ));
      }
    }

    if (air != null && air.pm25 > pmWatch) {
      out.add(RiskAlert(
        hazard: 'pm25',
        level: air.pm25 > pmWarning ? 2 : 1,
        title: 'ฝุ่น PM2.5 ${air.bandLabel}',
        detail: 'PM2.5 ประมาณ ${air.pm25.round()} µg/m³ (เกณฑ์ไทยไม่เกิน 37.5)',
        icon: Icons.masks,
        actions: const ['สวมหน้ากาก N95 เมื่ออยู่กลางแจ้ง', 'ลดกิจกรรมกลางแจ้ง โดยเฉพาะเด็กและผู้สูงอายุ', 'ปิดหน้าต่างและใช้เครื่องฟอกอากาศถ้ามี'],
      ));
    }

    if (location != null) {
      for (final q in quakes) {
        final age = DateTime.now().difference(q.time);
        if (age > const Duration(hours: 48)) continue;
        final dKm = haversine(location.lat, location.lon, q.lat, q.lon) / 1000;
        final felt = q.mag >= 6 ? 1000 : q.mag >= 5 ? 500 : q.mag >= 4 ? 200 : 60;
        if (dKm <= felt) {
          out.add(RiskAlert(
            hazard: 'earthquake',
            level: q.mag >= 6 && dKm < 500 ? 2 : 1,
            title: 'แผ่นดินไหว M${q.mag.toStringAsFixed(1)} ห่าง ${dKm.round()} กม.',
            detail: '${q.place} • ${timeAgo(q.time)}${q.tsunamiFlag ? ' • มีการประเมินสึนามิ' : ''}',
            icon: Icons.vibration,
            actions: const ['ระวังอาฟเตอร์ช็อก', 'ตรวจรอยร้าวอาคารก่อนเข้าใช้', 'ถ้าอยู่ชายฝั่งและสั่นแรง ให้ขึ้นที่สูงทันที'],
          ));
          break; // one quake card is enough
        }
      }
    }

    out.sort((a, b) => b.level.compareTo(a.level));
    return out;
  }

  /// Hourly rain intensity → 0 (none) .. 3 (very heavy).
  static int rainClass(double mmPerHour) {
    if (mmPerHour < 0.1) return 0;
    if (mmPerHour < 2.5) return 1;
    if (mmPerHour < 10) return 2;
    return 3;
  }
}
