import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../app_state.dart';
import '../data/content.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'emergency_page.dart';
import 'hotlines_page.dart';
import 'location_picker.dart';
import 'onboarding_page.dart';
import 'sos_page.dart';

class MePage extends StatelessWidget {
  const MePage({super.key});

  Future<void> _addContact(BuildContext context) async {
    final name = TextEditingController(), phone = TextEditingController(), rel = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: panel,
        title: const Text('เพิ่มผู้ติดต่อฉุกเฉิน'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'ชื่อ')),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'เบอร์โทร')),
          TextField(controller: rel, decoration: const InputDecoration(labelText: 'ความสัมพันธ์ (เช่น แม่, เพื่อนบ้าน)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('บันทึก')),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty && phone.text.trim().isNotEmpty && context.mounted) {
      await AppScope.read(context).addContact(EmergencyContact(name.text.trim(), phone.text.trim(), rel.text.trim()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const PageHeader('ฉัน', subtitle: 'ข้อมูลทั้งหมดเก็บในเครื่องนี้เท่านั้น'),

        InfoCard(
          icon: s.location.fromGps ? Icons.my_location : Icons.location_on,
          title: 'พื้นที่ของฉัน',
          subtitle: s.location.name,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LocationPickerPage())),
        ),
        InfoCard(
          icon: Icons.sos,
          color: red,
          title: 'หน้าขอความช่วยเหลือ (SOS)',
          subtitle: 'สายด่วน ส่งตำแหน่ง ไฟสัญญาณ',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SosPage())),
        ),

        SectionTitle('ผู้ติดต่อฉุกเฉิน', trailing: '+ เพิ่ม', onTrailing: () => _addContact(context)),
        if (s.contacts.isEmpty)
          InfoCard(
            icon: Icons.person_add_alt,
            color: amber,
            title: 'เพิ่มคนที่ควรรู้เมื่อคุณเกิดเหตุ',
            subtitle: 'ครอบครัว เพื่อนบ้าน หรือผู้นำชุมชน',
            onTap: () => _addContact(context),
          ),
        for (final c in s.contacts)
          Panel(
            child: Row(children: [
              const CircleAvatar(backgroundColor: panel2, child: Icon(Icons.person, color: blue)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${c.relation.isEmpty ? '' : '${c.relation} • '}${c.phone}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                ]),
              ),
              IconButton(onPressed: () => callNumber(context, c.phone), icon: const Icon(Icons.call, color: green)),
              IconButton(onPressed: () => s.removeContact(c), icon: const Icon(Icons.delete_outline, color: Colors.white38)),
            ]),
          ),

        const SectionTitle('ข้อมูลทางการแพทย์'),
        InfoCard(
          icon: Icons.medical_information,
          color: red,
          title: s.medical.isEmpty ? 'ยังไม่ได้กรอก' : (s.medical.fullName.isEmpty ? 'ข้อมูลของฉัน' : s.medical.fullName),
          subtitle: s.medical.isEmpty
              ? 'กรุ๊ปเลือด ยาที่แพ้ โรคประจำตัว — แนบไปกับข้อความ SOS'
              : [if (s.medical.bloodType.isNotEmpty) 'กรุ๊ป ${s.medical.bloodType}', if (s.medical.allergies.isNotEmpty) 'แพ้ ${s.medical.allergies}']
                  .join(' • '),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MedicalPage())),
        ),
        InfoCard(
          icon: Icons.family_restroom,
          title: 'แผนครอบครัว',
          subtitle: 'จุดนัดพบ เส้นทางอพยพ ติดต่อกันเมื่อเครือข่ายล่ม',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FamilyPlanPage())),
        ),
        InfoCard(
          icon: Icons.badge,
          color: amber,
          title: 'บัตรข้อมูลสมาชิกครอบครัว (${s.members.length})',
          subtitle: 'เด็ก ผู้สูงอายุ ผู้ป่วย — กรุ๊ปเลือด ยา เบอร์ผู้ปกครอง',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MembersPage())),
        ),

        SectionTitle('สายด่วนฉุกเฉิน', trailing: 'ดูทั้งหมด ${hotlineDirectory.length}', onTrailing: () => openHotlines(context)),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final h in hotlines)
            ActionChip(
              avatar: Icon(h.icon, color: h.color, size: 18),
              label: Text('${h.number} ${h.name}'),
              onPressed: () async {
                if (await confirmCall(context, h.number, h.name) && context.mounted) callNumber(context, h.number);
              },
            ),
        ]),

        const SectionTitle('การแสดงผล & โหมด'),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ขนาดตัวอักษร', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SegmentedButton<double>(
              segments: const [
                ButtonSegment(value: 1.0, label: Text('ปกติ')),
                ButtonSegment(value: 1.15, label: Text('ใหญ่')),
                ButtonSegment(value: 1.3, label: Text('ใหญ่มาก')),
              ],
              selected: {s.textScale},
              onSelectionChanged: (v) => s.setTextScale(v.first),
            ),
          ]),
        ),
        InfoCard(
          icon: Icons.battery_saver,
          color: amber,
          title: 'โหมดฉุกเฉิน (ประหยัดแบต)',
          subtitle: s.emergencyMode ? 'เปิดอยู่ — แอปจะเปิดเข้าโหมดนี้' : 'จอมืด ปุ่มใหญ่ เฉพาะสิ่งจำเป็น',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyPage())),
        ),
        InfoCard(
          icon: Icons.school,
          title: 'ดูหน้าแนะนำแอปอีกครั้ง',
          subtitle: 'ข้อจำกัดของแอป เลือกพื้นที่ ขนาดตัวอักษร',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OnboardingPage(replay: true))),
        ),

        const SectionTitle('เกี่ยวกับแอป'),
        InfoCard(
          icon: Icons.info_outline,
          title: 'RODRU รอดรู้ v0.4 (ต้นแบบทดลอง)',
          subtitle: 'แหล่งข้อมูล ข้อจำกัด และสัญญาอนุญาต',
          onTap: () => showAboutDialog(
            context: context,
            applicationName: 'RODRU รอดรู้',
            applicationVersion: '0.4.0',
            applicationLegalese: 'ต้นแบบเพื่อทดสอบ ไม่ใช่ระบบเตือนภัยทางการ',
            children: const [
              SizedBox(height: 12),
              Text(
                'แหล่งข้อมูล:\n'
                '• พยากรณ์อากาศ / ฝุ่น / ระดับน้ำทะเล: Open-Meteo (CC BY 4.0)\n'
                '• แผ่นดินไหว: USGS Earthquake Hazards Program\n'
                '• เรดาร์ฝน: RainViewer\n'
                '• แผนที่และสถานที่: © OpenStreetMap contributors (ODbL)\n'
                '• เส้นทาง: OSRM\n'
                '• ดวงอาทิตย์/ดวงจันทร์: คำนวณในเครื่อง (SunCalc)\n'
                '• ระดับน้ำ: ThaiWater (สสน.)\n'
                '• ระดับรังสีแกมมา: สำนักงานปรมาณูเพื่อสันติ (ปส.) รายงานรายสัปดาห์\n\n'
                'ข้อจำกัด: ระดับเฝ้าระวังคำนวณจากพยากรณ์ ไม่ใช่ประกาศของรัฐ '
                'จุดปลอดภัยยังไม่ได้ยืนยันโดยหน่วยงาน',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        InfoCard(
          icon: Icons.privacy_tip_outlined,
          title: 'นโยบายความเป็นส่วนตัว',
          subtitle: 'ข้อมูลอะไรเก็บที่ไหน — ทุกอย่างอยู่ในเครื่องคุณ',
          onTap: () => openWeb(context, 'https://github.com/mengnattawitmarin/rodru/blob/main/PRIVACY.md'),
        ),
        InfoCard(
          icon: Icons.delete_forever,
          color: Colors.white38,
          title: 'ล้างข้อมูลทั้งหมดในเครื่อง',
          subtitle: 'ผู้ติดต่อ ข้อมูลแพทย์ เช็กลิสต์ พื้นที่',
          onTap: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: panel,
                title: const Text('ล้างข้อมูลทั้งหมด?'),
                content: const Text('ข้อมูลที่บันทึกไว้จะหายและกู้คืนไม่ได้'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
                  FilledButton(style: FilledButton.styleFrom(backgroundColor: red), onPressed: () => Navigator.pop(ctx, true), child: const Text('ล้าง')),
                ],
              ),
            );
            if (ok == true) await s.resetAll();
          },
        ),
      ],
    );
  }
}

