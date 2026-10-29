import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/content.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'guide_page.dart';
import 'me_page.dart';

class ReadyPage extends StatelessWidget {
  const ReadyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final all = [...goBag, ...homePrep];
    final done = all.where((i) => s.checklistDone.contains(i.id)).length;
    final pct = all.isEmpty ? 0.0 : done / all.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const PageHeader('เตรียมพร้อม', subtitle: 'ใช้ได้แม้ไม่มีอินเทอร์เน็ต'),

        // ---- readiness score ----
        Panel(
          color: panel2,
          child: Row(children: [
            SizedBox(
              width: 74,
              height: 74,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: pct,
                    strokeWidth: 8,
                    backgroundColor: Colors.white12,
                    color: pct >= .8 ? green : pct >= .4 ? amber : red,
                  ),
                ),
                Text('${(pct * 100).round()}%', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ]),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('ความพร้อมของฉัน', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('เตรียมแล้ว $done จาก ${all.length} รายการ', style: const TextStyle(color: Colors.white70)),
                Text(
                  pct >= .8 ? 'ยอดเยี่ยม! ตรวจของหมดอายุทุก 6 เดือน' : 'ค่อย ๆ เตรียมทีละอย่างก็ได้',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ]),
            ),
          ]),
        ),

        // ---- guides ----
        const SectionTitle('คู่มือรับมือภัย'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.4,
          children: [
            for (final h in hazards)
              Panel(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                onTap: () => openGuide(context, h),
                child: Row(children: [
                  Icon(h.icon, color: h.color, size: 26),
                  const SizedBox(width: 10),
                  Expanded(child: Text(h.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                ]),
              ),
          ],
        ),
        const SizedBox(height: 10),

        // ---- go bag ----
        _ChecklistSection(title: 'กระเป๋าฉุกเฉิน (Go-Bag)', icon: Icons.backpack, items: goBag),
        _ChecklistSection(title: 'แผนครอบครัว & บ้าน', icon: Icons.family_restroom, items: homePrep),

        InfoCard(
          icon: Icons.edit_note,
          title: 'บันทึกแผนครอบครัว',
          subtitle: s.familyPlan['meet1']?.isNotEmpty == true ? 'จุดนัดพบ: ${s.familyPlan['meet1']}' : 'จุดนัดพบ เส้นทางอพยพ ผู้ดูแลเด็ก/ผู้สูงอายุ',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FamilyPlanPage())),
        ),
        const Disclaimer('คำแนะนำเป็นข้อมูลทั่วไป ให้ยึดคำสั่งเจ้าหน้าที่และแนวทางของหน่วยงานในพื้นที่เป็นหลัก'),
      ],
    );
  }
}

class _ChecklistSection extends StatelessWidget {
  const _ChecklistSection({required this.title, required this.icon, required this.items});
  final String title;
  final IconData icon;
  final List<ChecklistItem> items;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final done = items.where((i) => s.checklistDone.contains(i.id)).length;
    final cats = <String>[];
    for (final i in items) {
      if (!cats.contains(i.category)) cats.add(i.category);
    }
    return Panel(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(icon, color: blue),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('$done/${items.length} รายการ', style: const TextStyle(fontSize: 12, color: Colors.white60)),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          children: [
            for (final c in cats) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
                child: Align(alignment: Alignment.centerLeft, child: Text(c, style: const TextStyle(color: amber, fontSize: 12))),
              ),
              for (final i in items.where((e) => e.category == c))
                CheckboxListTile(
                  dense: true,
                  value: s.checklistDone.contains(i.id),
                  onChanged: (_) => s.toggleCheck(i.id),
                  title: Text(i.label, style: const TextStyle(fontSize: 13)),
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: green,
                ),
            ],
          ],
        ),
      ),
    );
  }
}
