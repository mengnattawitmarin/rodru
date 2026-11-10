import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/content.dart';
import '../logic/format.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'guide_page.dart';
import 'me_page.dart';
import 'sos_page.dart';

/// โหมดฉุกเฉิน (B4): black screen (saves battery on OLED), huge buttons, only
/// the essentials, nothing heavy is downloaded. Can be set as the start screen.
class EmergencyPage extends StatelessWidget {
  const EmergencyPage({super.key, this.asHome = false});

  /// True when shown as the app's first screen (emergency mode switched on).
  final bool asHome;

  static const _bg = Colors.black;
  static const _card = Color(0xFF141414);

  Future<void> _call(BuildContext context, String number, String name) async {
    if (await confirmCall(context, number, name) && context.mounted) callNumber(context, number);
  }

  void _showText(BuildContext context, String title, String text) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _card,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(text.isEmpty ? 'ยังไม่ได้กรอก — เพิ่มได้ในแท็บ "ฉัน"' : text, style: const TextStyle(fontSize: 18, height: 1.5)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final notices = s.visibleNotices.where((n) => n.level >= 1).toList();
    final plan = s.familyPlan;
    final planText = [
      if ((plan['meet1'] ?? '').isNotEmpty) 'จุดนัดพบใกล้บ้าน: ${plan['meet1']}',
      if ((plan['meet2'] ?? '').isNotEmpty) 'จุดนัดพบนอกพื้นที่: ${plan['meet2']}',
      if ((plan['outContact'] ?? '').isNotEmpty) 'ผู้ติดต่อนอกพื้นที่: ${plan['outContact']}',
      if ((plan['comm'] ?? '').isNotEmpty) 'ถ้าเครือข่ายล่ม: ${plan['comm']}',
      if ((plan['route'] ?? '').isNotEmpty) 'เส้นทางอพยพ: ${plan['route']}',
      if ((plan['shelter'] ?? '').isNotEmpty) 'ศูนย์พักพิง: ${plan['shelter']}',
      if ((plan['radio'] ?? '').isNotEmpty) 'ช่องทางรับประกาศ: ${plan['radio']}',
    ].join('\n\n');

    Widget bigCall(String number, String name, Color c, IconData icon) => Expanded(
          child: Semantics(
            button: true,
            label: 'โทร $number $name',
            child: Material(
              color: c.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _call(context, number, name),
                child: Container(
                  height: 124,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: c, width: 2)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(icon, color: c, size: 30),
                    Text(number, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: c)),
                    Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
          ),
        );

    Widget bigButton(String label, IconData icon, Color c, VoidCallback onTap, {Color fg = Colors.white}) => SizedBox(
          height: 64,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: c,
              foregroundColor: fg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            onPressed: onTap,
            icon: Icon(icon, size: 26),
            label: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
        );

    Widget tile(String label, IconData icon, VoidCallback onTap) => Material(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(children: [
                Icon(icon, size: 26, color: Colors.white70),
                const SizedBox(width: 14),
                Expanded(child: Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
                const Icon(Icons.chevron_right, color: Colors.white38),
              ]),
            ),
          ),
        );

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        automaticallyImplyLeading: !asHome,
        title: const Text('โหมดฉุกเฉิน', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (asHome)
            TextButton(
              onPressed: () => s.setEmergencyMode(false),
              child: const Text('ออกจากโหมดนี้', style: TextStyle(color: amber)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Text(
            '${s.location.name}${s.lastUpdated != null ? ' • ข้อมูลล่าสุด ${hhmm(s.lastUpdated)} น.' : ''}',
            style: const TextStyle(color: Colors.white60, fontSize: 14),
          ),
          const SizedBox(height: 10),
          for (final n in notices)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: levelColor(n.level).withValues(alpha: .15), borderRadius: BorderRadius.circular(14), border: Border.all(color: levelColor(n.level))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(n.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: levelColor(n.level))),
                if (n.body.isNotEmpty) Text(n.body, style: const TextStyle(fontSize: 15, height: 1.4)),
              ]),
            ),
          Row(children: [
            bigCall('1669', 'เจ็บป่วยฉุกเฉิน', red, Icons.medical_services),
            const SizedBox(width: 10),
            bigCall('191', 'เหตุด่วนเหตุร้าย', blue, Icons.local_police),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            bigCall('199', 'ดับเพลิง', const Color(0xFFFF9F43), Icons.fire_truck),
            const SizedBox(width: 10),
            bigCall('1784', 'ปภ.', amber, Icons.shield),
          ]),
          const SizedBox(height: 14),
          bigButton('ส่งตำแหน่งขอความช่วยเหลือ', Icons.share_location, red, () => shareSos(context, safe: false)),
          const SizedBox(height: 10),
          bigButton('แจ้งครอบครัวว่าฉันปลอดภัย', Icons.verified_user, green, () => shareSos(context, safe: true), fg: Colors.black),
          const SizedBox(height: 10),
          bigButton('ไฟสัญญาณ SOS', Icons.flashlight_on, const Color(0xFF333333),
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignalLightPage()))),
          if (s.contacts.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text('ผู้ติดต่อของฉัน', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (final c in s.contacts)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: tile('โทร ${c.name} ${c.phone}', Icons.call, () => callNumber(context, c.phone)),
              ),
          ],
          const SizedBox(height: 18),
          const Text('ข้อมูลที่ต้องใช้', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          tile('ข้อมูลทางการแพทย์ของฉัน', Icons.medical_information, () => _showText(context, 'ข้อมูลทางการแพทย์', s.medical.toShareText())),
          const SizedBox(height: 8),
          tile('แผนครอบครัว / จุดนัดพบ', Icons.family_restroom, () => _showText(context, 'แผนครอบครัว', planText)),
          const SizedBox(height: 8),
          tile('บัตรข้อมูลสมาชิก (${s.members.length})', Icons.badge,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MembersPage()))),
          const SizedBox(height: 18),
          const Text('คู่มือรับมือ (อ่านได้ไม่ต้องใช้เน็ต)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final h in hazards)
              ActionChip(
                backgroundColor: _card,
                avatar: Icon(h.icon, color: h.color, size: 20),
                label: Text(h.title, style: const TextStyle(fontSize: 15)),
                onPressed: () => openGuide(context, h),
              ),
          ]),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: s.emergencyMode,
                onChanged: (v) {
                  s.setEmergencyMode(v);
                  if (!v && !asHome) return;
                  if (v && !asHome) Navigator.pop(context);
                },
                title: const Text('เปิดแอปเข้าโหมดนี้ทุกครั้ง', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                subtitle: const Text('และหยุดโหลดข้อมูลหนัก (ระดับน้ำ รังสี) เพื่อประหยัดเน็ตและแบต', style: TextStyle(fontSize: 13)),
              ),
              const Text(
                'ประหยัดแบตเพิ่ม: ลดความสว่างจอ • เปิดโหมดประหยัดพลังงานของเครื่อง • ปิดแอปอื่น • โทรเฉพาะเมื่อจำเป็น ใช้ SMS แทนได้',
                style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
