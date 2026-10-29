import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app_state.dart';
import '../logic/format.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'route_page.dart';

const osmUserAgent = 'com.rodru.app';

class MapPage extends StatefulWidget {
  const MapPage({super.key});
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final _map = MapController();
  bool _radar = true, _quakes = true, _places = true;
  String? _radarTemplate;
  DateTime? _radarTime;
  List<SafePlace> _safePlaces = [];
  bool _loadingPlaces = false;
  String? _placesError;
  AppLocation? _loadedFor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRadar());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final loc = AppScope.of(context).location;
    if (_loadedFor == null || _loadedFor!.lat != loc.lat || _loadedFor!.lon != loc.lon) {
      final first = _loadedFor == null;
      _loadedFor = loc;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadPlaces(loc);
        if (!first) {
          try {
            _map.move(loc.latLng, 11);
          } catch (_) {}
        }
      });
    }
  }

  Future<void> _loadRadar() async {
    try {
      final r = await AppScope.read(context).api.fetchRadarTemplate();
      if (!mounted || r == null) return;
      setState(() {
        _radarTemplate = r.$1;
        _radarTime = r.$2;
      });
    } catch (_) {}
  }

  Future<void> _loadPlaces(AppLocation loc) async {
    setState(() {
      _loadingPlaces = true;
      _placesError = null;
    });
    try {
      final p = await AppScope.read(context).api.fetchSafePlaces(loc.lat, loc.lon);
      p.sort((a, b) => haversine(loc.lat, loc.lon, a.lat, a.lon).compareTo(haversine(loc.lat, loc.lon, b.lat, b.lon)));
      if (mounted) setState(() => _safePlaces = p);
    } catch (e) {
      if (mounted) setState(() => _placesError = 'โหลดจุดปลอดภัยไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _loadingPlaces = false);
    }
  }

  void _showPlace(SafePlace p, AppLocation from) {
    final d = haversine(from.lat, from.lon, p.lat, p.lon);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(p.icon, color: green, size: 30),
              const SizedBox(width: 10),
              Expanded(child: Text(p.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold))),
            ]),
            const SizedBox(height: 6),
            Text('${p.kindLabel} • ห่าง ${distanceText(d)} (เส้นตรง)', style: const TextStyle(color: Colors.white70)),
            if (p.phone != null) Text('โทร ${p.phone}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => RoutePage(from: from.latLng, place: p)));
                  },
                  icon: const Icon(Icons.alt_route),
                  label: const Text('ดูเส้นทาง'),
                ),
              ),
              if (p.phone != null) ...[
                const SizedBox(width: 10),
                OutlinedButton.icon(onPressed: () => callNumber(context, p.phone!), icon: const Icon(Icons.call), label: const Text('โทร')),
              ],
            ]),
            const Disclaimer('ข้อมูลจาก OpenStreetMap ยังไม่ได้ยืนยันโดยหน่วยงาน — โทรตรวจสอบก่อนเดินทาง'),
          ]),
        ),
      ),
    );
  }

  void _showQuake(Quake q, AppLocation from) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('แผ่นดินไหวขนาด ${q.mag.toStringAsFixed(1)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(q.place),
            Text('${thaiDate(q.time)} ${hhmm(q.time)} น. (${timeAgo(q.time)})', style: const TextStyle(color: Colors.white70)),
            Text('ความลึก ${q.depthKm.round()} กม. • ห่างจากพื้นที่ของคุณ ${distanceText(haversine(from.lat, from.lon, q.lat, q.lon))}',
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: () => openWeb(context, q.url), icon: const Icon(Icons.open_in_new), label: const Text('รายละเอียดจาก USGS')),
          ]),
        ),
      ),
    );
  }

  void _showPlacesList(AppLocation from) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .6,
        maxChildSize: .92,
        builder: (_, sc) => ListView(
          controller: sc,
          padding: const EdgeInsets.all(16),
          children: [
            const Text('จุดปลอดภัยใกล้คุณ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Disclaimer('โรงพยาบาล ตำรวจ ดับเพลิง จุดรวมพล จาก OpenStreetMap — ศูนย์พักพิงชั่วคราวให้ตรวจสอบกับ ปภ. 1784 / อบต. / เทศบาล'),
            for (final p in _safePlaces.take(40))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(backgroundColor: green.withValues(alpha: .15), child: Icon(p.icon, color: green)),
                title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${p.kindLabel} • ${distanceText(haversine(from.lat, from.lon, p.lat, p.lon))}'),
                trailing: const Icon(Icons.alt_route, color: blue),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => RoutePage(from: from.latLng, place: p)));
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final loc = s.location;
    final quakes = _quakes ? s.quakes : const <Quake>[];

    return Stack(children: [
      FlutterMap(
        mapController: _map,
        options: MapOptions(
          initialCenter: loc.latLng,
          initialZoom: 10,
          minZoom: 4,
          maxZoom: 18,
          interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: osmUserAgent,
            maxNativeZoom: 19,
          ),
          if (_radar && _radarTemplate != null)
            TileLayer(
              key: ValueKey(_radarTemplate),
              urlTemplate: _radarTemplate!,
              userAgentPackageName: osmUserAgent,
              maxNativeZoom: 7,
              tileDisplay: const TileDisplay.instantaneous(opacity: .7),
            ),
          MarkerLayer(markers: [
            for (final q in quakes)
              Marker(
                point: q.latLng,
                width: 14 + q.mag * 6,
                height: 14 + q.mag * 6,
                child: GestureDetector(
                  onTap: () => _showQuake(q, loc),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (q.mag >= 5 ? red : amber).withValues(alpha: .35),
                      border: Border.all(color: q.mag >= 5 ? red : amber, width: 2),
                    ),
                    child: Text(q.mag.toStringAsFixed(1), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ),
            if (_places)
              for (final p in _safePlaces.take(120))
                Marker(
                  point: p.latLng,
                  width: 36,
                  height: 36,
                  child: GestureDetector(onTap: () => _showPlace(p, loc), child: _MapPin(icon: p.icon, color: green)),
                ),
            Marker(point: loc.latLng, width: 48, height: 48, child: const _MapPin(icon: Icons.person_pin_circle, color: blue, big: true)),
          ]),
          const RichAttributionWidget(attributions: [
            TextSourceAttribution('© OpenStreetMap contributors'),
            TextSourceAttribution('Radar: RainViewer'),
            TextSourceAttribution('Earthquakes: USGS'),
          ]),
        ],
      ),

      // ---- header ----
      Positioned(
        left: 12,
        right: 76,
        top: 10,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: navy.withValues(alpha: .88), borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            const Row(children: [
              Text('แผนที่สถานการณ์', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              SizedBox(width: 8),
              Pill('LIVE', color: green),
            ]),
            Text(
              _radarTime != null ? 'เรดาร์ฝน ${hhmm(_radarTime)} น. • ${loc.name}' : loc.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ]),
        ),
      ),

      // ---- layer toggles ----
      Positioned(
        right: 10,
        top: 10,
        child: Column(children: [
          _LayerButton(icon: Icons.water_drop, label: 'เรดาร์', on: _radar, onTap: () => setState(() => _radar = !_radar)),
          _LayerButton(icon: Icons.vibration, label: 'แผ่นดินไหว', on: _quakes, onTap: () => setState(() => _quakes = !_quakes)),
          _LayerButton(icon: Icons.health_and_safety, label: 'จุดปลอดภัย', on: _places, onTap: () => setState(() => _places = !_places)),
          _LayerButton(
            icon: Icons.my_location,
            label: 'ตำแหน่ง',
            on: false,
            onTap: () => _map.move(loc.latLng, 12),
          ),
          _LayerButton(
            icon: Icons.refresh,
            label: 'รีเฟรช',
            on: false,
            onTap: () {
              _loadRadar();
              _loadPlaces(loc);
              s.refresh();
            },
          ),
        ]),
      ),

      // ---- bottom panel ----
      Positioned(
        left: 12,
        right: 12,
        bottom: 12,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_radar)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: navy.withValues(alpha: .88), borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                const Text('ฝนเรดาร์', style: TextStyle(fontSize: 11)),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: const LinearGradient(colors: [Color(0xFF88DDEE), Color(0xFF0099CC), Color(0xFF005588), Color(0xFFFFEE00), Color(0xFFFF4400), Color(0xFFC10000)]),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('เบา → หนัก', style: TextStyle(fontSize: 10, color: Colors.white60)),
              ]),
            ),
          Material(
            color: panel,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _safePlaces.isEmpty ? null : () => _showPlacesList(loc),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  _loadingPlaces
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.health_and_safety, color: green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _loadingPlaces
                          ? 'กำลังค้นหาจุดปลอดภัย...'
                          : _placesError ?? (_safePlaces.isEmpty
                              ? 'ไม่พบจุดปลอดภัยในรัศมี 15 กม.'
                              : 'จุดปลอดภัยใกล้คุณ ${_safePlaces.length} แห่ง • ใกล้สุด ${distanceText(haversine(loc.lat, loc.lon, _safePlaces.first.lat, _safePlaces.first.lon))}'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (_safePlaces.isNotEmpty) const Text('ดูทั้งหมด', style: TextStyle(color: blue, fontSize: 12)),
                  if (_placesError != null) TextButton(onPressed: () => _loadPlaces(loc), child: const Text('ลองใหม่')),
                ]),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }
}

class _LayerButton extends StatelessWidget {
  const _LayerButton({required this.icon, required this.label, required this.on, required this.onTap});
  final IconData icon;
  final String label;
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Material(
          color: on ? panel2 : navy.withValues(alpha: .88),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Container(
              width: 58,
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: on ? blue : Colors.white12)),
              child: Column(children: [
                Icon(icon, size: 22, color: on ? blue : Colors.white70),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(fontSize: 9), textAlign: TextAlign.center),
              ]),
            ),
          ),
        ),
      );
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.icon, required this.color, this.big = false});
  final IconData icon;
  final Color color;
  final bool big;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: navy,
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6)],
        ),
        child: Icon(icon, color: color, size: big ? 28 : 19),
      );
}

/// Exposed for route_page: same pin style.
Widget mapPin(IconData icon, Color color, {bool big = false}) => _MapPin(icon: icon, color: color, big: big);

LatLng centerOf(LatLng a, LatLng b) => LatLng((a.latitude + b.latitude) / 2, (a.longitude + b.longitude) / 2);
