import 'package:flutter/material.dart';

import '../data/content.dart';
import '../theme.dart';
import '../widgets/common.dart';

void openGuide(BuildContext context, Hazard h) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => GuidePage(hazard: h)));

class GuidePage extends StatelessWidget {
  const GuidePage({super.key, required this.hazard});
  final Hazard hazard;

  @override
  Widget build(BuildContext context) {
    final h = hazard;
    return DefaultTabController(
      length: 3,
      initialIndex: 1,
      child: Scaffold(
        appBar: AppBar(
          title: Row(children: [Icon(h.icon, color: h.color), const SizedBox(width: 8), Text(h.title)]),
          bottom: const TabBar(tabs: [Tab(text: 'ก่อนเกิดเหตุ'), Tab(text: 'ขณะเกิดเหตุ'), Tab(text: 'หลังเกิดเหตุ')]),
        ),
        body: TabBarView(children: [
          _StepList(steps: h.before, color: h.color),
          _StepList(steps: h.during, color: h.color),
          _StepList(steps: h.after, color: h.color),
        ]),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    if (await confirmCall(context, '1784', 'สายด่วน ปภ.') && context.mounted) callNumber(context, '1784');
                  },
                  icon: const Icon(Icons.shield),
                  label: const Text('ปภ. 1784'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: red),
                  onPressed: () async {
                    if (await confirmCall(context, '1669', 'เจ็บป่วยฉุกเฉิน') && context.mounted) callNumber(context, '1669');
                  },
                  icon: const Icon(Icons.medical_services),
                  label: const Text('1669'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _StepList extends StatelessWidget {
  const _StepList({required this.steps, required this.color});
  final List<String> steps;
  final Color color;
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (var i = 0; i < steps.length; i++)
            Panel(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: color.withValues(alpha: .18), shape: BoxShape.circle),
                  child: Text('${i + 1}', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(steps[i], style: const TextStyle(fontSize: 15, height: 1.45))),
              ]),
            ),
          const Disclaimer('คำแนะนำทั่วไป อ่านได้แม้ไม่มีอินเทอร์เน็ต — เมื่อเกิดเหตุจริงให้ทำตามคำสั่งเจ้าหน้าที่ในพื้นที่เป็นหลัก'),
        ],
      );
}
