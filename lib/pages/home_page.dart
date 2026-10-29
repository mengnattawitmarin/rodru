import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/content.dart';
import '../logic/format.dart';
import '../main.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'alerts_page.dart';
import 'guide_page.dart';
import 'location_picker.dart';
import 'sos_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final f = s.forecast;
    final top = s.alerts.isEmpty ? null : s.alerts.first;

    return RefreshIndicator(
      onRefresh: s.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // ---- header ----
          Row(children: [
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('รอดรู้', style: TextStyle(fontSize: 31, fontWeight: FontWeight.w900, letterSpacing: -.8, height: 1.1)),
                Text('RODRU  •  รู้ก่อน เตรียมตัวทัน', style: TextStyle(color: Colors.white60, fontSize: 12)),
              ]),
            ),
            IconButton(
              tooltip: 'อัปเดต',
              onPressed: s.loading ? null : s.refresh,
              icon: s.loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'การแจ้งเตือน',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AlertsPage())),
              icon: Badge(
                isLabelVisible: s.alerts.isNotEmpty,
                label: Text('${s.alerts.length}'),
                backgroundColor: red,
                child: const Icon(Icons.notifications_none_rounded, size: 27),
              ),
            ),
          ]),
          const SizedBox(height: 12),

          // ---- location ----
          Row(children: [
            Icon(s.location.fromGps ? Icons.my_location : Icons.location_on, color: blue, size: 20),
            const SizedBox(width: 6),
            Expanded(
              child: Text(s.location.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, shape: const StadiumBorder()),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LocationPickerPage())),
              child: const Text('เปลี่ยนพื้นที่'),
            ),
          ]),
          const SizedBox(height: 10),

          if (s.error != null)
            Panel(
              color: const Color(0xFF2B2230),
              child: Row(children: [
                const Icon(Icons.wifi_off, color: amber, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(s.error!, style: const TextStyle(fontSize: 12))),
                TextButton(onPressed: s.refresh, child: const Text('ลองใหม่')),
              ]),
            ),

          // ---- status banner ----
          _StatusBanner(top: top, forecast: f, loading: s.loading && f == null),

          // ---- what to do now ----
          _WhatToDo(top: top),

          // ---- SOS ----
          const SizedBox(height: 2),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SosPage())),
              icon: const Icon(Icons.call, size: 26),
              label: const Text('SOS  ขอความช่วยเหลือด่วน', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 14),

          // ---- weather detail ----
          if (f != null) ...[
            const SectionTitle('พยากรณ์รายชั่วโมง'),
            _HourlyStrip(hours: f.hours.take(24).toList()),
            const SizedBox(height: 10),
          ],
          if (s.air != null) _AirCard(air: s.air!),

          // ---- hazards ----
          SectionTitle('สถานการณ์ & ภัยพิบัติ', trailing: 'คู่มือทั้งหมด', onTrailing: () => ShellController.go(context, Tabs.ready)),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: .95,
            children: [
              for (final h in hazards)
                ActionTile(
                  icon: h.icon,
                  title: h.title.split('/').first,
                  color: h.color,
                  highlight: s.alerts.any((a) => a.hazard == h.id),
                  onTap: () => openGuide(context, h),
                ),
            ],
          ),
          const SizedBox(height: 14),

          if (f != null && f.days.isNotEmpty) ...[
            const SectionTitle('พยากรณ์ 7 วัน'),
            Panel(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), child: Column(children: [for (final d in f.days) _DayRow(d)])),
          ],

          // ---- earthquakes ----
          if (s.quakes.isNotEmpty) ...[
            SectionTitle('แผ่นดินไหวล่าสุดในภูมิภาค', trailing: 'ดูบนแผนที่', onTrailing: () => ShellController.go(context, Tabs.map)),
            for (final q in s.quakes.take(3))
              InfoCard(
                icon: Icons.vibration,
                color: q.mag >= 5 ? red : q.mag >= 4 ? amber : Colors.white70,
                title: 'M${q.mag.toStringAsFixed(1)}  •  ห่าง ${distanceText(haversine(s.location.lat, s.location.lon, q.lat, q.lon))}',
                subtitle: '${q.place}\n${timeAgo(q.time)} • ลึก ${q.depthKm.round()} กม.',
                onTap: () => openWeb(context, q.url),
              ),
          ],

          // ---- official sources ----
          const SectionTitle('แหล่งประกาศทางการ'),
          for (final o in officialSources)
            InfoCard(icon: Icons.verified_outlined, color: green, title: o.name, subtitle: o.desc, onTap: () => openWeb(context, o.url)),

          const SizedBox(height: 6),
          Disclaimer(
            'ระดับเฝ้าระวังในแอปคำนวณจากพยากรณ์ Open-Meteo / USGS ไม่ใช่ประกาศทางการ '
            'เมื่อเกิดเหตุให้ยึดคำสั่งเจ้าหน้าที่และประกาศ Cell Broadcast เป็นหลัก'
            '${s.lastUpdated != null ? '\nอัปเดตล่าสุด ${hhmm(s.lastUpdated)} น.${s.forecastFromCache ? ' (ข้อมูลที่บันทึกไว้)' : ''}' : ''}',
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.top, required this.forecast, required this.loading});
  final RiskAlert? top;
  final Forecast? forecast;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final f = forecast;
    final level = top?.level ?? 0;
    final c = levelColor(level);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: level == 2
              ? const [Color(0xFF5A1F28), Color(0xFF231A2E)]
              : level == 1
                  ? const [Color(0xFF4A3A1A), Color(0xFF14273D)]
                  : const [panel2, panel],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: c.withValues(alpha: .45)),
      ),
      child: loading
          ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(top?.icon ?? (f == null ? Icons.cloud_off : weatherIcon(f.code, isDay: f.isDay)),
                    size: 54, color: top != null ? c : (f == null ? Colors.white38 : weatherColor(f.code))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Pill(level == 2 ? 'เตือนภัย' : level == 1 ? 'เฝ้าระวัง' : 'สถานการณ์ปกติ', color: c),
                    const SizedBox(height: 6),
                    Text(top?.title ?? (f == null ? 'ยังไม่มีข้อมูล' : weatherText(f.code)),
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, height: 1.2)),
                    if (top != null) ...[
                      const SizedBox(height: 4),
                      Text(top!.detail, style: TextStyle(color: c, fontSize: 13)),
                    ],
                  ]),
                ),
              ]),
              if (f != null) ...[
                const Divider(height: 22, color: Colors.white12),
                Row(children: [
                  Text('${f.temp.round()}°', style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w800, height: 1)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${weatherText(f.code)}\nรู้สึกเหมือน ${f.feels.round()}° • ความชื้น ${f.humidity}%\n'
                      'ฝน ${f.precip.toStringAsFixed(1)} มม. • ลม ${f.wind.round()} (กระโชก ${f.gust.round()}) กม./ชม.',
                      style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                    ),
                  ),
                ]),
              ],
            ]),
    );
  }
}

