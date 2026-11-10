import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/content.dart';
import '../logic/daily_brief.dart';
import '../logic/format.dart';
import '../main.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'alerts_page.dart';
import 'emergency_page.dart';
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
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
              tooltip: 'โหมดฉุกเฉิน (ประหยัดแบต)',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyPage())),
              icon: const Icon(Icons.battery_saver),
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
                isLabelVisible: s.alerts.isNotEmpty || s.activeNotices.isNotEmpty,
                label: Text('${s.alerts.length + s.activeNotices.length}'),
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

          // ---- notices from the app owner (data/announcements.json) ----
          for (final n in s.visibleNotices) _NoticeCard(n),

          // ---- daily brief (TV-weather style) ----
          _BriefCard(state: s, loading: s.loading && f == null),

          // ---- weather detail ----
          if (f != null) ...[
            const SectionTitle('พยากรณ์รายชั่วโมง'),
            _HourlyStrip(hours: f.hours.take(24).toList()),
            const SizedBox(height: 10),
          ],
          if (s.air != null) _AirCard(air: s.air!),
          _WaterNearCard(state: s),

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

          // ---- what to do now + SOS (moved to the bottom; floating SOS stays on screen) ----
          const SizedBox(height: 8),
          _WhatToDo(top: top),
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

class _BriefCard extends StatelessWidget {
  const _BriefCard({required this.state, required this.loading});
  final AppState state;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final f = state.forecast;
    if (f == null) {
      return Panel(
        padding: const EdgeInsets.all(18),
        child: SizedBox(
          height: 140,
          child: Center(
            child: loading
                ? const CircularProgressIndicator()
                : const Text('ยังไม่มีข้อมูลอากาศ ดึงลงเพื่อลองใหม่', style: TextStyle(color: Colors.white60)),
          ),
        ),
      );
    }
    final b = DailyBriefBuilder().build(f: f, air: state.air, alerts: state.alerts);
    final c = levelColor(b.level);
    final top = state.alerts.isEmpty ? null : state.alerts.first;

    Widget section(String label, String text, {IconData? icon}) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 62,
              child: Text(label, style: const TextStyle(color: amber, fontSize: 12, fontWeight: FontWeight.w800, height: 1.5)),
            ),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 14, height: 1.45))),
          ]),
        );

    Widget chip(BriefChip ch, {bool lifestyle = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: (lifestyle ? (ch.good ? green : Colors.white38) : blue).withValues(alpha: .15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: (lifestyle ? (ch.good ? green : Colors.white24) : blue).withValues(alpha: .5)),
          ),
          child: Text('${ch.emoji} ${ch.label}', style: TextStyle(fontSize: 12.5, color: lifestyle && !ch.good ? Colors.white60 : Colors.white)),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: b.level == 2
              ? const [Color(0xFF5A1F28), Color(0xFF231A2E)]
              : b.level == 1
                  ? const [Color(0xFF4A3A1A), Color(0xFF14273D)]
                  : const [panel2, panel],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: c.withValues(alpha: .45)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // greeting + temperature
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${b.greeting} • ${state.location.name}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 6),
              if (b.level > 0) ...[
                Pill(b.level == 2 ? 'เตือนภัย' : 'เฝ้าระวัง', color: c),
                const SizedBox(height: 6),
              ],
              Text(b.headline, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, height: 1.25)),
              if (top != null) ...[
                const SizedBox(height: 4),
                Text(top.detail, style: TextStyle(color: c, fontSize: 13)),
              ],
            ]),
          ),
          const SizedBox(width: 10),
          Column(children: [
            Icon(top?.icon ?? weatherIcon(f.code, isDay: f.isDay), size: 40, color: top != null ? c : weatherColor(f.code)),
            Text('${f.temp.round()}°', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, height: 1.1)),
          ]),
        ]),
        const SizedBox(height: 8),
        Text(
          '${weatherText(f.code)} • รู้สึกเหมือน ${f.feels.round()}° • ชื้น ${f.humidity}% • ลม ${f.wind.round()} (กระโชก ${f.gust.round()}) กม./ชม.',
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        const Divider(height: 18, color: Colors.white12),
        if (b.today.isNotEmpty) section('วันนี้', b.today.join('\n')),
        if (b.tomorrow != null) section('พรุ่งนี้', b.tomorrow!),
        if (b.bring.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(width: 62, child: Text('ต้องพก', style: TextStyle(color: amber, fontSize: 12, fontWeight: FontWeight.w800, height: 2))),
            Expanded(child: Wrap(spacing: 6, runSpacing: 6, children: [for (final ch in b.bring) chip(ch)])),
          ]),
        ],
        if (b.lookahead != null) section('ข้างหน้า', b.lookahead!),
        if (b.lifestyle.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final ch in b.lifestyle) chip(ch, lifestyle: true)]),
        ],
        const SizedBox(height: 10),
        Text(
          b.serious ? 'ข้อมูลประเมินจากพยากรณ์ — ทำตามประกาศทางการและเจ้าหน้าที่เป็นหลัก' : 'คำแนะนำจากพยากรณ์ ไม่ใช่ประกาศทางการ',
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ]),
    );
  }
}