class MedicalPage extends StatefulWidget {
  const MedicalPage({super.key});
  @override
  State<MedicalPage> createState() => _MedicalPageState();
}

class _MedicalPageState extends State<MedicalPage> {
  late final TextEditingController _name, _allergies, _conditions, _meds;
  String _blood = '';
  static const _bloodTypes = ['', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'ไม่ทราบ'];

  @override
  void initState() {
    super.initState();
    final m = AppScope.read(context).medical;
    _name = TextEditingController(text: m.fullName);
    _allergies = TextEditingController(text: m.allergies);
    _conditions = TextEditingController(text: m.conditions);
    _meds = TextEditingController(text: m.medications);
    _blood = _bloodTypes.contains(m.bloodType) ? m.bloodType : '';
  }

  @override
  void dispose() {
    for (final c in [_name, _allergies, _conditions, _meds]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('ข้อมูลทางการแพทย์')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'ชื่อ-นามสกุล')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _blood,
            decoration: const InputDecoration(labelText: 'กรุ๊ปเลือด'),
            items: [for (final b in _bloodTypes) DropdownMenuItem(value: b, child: Text(b.isEmpty ? '— เลือก —' : b))],
            onChanged: (v) => setState(() => _blood = v ?? ''),
          ),
          const SizedBox(height: 12),
          TextField(controller: _allergies, decoration: const InputDecoration(labelText: 'แพ้ยา / แพ้อาหาร')),
          const SizedBox(height: 12),
          TextField(controller: _conditions, decoration: const InputDecoration(labelText: 'โรคประจำตัว')),
          const SizedBox(height: 12),
          TextField(controller: _meds, maxLines: 2, decoration: const InputDecoration(labelText: 'ยาที่ใช้ประจำ')),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            onPressed: () async {
              await AppScope.read(context).saveMedical(MedicalInfo(
                fullName: _name.text.trim(),
                bloodType: _blood,
                allergies: _allergies.text.trim(),
                conditions: _conditions.text.trim(),
                medications: _meds.text.trim(),
              ));
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('บันทึก'),
          ),
          const Disclaimer('เก็บในเครื่องเท่านั้น จะถูกแนบไปเมื่อคุณกดส่งข้อความ SOS เองเท่านั้น'),
        ]),
      );
}

