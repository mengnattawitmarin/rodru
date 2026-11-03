import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/models.dart';

/// Rough shaking-intensity estimates (Modified Mercalli Intensity, MMI).
///
/// Uses a simple magnitude–distance attenuation
///   MMI ≈ 1.5·M − 3·log10(R) + 2,  R = hypocentral distance (km)
/// tuned so that e.g. the 2025 M7.7 Myanmar quake gives ~IV–V in Bangkok
/// (~1,000 km). It ignores soil amplification and fault direction, so it is
/// only a visual guide — USGS ShakeMap is shown instead when available.
class QuakeIntensity {
  static double estimate(double mag, double distKm, double depthKm) {
    final r = math.max(1.0, math.sqrt(distKm * distKm + depthKm * depthKm));
    return (1.5 * mag - 3.0 * math.log(r) / math.ln10 + 2.0).clamp(1.0, 12.0);
  }

  /// Epicentral radius (km) where intensity drops to [mmi]; 0 if never reached.
  static double radiusKm(double mag, double depthKm, double mmi) {
    final r = math.pow(10, (1.5 * mag + 2.0 - mmi) / 3.0).toDouble();
    if (r <= depthKm) return 0;
    return math.sqrt(r * r - depthKm * depthKm);
  }

  static String roman(double mmi) {
    const r = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI', 'XII'];
    return r[(mmi.round().clamp(1, 12)) - 1];
  }

  static String describe(double mmi) {
    final i = mmi.round();
    if (i <= 2) return 'แทบไม่รู้สึก';
    if (i == 3) return 'รู้สึกเบา ๆ เมื่ออยู่ในอาคาร';
    if (i == 4) return 'ของในบ้าน หน้าต่าง สั่นไหว';
    if (i == 5) return 'คนส่วนใหญ่รู้สึก ของเล็กล้ม';
    if (i == 6) return 'เดินลำบาก ของหนักขยับ ผนังร้าว';
    if (i == 7) return 'อาคารเสียหายเล็กน้อย–ปานกลาง';
    return 'อาคารเสียหายหนัก';
  }

  /// USGS ShakeMap colour scale.
  static Color color(double mmi) {
    final i = mmi.round();
    if (i <= 2) return const Color(0xFFBFCCFF);
    if (i == 3) return const Color(0xFFA0E6FF);
    if (i == 4) return const Color(0xFF80FFFF);
    if (i == 5) return const Color(0xFF7AFF93);
    if (i == 6) return const Color(0xFFFFFF00);
    if (i == 7) return const Color(0xFFFFC800);
    if (i == 8) return const Color(0xFFFF9100);
    if (i == 9) return const Color(0xFFFF0000);
    return const Color(0xFFC80000);
  }

  /// Could this event plausibly generate a tsunami (if it was under the sea)?
  static bool tsunamiPotential(Quake q) => q.tsunamiFlag || (q.mag >= 6.5 && q.depthKm <= 70);

  /// Very rough open-ocean tsunami speed for the Andaman Sea / Indian Ocean
  /// (√(g·h) with h ≈ 2.5 km ≈ 560 km/h). Waves slow down near the coast.
  static const tsunamiSpeedKmh = 560.0;
}
