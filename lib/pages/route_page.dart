import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app_state.dart';
import '../logic/format.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'map_page.dart';

class RoutePage extends StatefulWidget {
  const RoutePage({super.key, required this.from, required this.place});
  final LatLng from;
  final SafePlace place;
  @override
  State<RoutePage> createState() => _RoutePageState();
}

class _RoutePageState extends State<RoutePage> {
  List<RouteOption> _routes = [];
  int _selected = 0;
  bool _loading = true;
  String? _error;
  DateTime? _checkedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await AppScope.read(context).api.fetchRoutes(widget.from, widget.place.latLng);
      if (!mounted) return;
      setState(() {
        _routes = r;
        _selected = 0;
        _checkedAt = DateTime.now();
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'คำนวณเส้นทางไม่ได้ (ต้องใช้อินเทอร์เน็ต) — กดนำทางเพื่อเปิดแอปแผนที่แทน');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.place;
    final colors = [blue, green, purple];
    final bounds = LatLngBounds.fromPoints([widget.from, p.latLng, for (final r in _routes) ...r.points]);

    return Scaffold(
      appBar: AppBar(title: const Text('เส้นทางไปจุดปลอดภัย')),
      body: Column(children: [
        Container(
          color: panel,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            const Icon(Icons.verified_user, color: green, size: 18),
            const SizedBox(width: 8),
            const Expanded(child: Text('ตรวจสอบข้อมูลล่าสุดก่อนเดินทาง', style: TextStyle(fontSize: 12))),
            if (_checkedAt != null) Text('อัปเดต ${hhmm(_checkedAt)} น.', style: const TextStyle(fontSize: 11, color: Colors.white60)),
          ]),
        ),
        Expanded(
          flex: 5,
          child: FlutterMap(
            key: ValueKey(_routes.length),
            options: MapOptions(
              initialCameraFit: CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(40), maxZoom: 16),
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            ),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: osmUserAgent),
              PolylineLayer(polylines: [
                for (var i = _routes.length - 1; i >= 0; i--)
                  Polyline(
                    points: _routes[i].points,
                    strokeWidth: i == _selected ? 6 : 4,
                    color: (colors[i % colors.length]).withValues(alpha: i == _selected ? 1 : .55),
                    borderColor: Colors.black54,
                    borderStrokeWidth: 1.5,
                  ),
              ]),
              MarkerLayer(markers: [
                Marker(point: widget.from, width: 40, height: 40, child: mapPin(Icons.person_pin_circle, blue, big: true)),
                Marker(point: p.latLng, width: 44, height: 44, child: mapPin(p.icon, green, big: true)),
              ]),
              const RichAttributionWidget(attributions: [
                TextSourceAttribution('© OpenStreetMap contributors'),
                TextSourceAttribution('Routing: OSRM'),
              ]),
            ],
          ),
        ),
        Expanded(
          flex: 6,
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              if (_loading) const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
              if (_error != null) Disclaimer(_error!),
              for (var i = 0; i < _routes.length; i++)
                Panel(
                  borderColor: i == _selected ? colors[i % colors.length] : null,
                  onTap: () => setState(() => _selected = i),
                  child: Row(children: [
                    Icon(Icons.directions_car, color: colors[i % colors.length], size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('เส้นทางที่ ${i + 1}${i == 0 ? ' (เร็วที่สุด)' : ''}', style: TextStyle(color: colors[i % colors.length], fontSize: 12)),
                        Text('${durationText(_routes[i].durationS)} • ${distanceText(_routes[i].distanceM)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      ]),
                    ),
                    if (i == _selected) const Icon(Icons.check_circle, color: green),
                  ]),
                ),
              Panel(
                color: const Color(0xFF12301F),
                borderColor: green.withValues(alpha: .5),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(p.icon, color: green),
                    const SizedBox(width: 8),
                    Expanded(child: Text(p.kindLabel, style: const TextStyle(color: green, fontWeight: FontWeight.bold))),
                    const Pill('ยังไม่ยืนยันสถานะ', color: amber),
                  ]),
                  const SizedBox(height: 6),
                  Text(p.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  Text('ห่าง ${distanceText(haversine(widget.from.latitude, widget.from.longitude, p.lat, p.lon))} (เส้นตรง)',
                      style: const TextStyle(color: Colors.white60, fontSize: 12)),
                ]),
              ),
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    onPressed: () => openDirections(context, p.lat, p.lon),
                    icon: const Icon(Icons.navigation),
                    label: const Text('นำทางด้วย Google Maps'),
                  ),
                ),
                if (p.phone != null) ...[
                  const SizedBox(width: 10),
                  IconButton.filledTonal(onPressed: () => callNumber(context, p.phone!), icon: const Icon(Icons.call)),
                ],
              ]),
              const Disclaimer('เส้นทางคำนวณจากถนนปกติ ยังไม่รวมข้อมูลถนนน้ำท่วม/ปิด — ห้ามขับฝ่าน้ำไหล และทำตามคำแนะนำเจ้าหน้าที่'),
            ],
          ),
        ),
      ]),
    );
  }
}