class _WaterNearCard extends StatelessWidget {
  const _WaterNearCard({required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    final w = state.nearestWaterStation();
    if (w == null) return const SizedBox.shrink();
    final d = haversine(state.location.lat, state.location.lon, w.lat, w.lon);
    return Panel(
      onTap: () => ShellController.go(context, Tabs.map),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(shape: BoxShape.circle, color: w.color.withValues(alpha: .15), border: Border.all(color: w.color, width: 2)),
          child: Icon(w.trend > 0 ? Icons.trending_up : w.trend < 0 ? Icons.trending_down : Icons.water, color: w.color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ระดับน้ำใกล้คุณ • ${w.situationLabel}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(
              '${w.name}${w.river.isNotEmpty ? ' (${w.river})' : ''} • ห่าง ${distanceText(d)}\n'
              '${w.bankText ?? 'ระดับ ${w.levelMsl?.toStringAsFixed(2)} ม.รทก.'}'
              '${w.trend > 0 ? ' • น้ำกำลังขึ้น' : w.trend < 0 ? ' • น้ำกำลังลง' : ''} • ${hhmm(w.time)} น.',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ]),
        ),
        const Icon(Icons.chevron_right, color: Colors.white38),
      ]),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard(this.n);
  final Notice n;
  @override
  Widget build(BuildContext context) {
    final c = n.level == 0 ? blue : levelColor(n.level);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.withValues(alpha: .7), width: n.level >= 2 ? 2 : 1),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(n.level >= 2 ? Icons.campaign : Icons.info_outline, color: c, size: 26),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ประกาศ • ${n.title}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: c)),
            if (n.body.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(n.body, style: const TextStyle(fontSize: 14, height: 1.4)),
            ],
            if (n.link != null)
              TextButton.icon(
                style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                onPressed: () => openWeb(context, n.link!),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('อ่านประกาศฉบับเต็ม'),
              ),
          ]),
        ),
        if (n.level < 2)
          IconButton(
            tooltip: 'ซ่อนประกาศนี้',
            visualDensity: VisualDensity.compact,
            onPressed: () => AppScope.read(context).dismissNotice(n),
            icon: const Icon(Icons.close, size: 20, color: Colors.white54),
          ),
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
                Text(i == 0 ? 'ตอนนี้' : '${two(h.time.hour)}:00', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                Icon(weatherIcon(h.code, isDay: h.time.hour >= 6 && h.time.hour < 18), color: weatherColor(h.code), size: 22),
                Text('${h.temp.round()}°', style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('${h.precipProb}%', style: const TextStyle(fontSize: 12, color: blue)),
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
              style: TextStyle(fontSize: 12, color: d.precipSum >= 35 ? red : blue)),
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
