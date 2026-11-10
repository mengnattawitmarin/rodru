import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import 'location_picker.dart';

/// First-run introduction (C5): what the app is (and is not), choose the area,
/// pick a text size. Shown once; can be re-opened from the "ฉัน" tab.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, this.replay = false});

  /// Opened again from settings: finishing just closes the page.
  final bool replay;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pc = PageController();
  int _page = 0;
  bool _locating = false;
  String? _msg;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < 2) {
      _pc.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final s = AppScope.read(context);
    if (widget.replay) {
      Navigator.pop(context);
      return;
    }
    await s.setOnboarded();
  }

  Future<void> _gps() async {
    setState(() {
      _locating = true;
      _msg = null;
    });
    final err = await AppScope.read(context).useGps();
    if (!mounted) return;
    setState(() {
      _locating = false;
      _msg = err ?? 'ใช้ตำแหน่งปัจจุบันแล้ว ✓';
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    Widget page({required IconData icon, required Color color, required String title, required List<Widget> children}) => ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            Icon(icon, size: 64, color: color),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, height: 1.25)),
            const SizedBox(height: 14),
            ...children,
          ],
        );
    Widget bullet(String t, {Color c = green, IconData icon = Icons.check_circle}) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: c, size: 22),
            const SizedBox(width: 10),
            Expanded(child: Text(t, style: const TextStyle(fontSize: 16, height: 1.45))),
          ]),
        );

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: PageView(
              controller: _pc,
              onPageChanged: (i) => setState(() => _page = i),
              children: [
                page(
                  icon: Icons.shield,
                  color: blue,
                  title: 'ยินดีต้อนรับสู่ รอดรู้\nรู้ก่อน เตรียมตัวทัน',
                  children: [
                    bullet('สรุปอากาศ ฝุ่น น้ำ แผ่นดินไหว และรังสี ใกล้ตัวคุณ'),
                    bullet('ปุ่ม SOS โทรสายด่วน ส่งตำแหน่งให้ครอบครัว'),
                    bullet('คู่มือรับมือภัย 10 แบบ อ่านได้แม้ไม่มีเน็ต'),
                    const SizedBox(height: 8),
                    bullet('ระดับเตือนในแอปประเมินจากข้อมูลพยากรณ์ ไม่ใช่ประกาศทางการ', c: amber, icon: Icons.info),
                    bullet('เกิดเหตุจริง ให้ทำตามเจ้าหน้าที่และโทร 191 / 1669 / 199 ทันที', c: red, icon: Icons.warning_amber_rounded),
                    bullet('ข้อมูลส่วนตัวทั้งหมดเก็บในเครื่องนี้ ไม่ส่งขึ้นเซิร์ฟเวอร์', c: green, icon: Icons.lock),
                  ],
                ),
                page(
                  icon: Icons.location_on,
                  color: green,
                  title: 'เลือกพื้นที่ของคุณ',
                  children: [
                    const Text('ใช้เพื่อแสดงอากาศ ความเสี่ยง และจุดปลอดภัยใกล้คุณ ตำแหน่งใช้ในเครื่องเท่านั้น',
                        style: TextStyle(fontSize: 15, color: Colors.white70, height: 1.4)),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: _locating ? null : _gps,
                        icon: _locating
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.my_location),
                        label: const Text('ใช้ตำแหน่งปัจจุบัน (GPS)', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LocationPickerPage())),
                        icon: const Icon(Icons.search),
                        label: const Text('ค้นหาอำเภอ / จังหวัด', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('พื้นที่ตอนนี้: ${s.location.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    if (_msg != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_msg!, style: const TextStyle(color: amber))),
                  ],
                ),
                page(
                  icon: Icons.text_fields,
                  color: amber,
                  title: 'ขนาดตัวอักษร',
                  children: [
                    const Text('เลือกขนาดที่อ่านสบาย เปลี่ยนภายหลังได้ในแท็บ "ฉัน"',
                        style: TextStyle(fontSize: 15, color: Colors.white70)),
                    const SizedBox(height: 14),
                    for (final o in const [(1.0, 'ปกติ'), (1.15, 'ใหญ่'), (1.3, 'ใหญ่มาก')])
                      RadioListTile<double>(
                        value: o.$1,
                        groupValue: s.textScale,
                        onChanged: (v) => s.setTextScale(v ?? 1.0),
                        title: Text(o.$2, style: TextStyle(fontSize: 16 * o.$1, fontWeight: FontWeight.w700)),
                      ),
                    const SizedBox(height: 14),
                    const Text('แนะนำต่อจากนี้: เพิ่มผู้ติดต่อฉุกเฉินและข้อมูลทางการแพทย์ในแท็บ "ฉัน" แล้วเช็กกระเป๋าฉุกเฉินในแท็บ "เตรียมพร้อม"',
                        style: TextStyle(fontSize: 15, height: 1.45)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Row(children: [
              for (var i = 0; i < 3; i++)
                Container(
                  width: i == _page ? 22 : 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(color: i == _page ? blue : Colors.white24, borderRadius: BorderRadius.circular(4)),
                ),
              const Spacer(),
              if (_page < 2) TextButton(onPressed: _finish, child: const Text('ข้าม')),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(120, 50)),
                onPressed: _next,
                child: Text(_page < 2 ? 'ถัดไป' : 'เริ่มใช้งาน', style: const TextStyle(fontSize: 16)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