class FamilyPlanPage extends StatefulWidget {
  const FamilyPlanPage({super.key});
  @override
  State<FamilyPlanPage> createState() => _FamilyPlanPageState();
}

class _FamilyPlanPageState extends State<FamilyPlanPage> {
  static const _fields = {
    'meet1': 'จุดนัดพบใกล้บ้าน',
    'meet2': 'จุดนัดพบนอกพื้นที่ (กรณีอพยพ)',
    'route': 'เส้นทางอพยพหลัก / สำรอง',
    'shelter': 'ศูนย์พักพิงที่ทางการกำหนด (ถามจาก อบต./เทศบาล)',
    'care': 'ใครดูแลเด็ก ผู้สูงอายุ ผู้ป่วย สัตว์เลี้ยง',
    'comm': 'ถ้าโทรศัพท์/เน็ตล่ม จะติดต่อกันยังไง (SMS, นัดเวลา, ฝากข้อความกับเพื่อนบ้าน)',
    'outContact': 'ผู้ติดต่อนอกพื้นที่ (ญาติต่างจังหวัด ชื่อ/เบอร์) — ทุกคนโทรแจ้งคนนี้',
    'radio': 'สถานีวิทยุ/ช่องทางรับประกาศในพื้นที่ และสัญญาณเตือนภัย',
    'notes': 'บันทึกอื่น ๆ (เบรกเกอร์ วาล์วแก๊ส ประกัน)',
  };
  late final Map<String, TextEditingController> _c;

  @override
  void initState() {
    super.initState();
    final plan = AppScope.read(context).familyPlan;
    _c = {for (final k in _fields.keys) k: TextEditingController(text: plan[k] ?? '')};
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('แผนครอบครัว')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          for (final e in _fields.entries) ...[
            TextField(controller: _c[e.key], maxLines: null, decoration: InputDecoration(labelText: e.value)),
            const SizedBox(height: 12),
          ],
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            onPressed: () async {
              await AppScope.read(context).saveFamilyPlan({for (final e in _c.entries) e.key: e.value.text.trim()});
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('บันทึก'),
          ),
          const Disclaimer('แนะนำให้พิมพ์หรือจดแผนนี้ไว้บนกระดาษด้วย เผื่อโทรศัพท์แบตหมด'),
        ]),
      );
}


class MembersPage extends StatelessWidget {
  const MembersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('บัตรข้อมูลสมาชิก')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'addMember',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MemberEditPage())),
        icon: const Icon(Icons.person_add),
        label: const Text('เพิ่มสมาชิก'),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 90), children: [
        const Disclaimer('ทำบัตรให้เด็ก ผู้สูงอายุ และผู้ป่วย — ตอนเกิดเหตุเปิดบัตรให้เจ้าหน้าที่ดู หรือแคปหน้าจอ/พิมพ์ติดตัวไว้ เก็บในเครื่องนี้เท่านั้น'),
        if (s.members.isEmpty)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('ยังไม่มีสมาชิก กด "เพิ่มสมาชิก"'))),
        for (final m in s.members)
          InfoCard(
            icon: Icons.badge,
            color: amber,
            title: m.name.isEmpty ? '(ไม่มีชื่อ)' : '${m.name}${m.nickname.isNotEmpty ? ' (${m.nickname})' : ''}',
            subtitle: [if (m.age.isNotEmpty) 'อายุ ${m.age}', if (m.bloodType.isNotEmpty) 'กรุ๊ป ${m.bloodType}', if (m.allergies.isNotEmpty) 'แพ้ ${m.allergies}']
                .join(' • '),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MemberCardPage(member: m))),
          ),
      ]),
    );
  }
}

