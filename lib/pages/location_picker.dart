import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/models.dart';
import '../services/location_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Popular places for one-tap selection (works offline).
const quickPlaces = <AppLocation>[
  AppLocation('กรุงเทพมหานคร', 13.7563, 100.5018),
  AppLocation('เชียงใหม่', 18.7883, 98.9853),
  AppLocation('เชียงราย', 19.9105, 99.8406),
  AppLocation('ขอนแก่น', 16.4419, 102.8360),
  AppLocation('นครราชสีมา', 14.9799, 102.0977),
  AppLocation('อุบลราชธานี', 15.2287, 104.8564),
  AppLocation('ชลบุรี', 13.3611, 100.9847),
  AppLocation('ระยอง', 12.6814, 101.2816),
  AppLocation('ภูเก็ต', 7.8804, 98.3923),
  AppLocation('พังงา (เขาหลัก)', 8.6430, 98.2530),
  AppLocation('สุราษฎร์ธานี', 9.1382, 99.3215),
  AppLocation('นครศรีธรรมราช', 8.4304, 99.9631),
  AppLocation('หาดใหญ่, สงขลา', 7.0086, 100.4747),
  AppLocation('พิษณุโลก', 16.8211, 100.2659),
  AppLocation('อยุธยา', 14.3532, 100.5689),
];

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({super.key});
  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<AppLocation> _results = [];
  bool _searching = false, _locating = false;
  String? _msg;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(q));
  }

  Future<void> _search(String q) async {
    if (q.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() {
      _searching = true;
      _msg = null;
    });
    try {
      final r = await AppScope.read(context).api.searchPlaces(q.trim());
      if (!mounted) return;
      setState(() {
        _results = r;
        _msg = r.isEmpty ? 'ไม่พบสถานที่ ลองพิมพ์ชื่ออำเภอหรือจังหวัด' : null;
      });
    } catch (_) {
      if (mounted) setState(() => _msg = 'ค้นหาไม่ได้ ตรวจสอบอินเทอร์เน็ต');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _pick(AppLocation l) async {
    final s = AppScope.read(context);
    Navigator.pop(context);
    await s.setLocation(l);
  }

  Future<void> _gps() async {
    setState(() => _locating = true);
    final s = AppScope.read(context);
    final err = await s.useGps();
    if (!mounted) return;
    setState(() => _locating = false);
    if (err == null) {
      Navigator.pop(context);
    } else {
      setState(() => _msg = err);
      if (err.contains('ถาวร')) {
        toast(context, err);
        await LocationService.openSettings();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = AppScope.of(context).location;
    return Scaffold(
      appBar: AppBar(title: const Text('เลือกพื้นที่')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Panel(
            color: panel2,
            onTap: _locating ? null : _gps,
            child: Row(children: [
              _locating
                  ? const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Icon(Icons.my_location, color: blue, size: 26),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('ใช้ตำแหน่งปัจจุบัน (GPS)', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('ตำแหน่งใช้ในเครื่องเท่านั้น ไม่ถูกเก็บบนเซิร์ฟเวอร์', style: TextStyle(color: Colors.white60, fontSize: 12)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _ctrl,
            onChanged: _onChanged,
            onSubmitted: _search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'ค้นหาอำเภอ / จังหวัด',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searching ? const Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 2)) : null,
              filled: true,
              fillColor: panel,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          if (_msg != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_msg!, style: const TextStyle(color: amber))),
          const SizedBox(height: 10),
          for (final r in _results)
            ListTile(
              leading: const Icon(Icons.place_outlined),
              title: Text(r.name),
              subtitle: Text('${r.lat.toStringAsFixed(3)}, ${r.lon.toStringAsFixed(3)}', style: const TextStyle(fontSize: 11)),
              onTap: () => _pick(r),
            ),
          if (_results.isEmpty) ...[
            const SectionTitle('พื้นที่ยอดนิยม'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final p in quickPlaces)
                ChoiceChip(
                  label: Text(p.name),
                  selected: p.name == current.name,
                  onSelected: (_) => _pick(p),
                ),
            ]),
          ],
        ],
      ),
    );
  }
}
