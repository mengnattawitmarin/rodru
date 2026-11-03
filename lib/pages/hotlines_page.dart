import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../data/content.dart';
import '../theme.dart';
import '../widgets/common.dart';

void openHotlines(BuildContext context) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => const HotlinesPage()));

/// สมุดเบอร์ฉุกเฉิน — searchable, grouped, pin favourites. Works offline.
class HotlinesPage extends StatefulWidget {
  const HotlinesPage({super.key});
  @override
  State<HotlinesPage> createState() => _HotlinesPageState();
}

class _HotlinesPageState extends State<HotlinesPage> {
  String _q = '';

  bool _match(Hotline h) {
    if (_q.isEmpty) return true;
    final q = _q.toLowerCase();
    return h.number.contains(q) || h.name.toLowerCase().contains(q) || h.desc.toLowerCase().contains(q) || h.category.contains(q);
  }

  Future<void> _call(Hotline h) async {
    if (await confirmCall(context, h.number, h.name) && mounted) callNumber(context, h.number);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final all = hotlineDirectory.where(_match).toList();
    final pinned = all.where((h) => s.pinnedHotlines.contains(h.number)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('สมุดเบอร์ฉุกเฉิน')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          TextField(
            onChanged: (v) => setState(() => _q = v.trim()),
            decoration: InputDecoration(
              hintText: 'ค้นหา เช่น ไฟดับ, รถพยาบาล, 1669',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: panel,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 8),
          if (pinned.isNotEmpty) ...[
            const SectionTitle('⭐ ปักหมุดไว้'),
            for (final h in pinned) _HotlineTile(h, pinned: true, onCall: () => _call(h)),
          ],
          for (final cat in hotlineCategories)
            if (all.any((h) => h.category == cat)) ...[
              SectionTitle(cat),
              for (final h in all.where((h) => h.category == cat))
                _HotlineTile(h, pinned: s.pinnedHotlines.contains(h.number), onCall: () => _call(h)),
            ],
          if (all.isEmpty)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('ไม่พบเบอร์ที่ค้นหา'))),
          const SizedBox(height: 8),
          const Disclaimer(
            'ตรวจสอบเบอร์ล่าสุด $hotlinesVerifiedAt จากข่าวและเว็บไซต์หน่วยงาน — เบอร์อาจเปลี่ยนได้ '
            '191 / 1669 / 199 โทรฟรี เบอร์ 4 หลักอื่นอาจมีค่าโทรตามผู้ให้บริการ',
          ),
        ],
      ),
    );
  }
}

class _HotlineTile extends StatelessWidget {
  const _HotlineTile(this.h, {required this.pinned, required this.onCall});
  final Hotline h;
  final bool pinned;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.read(context);
    return Panel(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      margin: const EdgeInsets.only(bottom: 8),
      onTap: onCall,
      child: Row(children: [
        Container(
          width: 64,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: h.color.withValues(alpha: .15), borderRadius: BorderRadius.circular(12)),
          child: Text(h.number, style: TextStyle(color: h.color, fontWeight: FontWeight.w900, fontSize: 17)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(h.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(h.desc, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ]),
        ),
        IconButton(
          tooltip: pinned ? 'เลิกปักหมุด' : 'ปักหมุด',
          onPressed: () => s.togglePinnedHotline(h.number),
          icon: Icon(pinned ? Icons.star : Icons.star_border, color: pinned ? amber : Colors.white38),
        ),
        IconButton(
          tooltip: 'คัดลอกเบอร์',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: h.number));
            toast(context, 'คัดลอก ${h.number} แล้ว');
          },
          icon: const Icon(Icons.copy, size: 20, color: Colors.white54),
        ),
        IconButton(tooltip: 'โทร', onPressed: onCall, icon: const Icon(Icons.call, color: green)),
      ]),
    );
  }
}
