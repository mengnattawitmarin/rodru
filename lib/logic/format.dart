import 'dart:math' as math;

import 'package:flutter/material.dart';

String two(int n) => n.toString().padLeft(2, '0');
String hhmm(DateTime? t) => t == null ? '--:--' : '${two(t.hour)}:${two(t.minute)}';

const _thaiDays = ['จ.', 'อ.', 'พ.', 'พฤ.', 'ศ.', 'ส.', 'อา.'];
const _thaiMonths = ['ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'];

String thaiWeekday(DateTime d) => _thaiDays[d.weekday - 1];
String thaiDate(DateTime d) => '${d.day} ${_thaiMonths[d.month - 1]} ${d.year + 543}';
String thaiShortDate(DateTime d) => '${thaiWeekday(d)} ${d.day} ${_thaiMonths[d.month - 1]}';

String timeAgo(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 1) return 'เมื่อสักครู่';
  if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
  if (diff.inHours < 24) return '${diff.inHours} ชม.ที่แล้ว';
  return '${diff.inDays} วันที่แล้ว';
}

String distanceText(double meters) =>
    meters < 1000 ? '${meters.round()} ม.' : '${(meters / 1000).toStringAsFixed(meters < 10000 ? 1 : 0)} กม.';

String durationText(double seconds) {
  final m = (seconds / 60).round();
  if (m < 60) return '$m นาที';
  return '${m ~/ 60} ชม. ${m % 60} นาที';
}

/// Great-circle distance in metres.
double haversine(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  final dLat = _rad(lat2 - lat1), dLon = _rad(lon2 - lon1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(lat1)) * math.cos(_rad(lat2)) * math.pow(math.sin(dLon / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}

/// Initial bearing in degrees (0 = north, clockwise).
double bearing(double lat1, double lon1, double lat2, double lon2) {
  final y = math.sin(_rad(lon2 - lon1)) * math.cos(_rad(lat2));
  final x = math.cos(_rad(lat1)) * math.sin(_rad(lat2)) -
      math.sin(_rad(lat1)) * math.cos(_rad(lat2)) * math.cos(_rad(lon2 - lon1));
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

double _rad(double d) => d * math.pi / 180;

String compassThai(double deg) {
  const names = ['เหนือ', 'ตะวันออกเฉียงเหนือ', 'ตะวันออก', 'ตะวันออกเฉียงใต้', 'ใต้', 'ตะวันตกเฉียงใต้', 'ตะวันตก', 'ตะวันตกเฉียงเหนือ'];
  return names[((deg % 360) / 45).round() % 8];
}

String compassShort(double deg) {
  const names = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  return names[((deg % 360) / 45).round() % 8];
}

/// WMO weather code → Thai description.
String weatherText(int code) {
  if (code == 0) return 'ท้องฟ้าแจ่มใส';
  if (code == 1) return 'มีเมฆเล็กน้อย';
  if (code == 2) return 'มีเมฆบางส่วน';
  if (code == 3) return 'มีเมฆมาก';
  if (code == 45 || code == 48) return 'มีหมอก';
  if (code >= 51 && code <= 57) return 'ฝนละออง';
  if (code == 61 || code == 80) return 'ฝนตกเล็กน้อย';
  if (code == 63 || code == 81) return 'ฝนตกปานกลาง';
  if (code == 65 || code == 82) return 'ฝนตกหนัก';
  if (code == 66 || code == 67) return 'ฝนเยือกแข็ง';
  if (code >= 71 && code <= 86) return 'หิมะ/ลูกเห็บ';
  if (code == 95) return 'พายุฝนฟ้าคะนอง';
  if (code == 96 || code == 99) return 'พายุฝนฟ้าคะนองและลูกเห็บ';
  return 'ตรวจสอบสภาพอากาศ';
}

IconData weatherIcon(int code, {bool isDay = true}) {
  if (code == 0) return isDay ? Icons.wb_sunny_rounded : Icons.nightlight_round;
  if (code <= 2) return isDay ? Icons.wb_cloudy_outlined : Icons.nights_stay_outlined;
  if (code == 3) return Icons.cloud;
  if (code == 45 || code == 48) return Icons.foggy;
  if (code >= 95) return Icons.thunderstorm;
  if (code >= 51 && code <= 82) return Icons.water_drop;
  return Icons.cloud_outlined;
}

Color weatherColor(int code) {
  if (code >= 95) return const Color(0xFFFFC857);
  if (code >= 51 && code <= 82) return const Color(0xFF39A9FF);
  if (code == 0 || code == 1) return const Color(0xFFFFC857);
  return Colors.white70;
}
