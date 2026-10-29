import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/content.dart';
import '../logic/format.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'guide_page.dart';

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('การแจ้งเตือน')),
      body: RefreshIndicator(
        onRefresh: s.refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('พื้นที่: ${s.location.name}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 10),
            if (s.alerts.isEmpty)
              const Panel(
                child: Row(children: [
                  Icon(Icons.check_circle, color: green, size: 30),
                  SizedBox(width: 12),
                  Expanded(child: Text('ยังไม่พบความเสี่ยงจากพยากรณ์ใน 24 ชม. ข้างหน้า')),
                ]),
              ),
            for (final a in s.alerts)
              Panel(
                borderColor: levelColor(a.level).withValues(alpha: .6),
                onTap: () {
                  final h = hazardById(a.hazard);
                  if (h != null) openGuide(context, h);
                },
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(a.icon, color: levelColor(a.level)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                    Pill(a.level == 2 ? 'เตือนภัย' : 'เฝ้าระวัง', color: levelColor(a.level)),
                  ]),
                  const SizedBox(height: 6),
                  Text(a.detail, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  for (final act in a.actions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('•  ', style: TextStyle(color: green)),
                        Expanded(child: Text(act, style: const TextStyle(fontSize: 13))),
                      ]),
                    ),
                ]),
              ),
            const SizedBox(height: 8),
            const SectionTitle('ตรวจสอบประกาศทางการ'),
            for (final o in officialSources.take(3))
              InfoCard(icon: Icons.open_in_new, color: green, title: o.name, subtitle: o.desc, onTap: () => openWeb(context, o.url)),
            Disclaimer(
              'รายการนี้ประเมินอัตโนมัติจากข้อมูลพยากรณ์ ไม่ใช่ประกาศของรัฐ'
              '${s.lastUpdated != null ? ' • อัปเดต ${timeAgo(s.lastUpdated!)}' : ''}',
            ),
          ],
        ),
      ),
    );
  }
}
