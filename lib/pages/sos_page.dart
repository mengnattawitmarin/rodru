import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../data/content.dart';
import '../models/models.dart';
import '../services/location_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

class SosPage extends StatefulWidget {
  const SosPage({super.key});
  @override
  State<SosPage> createState() => _SosPageState();
}

class _SosPageState extends State<SosPage> {
  bool _locating = false;

  /// Builds the help message with fresh GPS if possible, falling back to the
  /// selected area.
  Future<String> _buildMessage({required bool safe}) async {
    final s = AppScope.read(context);
    setState(() => _locating = true);
    final r = await LocationService.current();
    if (mounted) setState(() => _locating = false);
    final lat = r.position?.latitude ?? s.location.lat;
    final lon = r.position?.longitude ?? s.location.lon;
    final acc = r.position != null ? ' (±${r.position!.accuracy.round()} ม.)' : ' (ตำแหน่งโดยประมาณจากพื้นที่ที่เลือก)';
    final now = DateTime.now();
    final buf = StringBuffer()
      ..writeln(safe ? '✅ ฉันปลอดภัย' : '🆘 ขอความช่วยเหลือด่วน')
      ..writeln('ตำแหน่ง: https://maps.google.com/?q=${lat.toStringAsFixed(6)},${lon.toStringAsFixed(6)}$acc')
      ..writeln('เวลา: ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} น. ${now.day}/${now.month}/${now.year + 543}');
    if (!safe && !s.medical.isEmpty) {
      buf
        ..writeln()
        ..writeln('ข้อมูลทางการแพทย์:')
        ..writeln(s.medical.toShareText());
    }
    buf.write('— ส่งจากแอปรอดรู้');
    return buf.toString();
  }

  Future<void> _share({required bool safe}) async {
    final msg = await _buildMessage(safe: safe);
    if (!mounted) return;
    await Share.share(msg, subject: safe ? 'ฉันปลอดภัย' : 'SOS ขอความช่วยเหลือ');
  }

  Future<void> _sms(EmergencyContact c) async {
    final msg = await _buildMessage(safe: false);
    // Build manually: Uri(queryParameters:) encodes spaces as '+', which SMS apps show literally.
    final phone = c.phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final ok = await launchUrl(Uri.parse('sms:$phone?body=${Uri.encodeComponent(msg)}'));
    if (!ok && mounted) toast(context, 'เปิดแอปข้อความไม่ได้');
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF1A0E14),
      appBar: AppBar(backgroundColor: const Color(0xFF1A0E14), title: const Text('SOS ขอความช่วยเหลือ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Big primary call buttons
          Row(children: [
            Expanded(child: _BigCall(hotlines[0])),
            const SizedBox(width: 10),
            Expanded(child: _BigCall(hotlines[1])),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _BigCall(hotlines[2])),
            const SizedBox(width: 10),
            Expanded(child: _BigCall(hotlines[3])),
          ]),
          const SizedBox(height: 16),

          // Share location
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: red, minimumSize: const Size.fromHeight(54)),
                onPressed: _locating ? null : () => _share(safe: false),
                icon: _locating
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.share_location),
                label: const Text('ส่งตำแหน่งขอช่วย'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: green, foregroundColor: navy, minimumSize: const Size.fromHeight(54)),
                onPressed: _locating ? null : () => _share(safe: true),
                icon: const Icon(Icons.verified_user),
                label: const Text('แจ้งว่าปลอดภัย'),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignalLightPage())),
            icon: const Icon(Icons.flashlight_on),
            label: const Text('ไฟสัญญาณ SOS (กะพริบหน้าจอ)'),
          ),
          const SizedBox(height: 16),

          // Personal contacts
          const SectionTitle('ผู้ติดต่อฉุกเฉินของฉัน'),
          if (s.contacts.isEmpty)
            const InfoCard(
              icon: Icons.person_add_alt,
              title: 'ยังไม่มีผู้ติดต่อ',
              subtitle: 'เพิ่มได้ที่แท็บ "ฉัน" เพื่อโทร/ส่งตำแหน่งได้ในแตะเดียว',
              color: amber,
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
                IconButton(tooltip: 'ส่ง SMS พร้อมตำแหน่ง', onPressed: () => _sms(c), icon: const Icon(Icons.sms, color: amber)),
                IconButton(tooltip: 'โทร', onPressed: () => callNumber(context, c.phone), icon: const Icon(Icons.call, color: green)),
              ]),
            ),

          if (!s.medical.isEmpty) ...[
            const SectionTitle('ข้อมูลทางการแพทย์ (แสดงให้เจ้าหน้าที่)'),
            Panel(child: Text(s.medical.toShareText(), style: const TextStyle(height: 1.5))),
          ],

          const SectionTitle('สายด่วนอื่น ๆ'),
          for (final h in hotlines.skip(4))
            InfoCard(
              icon: h.icon,
              color: h.color,
              title: '${h.number}  ${h.name}',
              subtitle: h.desc,
              onTap: () async {
                if (await confirmCall(context, h.number, h.name) && context.mounted) callNumber(context, h.number);
              },
            ),
          const Disclaimer('ในไทย 191 / 1669 / 199 โทรได้ฟรีแม้ไม่มีเงินในระบบ — พูดช้า ๆ บอกสถานที่ จำนวนผู้บาดเจ็บ และอันตรายที่เห็น'),
        ],
      ),
    );
  }
}

class _BigCall extends StatelessWidget {
  const _BigCall(this.h);
  final Hotline h;
  @override
  Widget build(BuildContext context) => Material(
        color: h.color.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            if (await confirmCall(context, h.number, h.name) && context.mounted) callNumber(context, h.number);
          },
          child: Container(
            height: 112,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: h.color.withValues(alpha: .6))),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(h.icon, color: h.color, size: 30),
              const SizedBox(height: 4),
              Text(h.number, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: h.color)),
              Text(h.name, style: const TextStyle(fontSize: 12)),
            ]),
          ),
        ),
      );
}

/// Full-screen flashing light that blinks SOS in Morse (··· ––– ···).
class SignalLightPage extends StatefulWidget {
  const SignalLightPage({super.key});
  @override
  State<SignalLightPage> createState() => _SignalLightPageState();
}

class _SignalLightPageState extends State<SignalLightPage> {
  // on/off durations in units (1 unit = 200 ms)
  static const _pattern = [1, 1, 1, 1, 1, 3, 3, 1, 3, 1, 3, 3, 1, 1, 1, 1, 1, 7];
  int _step = 0;
  bool _on = true;
  bool _morse = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _tick();
  }

  void _tick() {
    final units = _morse ? _pattern[_step % _pattern.length] : 2;
    _timer = Timer(Duration(milliseconds: units * 200), () {
      if (!mounted) return;
      setState(() {
        _step++;
        _on = !_on;
        if (_morse && _step % _pattern.length == 0) _on = true;
      });
      _tick();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _on ? Colors.white : Colors.black,
        body: SafeArea(
          child: Stack(children: [
            Center(
              child: Text('SOS', style: TextStyle(fontSize: 96, fontWeight: FontWeight.w900, color: _on ? red : Colors.white24)),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Row(children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.black54),
                    onPressed: () => setState(() {
                      _morse = !_morse;
                      _step = 0;
                    }),
                    child: Text(_morse ? 'โหมด: มอร์ส SOS' : 'โหมด: กะพริบเร็ว'),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: red),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ปิด'),
                ),
              ]),
            ),
          ]),
        ),
      );
}