/// Big, high-contrast card to show responders (or screenshot / print).
class MemberCardPage extends StatelessWidget {
  const MemberCardPage({super.key, required this.member});
  final FamilyMember member;

  @override
  Widget build(BuildContext context) {
    final m = member;
    Widget row(String k, String v) => v.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 120, child: Text(k, style: const TextStyle(color: Colors.black54, fontSize: 16))),
              Expanded(child: Text(v, style: const TextStyle(color: Colors.black, fontSize: 19, fontWeight: FontWeight.w700))),
            ]),
          );
    return Scaffold(
      appBar: AppBar(title: const Text('บัตรข้อมูลฉุกเฉิน'), actions: [
        IconButton(
          tooltip: 'แก้ไข',
          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MemberEditPage(member: m))),
          icon: const Icon(Icons.edit),
        ),
        IconButton(tooltip: 'แชร์', onPressed: () => Share.share(m.toShareText()), icon: const Icon(Icons.share)),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: red, width: 4)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.medical_information, color: red, size: 30),
              SizedBox(width: 8),
              Text('ข้อมูลฉุกเฉิน', style: TextStyle(color: red, fontSize: 22, fontWeight: FontWeight.w900)),
            ]),
            const SizedBox(height: 14),
            Text(m.name.isEmpty ? '-' : m.name, style: const TextStyle(color: Colors.black, fontSize: 28, fontWeight: FontWeight.w900)),
            if (m.nickname.isNotEmpty) Text('ชื่อเล่น ${m.nickname}', style: const TextStyle(color: Colors.black87, fontSize: 18)),
            const SizedBox(height: 14),
            row('อายุ', m.age),
            row('กรุ๊ปเลือด', m.bloodType),
            row('แพ้', m.allergies),
            row('โรคประจำตัว', m.conditions),
            row('ยาที่ใช้', m.medications),
            row('ติดต่อผู้ปกครอง', m.guardianPhone),
            row('หมายเหตุ', m.note),
          ]),
        ),
        const SizedBox(height: 12),
        if (m.guardianPhone.isNotEmpty)
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: green, foregroundColor: navy, minimumSize: const Size.fromHeight(52)),
            onPressed: () => callNumber(context, m.guardianPhone),
            icon: const Icon(Icons.call),
            label: Text('โทรผู้ปกครอง ${m.guardianPhone}'),
          ),
        const Disclaimer('แนะนำ: แคปหน้าจอบัตรนี้เก็บไว้ในอัลบั้ม หรือพิมพ์ใส่กระเป๋าเด็ก/ผู้สูงอายุ'),
      ]),
    );
  }
}

class MemberEditPage extends StatefulWidget {
  const MemberEditPage({super.key, this.member});
  final FamilyMember? member;
  @override
  State<MemberEditPage> createState() => _MemberEditPageState();
}

class _MemberEditPageState extends State<MemberEditPage> {
  static const _fields = {
    'name': 'ชื่อ-นามสกุล',
    'nickname': 'ชื่อเล่น',
    'age': 'อายุ',
    'bloodType': 'กรุ๊ปเลือด',
    'allergies': 'แพ้ยา/อาหาร',
    'conditions': 'โรคประจำตัว',
    'medications': 'ยาที่ใช้ประจำ',
    'guardianPhone': 'เบอร์ผู้ปกครอง/ผู้ดูแล',
    'note': 'หมายเหตุ (เช่น สื่อสารไม่ได้ ใช้รถเข็น)',
  };
  late final Map<String, TextEditingController> _c;

  @override
  void initState() {
    super.initState();
    final j = widget.member?.toJson() ?? const <String, dynamic>{};
    _c = {for (final k in _fields.keys) k: TextEditingController(text: (j[k] as String?) ?? '')};
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.member == null ? 'เพิ่มสมาชิก' : 'แก้ไขสมาชิก'),
          actions: [
            if (widget.member != null)
              IconButton(
                tooltip: 'ลบ',
                onPressed: () async {
                  await AppScope.read(context).removeMember(widget.member!);
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        ),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          for (final e in _fields.entries) ...[
            TextField(
              controller: _c[e.key],
              keyboardType: e.key == 'guardianPhone' ? TextInputType.phone : TextInputType.text,
              decoration: InputDecoration(labelText: e.value),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            onPressed: () async {
              final j = <String, dynamic>{
                'id': widget.member?.id ?? '${DateTime.now().microsecondsSinceEpoch}',
                for (final e in _c.entries) e.key: e.value.text.trim(),
              };
              await AppScope.read(context).saveMember(FamilyMember.fromJson(j));
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('บันทึก'),
          ),
        ]),
      );
}