class _WhatToDo extends StatelessWidget {
  const _WhatToDo({required this.top});
  final RiskAlert? top;

  @override
  Widget build(BuildContext context) {
    final actions = top?.actions.isNotEmpty == true
        ? top!.actions
        : const ['เช็กกระเป๋าฉุกเฉินให้พร้อม', 'บันทึกเบอร์ติดต่อฉุกเฉินในหน้า "ฉัน"', 'รู้เส้นทางไปจุดปลอดภัยใกล้บ้าน'];
    final hazard = top == null ? null : hazardById(top!.hazard);
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(top == null ? 'เตรียมพร้อมไว้ก่อน' : 'ควรทำอะไรตอนนี้',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          if (hazard != null)
            InkWell(
              onTap: () => openGuide(context, hazard),
              child: const Padding(padding: EdgeInsets.all(4), child: Text('ดูทั้งหมด', style: TextStyle(color: blue, fontSize: 12))),
            ),
        ]),
        const SizedBox(height: 8),
        for (var i = 0; i < actions.length && i < 4; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.check_circle, color: green, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('${i + 1}. ${actions[i]}', style: const TextStyle(fontSize: 13, height: 1.35))),
            ]),
          ),
      ]),
    );
  }
}

class _HourlyStrip extends StatelessWidget {
  const _HourlyStrip({required this.hours});
  final List<HourPoint> hours;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 112,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: hours.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final h = hours[i];
            return Container(
              width: 62,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: panel,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: h.precip >= 10 ? red : h.precip >= 2.5 ? amber : Colors.white10),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                Text(i == 0 ? 'ตอนนี้' : '${two(h.time.hour)}:00', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                Icon(weatherIcon(h.code, isDay: h.time.hour >= 6 && h.time.hour < 18), color: weatherColor(h.code), size: 22),
                Text('${h.temp.round()}°', style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('${h.precipProb}%', style: const TextStyle(fontSize: 10, color: blue)),
              ]),
            );
          },
        ),
      );
}

class _DayRow extends StatelessWidget {
  const _DayRow(this.d);
  final DayPoint d;
  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isToday = d.date.day == today.day && d.date.month == today.month;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        SizedBox(width: 74, child: Text(isToday ? 'วันนี้' : thaiShortDate(d.date), style: const TextStyle(fontSize: 13))),
        Icon(weatherIcon(d.code), color: weatherColor(d.code), size: 20),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text('${d.precipProbMax}% ${d.precipSum >= 0.5 ? '${d.precipSum.toStringAsFixed(0)}มม.' : ''}',
              style: TextStyle(fontSize: 11, color: d.precipSum >= 35 ? red : blue)),
        ),
        const Spacer(),
        Text('${d.tMin.round()}°', style: const TextStyle(color: Colors.white54)),
        const SizedBox(width: 6),
        Text('${d.tMax.round()}°', style: const TextStyle(fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _AirCard extends StatelessWidget {
  const _AirCard({required this.air});
  final AirQuality air;
  @override
  Widget build(BuildContext context) => Panel(
        onTap: () {
          final h = hazardById('pm25');
          if (h != null) openGuide(context, h);
        },
        child: Row(children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: air.bandColor.withValues(alpha: .18), border: Border.all(color: air.bandColor, width: 2)),
            child: Text('${air.pm25.round()}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: air.bandColor)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('PM2.5 • ${air.bandLabel}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 3),
              Text(
                'µg/m³ • PM10 ${air.pm10.round()}${air.pm25Next24h.isNotEmpty ? ' • สูงสุด 24 ชม. ~${air.pm25Next24h.reduce((a, b) => a > b ? a : b).round()}' : ''}\n'
                'ค่าจากแบบจำลอง CAMS — ดูค่าสถานีจริงที่ Air4Thai',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ]),
          ),
        ]),
      );
}
