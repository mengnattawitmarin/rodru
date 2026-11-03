import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app_state.dart';
import '../logic/format.dart';
import '../logic/quake_intensity.dart';
import '../models/models.dart';
import '../services/storage.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'route_page.dart';
import 'sos_page.dart';

const osmUserAgent = 'com.rodru.app';

enum QuakePeriod { day, week, month, history }

class MapPage extends StatefulWidget {
  const MapPage({super.key});
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final _map = MapController();

  // layers
  bool _radar = true, _wind = false, _quakes = true, _water = false, _places = true;

  // radar animation
  List<RadarFrame> _frames = [];
  int _frame = 0;
  bool _playing = false;
  Timer? _playTimer;

  // wind grid
  List<WindSample> _windSamples = [];
  bool _loadingWind = false;
  Timer? _windDebounce;

  // quakes
  QuakePeriod _period = QuakePeriod.week;
  List<Quake>? _monthQuakes, _history;
  bool _loadingQuakes = false;
  Quake? _selected;
  List<MmiContour> _shake = const [];
  bool _loadingShake = false;

  // safe places
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
  void dispose() {
    _playTimer?.cancel();
    _windDebounce?.cancel();
    super.dispose();
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

  // ---------------- radar ----------------
  Future<void> _loadRadar() async {
    try {
      final f = await AppScope.read(context).api.fetchRadarFrames();
      if (!mounted || f.isEmpty) return;
      final lastPast = f.lastIndexWhere((e) => !e.nowcast);
      setState(() {
        _frames = f;
        _frame = lastPast < 0 ? f.length - 1 : lastPast;
      });
    } catch (_) {}
  }

  void _togglePlay() {
    if (_frames.length < 2) return;
    setState(() => _playing = !_playing);
    _playTimer?.cancel();
    if (_playing) {
      _playTimer = Timer.periodic(const Duration(milliseconds: 650), (_) {
        if (!mounted) return;
        setState(() => _frame = (_frame + 1) % _frames.length);
      });
    }
  }

  void _stopPlay() {
    _playTimer?.cancel();
    _playing = false;
  }

  // ---------------- wind ----------------
  void _scheduleWind() {
    if (!_wind) return;
    _windDebounce?.cancel();
    _windDebounce = Timer(const Duration(milliseconds: 900), _loadWind);
  }

  Future<void> _loadWind() async {
    if (!_wind || !mounted) return;
    LatLngBounds b;
    try {
      b = _map.camera.visibleBounds;
    } catch (_) {
      return;
    }
    const n = 5;
    final pts = <LatLng>[];
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < n; j++) {
        final lat = b.south + (b.north - b.south) * (i + .5) / n;
        final lon = b.west + (b.east - b.west) * (j + .5) / n;
        pts.add(LatLng(lat.clamp(-85.0, 85.0).toDouble(), lon));
      }
    }
    setState(() => _loadingWind = true);
    try {
      final w = await AppScope.read(context).api.fetchWindGrid(pts);
      if (mounted) setState(() => _windSamples = w);
    } catch (_) {
      if (mounted) toast(context, 'โหลดข้อมูลลมไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _loadingWind = false);
    }
  }

  // ---------------- quakes ----------------
  List<Quake> _visibleQuakes(AppState s) {
    final now = DateTime.now();
    return switch (_period) {
      QuakePeriod.day => s.quakes.where((q) => now.difference(q.time) <= const Duration(hours: 24)).toList(),
      QuakePeriod.week => s.quakes,
      QuakePeriod.month => _monthQuakes ?? s.quakes,
      QuakePeriod.history => _history ?? const <Quake>[],
    };
  }

  Future<void> _setPeriod(QuakePeriod p) async {
    setState(() {
      _period = p;
      _selected = null;
      _shake = const [];
    });
    final api = AppScope.read(context).api;
    if (p == QuakePeriod.month && _monthQuakes == null) {
      setState(() => _loadingQuakes = true);
      try {
        _monthQuakes = await api.fetchQuakes(days: 30, minMag: 3.5);
      } catch (_) {
        if (mounted) toast(context, 'โหลดแผ่นดินไหว 30 วันไม่สำเร็จ');
      }
    } else if (p == QuakePeriod.history && _history == null) {
      setState(() => _loadingQuakes = true);
      try {
        _history = await api.fetchHistoricQuakes();
      } catch (_) {
        if (mounted) toast(context, 'โหลดประวัติแผ่นดินไหวไม่สำเร็จ');
      }
    }
    if (mounted) setState(() => _loadingQuakes = false);
  }

  Future<void> _selectQuake(Quake q, AppLocation from) async {
    setState(() {
      _selected = q;
      _shake = const [];
      _loadingShake = q.mag >= 4.5;
    });
    _showQuake(q, from);
    if (q.mag < 4.5) return;
    try {
      final c = await AppScope.read(context).api.fetchShakeMap(q.id);
      if (mounted && _selected?.id == q.id) setState(() => _shake = c);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingShake = false);
    }
  }

  // ---------------- safe places ----------------
  Future<void> _loadPlaces(AppLocation loc) async {
    setState(() {
      _loadingPlaces = true;
      _placesError = null;
    });
    final s = AppScope.read(context);
    final cacheKey = '${loc.lat.toStringAsFixed(2)},${loc.lon.toStringAsFixed(2)}';
    void sortAndSet(List<SafePlace> p) {
      p.sort((a, b) => haversine(loc.lat, loc.lon, a.lat, a.lon).compareTo(haversine(loc.lat, loc.lon, b.lat, b.lon)));
      if (mounted) setState(() => _safePlaces = p);
    }

    // Show cached places for this area immediately (works offline).
    final cache = s.storage.getJson(Keys.safePlacesCache);
    if (cache != null && cache['key'] == cacheKey) {
      final list = (cache['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SafePlace.fromJson)
          .whereType<SafePlace>()
          .toList();
      if (list.isNotEmpty) sortAndSet(list);
    }
    try {
      var p = await s.api.fetchSafePlaces(loc.lat, loc.lon, radiusM: 8000);
      if (p.length < 5) p = await s.api.fetchSafePlaces(loc.lat, loc.lon, radiusM: 20000);
      sortAndSet(p);
      await s.storage.setJson(Keys.safePlacesCache, {'key': cacheKey, 'items': p.take(150).map((e) => e.toJson()).toList()});
    } catch (_) {
      if (mounted) {
        setState(() => _placesError = _safePlaces.isEmpty ? 'เซิร์ฟเวอร์แผนที่ไม่ว่าง ลองใหม่ภายหลัง' : null);
      }
    } finally {
      if (mounted) setState(() => _loadingPlaces = false);
    }
  }

  // ---------------- sheets ----------------
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

  void _showWater(WaterStation w, AppLocation from) {
    final d = haversine(from.lat, from.lon, w.lat, w.lon);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.water, color: w.color, size: 30),
              const SizedBox(width: 10),
              Expanded(child: Text(w.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold))),
              Pill(w.situationLabel, color: w.color),
            ]),
            const SizedBox(height: 6),
            Text(
              [if (w.river.isNotEmpty) w.river, if (w.district.isNotEmpty) 'อ.${w.district}', if (w.province.isNotEmpty) w.province].join(' • '),
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Row(children: [
              _Stat('ระดับน้ำ', w.levelMsl == null ? '-' : '${w.levelMsl!.toStringAsFixed(2)} ม.', sub: 'ม.รทก.'),
              _Stat('ตลิ่งต่ำสุด', w.minBank == null ? '-' : '${w.minBank!.toStringAsFixed(2)} ม.', sub: 'ม.รทก.'),
              _Stat(
                'แนวโน้ม',
                w.trend > 0 ? '↑ ขึ้น' : w.trend < 0 ? '↓ ลง' : '→ ทรงตัว',
                sub: w.previousMsl == null || w.levelMsl == null
                    ? ''
                    : '${(w.levelMsl! - w.previousMsl!) >= 0 ? '+' : ''}${((w.levelMsl! - w.previousMsl!) * 100).round()} ซม.',
                color: w.trend > 0 ? red : w.trend < 0 ? green : null,
              ),
            ]),
            if (w.bankText != null) ...[
              const SizedBox(height: 10),
              Text(w.bankText!, style: TextStyle(color: w.color, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
            const SizedBox(height: 6),
            Text('วัดเมื่อ ${hhmm(w.time)} น. (${timeAgo(w.time)}) • ห่างคุณ ${distanceText(d)}${w.agency.isNotEmpty ? ' • ${w.agency}' : ''}',
                style: const TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => openWeb(context, 'https://www.thaiwater.net'),
              icon: const Icon(Icons.open_in_new),
              label: const Text('ดูกราฟ/รายละเอียดที่ ThaiWater'),
            ),
            const Disclaimer('ข้อมูลสถานีโทรมาตร คลังข้อมูลน้ำแห่งชาติ (สสน.) — ระดับน้ำที่สถานีไม่เท่ากับน้ำท่วมทุกจุด'),
          ]),
        ),
      ),
    );
  }

  void _showQuake(Quake q, AppLocation from) {
    final dist = haversine(from.lat, from.lon, q.lat, q.lon) / 1000;
    final mmi = QuakeIntensity.estimate(q.mag, dist, q.depthKm);
    final tsunami = QuakeIntensity.tsunamiPotential(q);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('แผ่นดินไหวขนาด ${q.mag.toStringAsFixed(1)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(q.place),
            Text('${thaiDate(q.time)} ${hhmm(q.time)} น. (${timeAgo(q.time)}) • ลึก ${q.depthKm.round()} กม.',
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            Panel(
              color: QuakeIntensity.color(mmi).withValues(alpha: .12),
              borderColor: QuakeIntensity.color(mmi).withValues(alpha: .6),
              child: Row(children: [
                Text(QuakeIntensity.roman(mmi),
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: QuakeIntensity.color(mmi))),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'ที่ ${from.name} (ห่าง ${dist.round()} กม.) น่าจะรู้สึกระดับ ${QuakeIntensity.roman(mmi)}: ${QuakeIntensity.describe(mmi)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ]),
            ),
            const Text('วงสีบนแผนที่ = ระดับความรุนแรงโดยประมาณจากจุดกำเนิด', style: TextStyle(fontSize: 12, color: Colors.white60)),
            if (q.mag >= 4.5)
              const Text('กำลังตรวจหา ShakeMap (แผนที่แรงสั่นจริงจาก USGS) — ถ้ามีจะแสดงเป็นเส้นบนแผนที่',
                  style: TextStyle(fontSize: 12, color: Colors.white60)),
            if (tsunami) ...[
              const SizedBox(height: 10),
              Panel(
                color: const Color(0xFF12304A),
                borderColor: blue.withValues(alpha: .6),
                child: Text(
                  q.tsunamiFlag
                      ? '🌊 USGS ระบุว่าเหตุการณ์นี้อยู่ในพื้นที่ที่อาจเกิดสึนามิ — ติดตามประกาศศูนย์เตือนภัยพิบัติแห่งชาติ (192) ทันที '
                          'วงฟ้าบนแผนที่ = เวลาที่คลื่นอาจเดินทางถึงโดยประมาณ (30/60/120 นาที)'
                      : '🌊 ขนาด ≥ 6.5 และตื้น — ถ้าเกิดกลางทะเลอาจก่อสึนามิได้ วงฟ้า = เวลาคลื่นเดินทางโดยประมาณ (30/60/120 นาที) '
                          'ถ้าอยู่ชายฝั่งและรู้สึกสั่นแรง ให้ขึ้นที่สูงทันทีไม่ต้องรอประกาศ',
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(onPressed: () => openWeb(context, q.url), icon: const Icon(Icons.open_in_new), label: const Text('USGS')),
              OutlinedButton.icon(
                onPressed: () => openWeb(context, '${q.url}/tellus'),
                icon: const Icon(Icons.record_voice_over),
                label: const Text('คุณรู้สึกไหม?'),
              ),
              OutlinedButton.icon(
                onPressed: () => openWeb(context, 'https://earthquake.tmd.go.th'),
                icon: const Icon(Icons.verified),
                label: const Text('กรมอุตุฯ'),
              ),
            ]),
            const Disclaimer('ความรุนแรงเป็นการประมาณจากขนาดและระยะทาง ไม่รวมสภาพดิน — แผ่นดินไหวทำนายล่วงหน้าไม่ได้'),
          ]),
        ),
      ),
    );
  }

  void _showRiskInfo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('พื้นที่เสี่ยงแผ่นดินไหว & สึนามิ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text(
              '• จุดสีเทาบนแผนที่ (โหมด "ประวัติ") คือแผ่นดินไหวขนาด 5 ขึ้นไปตั้งแต่ปี 2519 — บริเวณที่จุดหนาแน่นคือที่ที่เกิดบ่อย\n'
              '• แนวมุดตัวซุนดา–อันดามัน (ทะเลอันดามันฝั่งตะวันตก) คือต้นเหตุสึนามิปี 2547 — ชายฝั่ง 6 จังหวัดอันดามันเสี่ยงสึนามิ\n'
              '• รอยเลื่อนสะกาย (เมียนมา) ก่อแผ่นดินไหว M7.7 ปี 2568 ที่สั่นถึงกรุงเทพฯ\n'
              '• ในไทยมีกลุ่มรอยเลื่อนมีพลัง 16 กลุ่ม ส่วนใหญ่ภาคเหนือและภาคตะวันตก (กรมทรัพยากรธรณี)\n\n'
              'แผ่นดินไหวทำนายวัน-เวลาไม่ได้ แผนที่นี้บอกเพียงพื้นที่ที่เคยเกิดบ่อย',
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton(onPressed: () => openWeb(context, 'https://www.dmr.go.th'), child: const Text('กรมทรัพยากรธรณี')),
              OutlinedButton(onPressed: () => openWeb(context, 'https://ndwc.disaster.go.th'), child: const Text('ศูนย์เตือนภัยพิบัติฯ')),
            ]),
            const Disclaimer('ยังไม่มีเส้นรอยเลื่อนบนแผนที่ — รอข้อมูล GeoJSON ทางการจากกรมทรัพยากรธรณี'),
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

  // ---------------- build ----------------
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final loc = s.location;
    final quakes = _quakes ? _visibleQuakes(s) : const <Quake>[];
    final steer = s.forecast?.steeringWind;
    final sel = _quakes ? _selected : null;

    return Stack(children: [
      FlutterMap(
        mapController: _map,
        options: MapOptions(
          initialCenter: loc.latLng,
          initialZoom: 9,
          minZoom: 3,
          maxZoom: 18,
          interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
          onPositionChanged: (camera, hasGesture) => _scheduleWind(),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: osmUserAgent,
            maxNativeZoom: 19,
          ),

          // Radar: every frame is built (so its tiles preload) but only the
          // current one is visible.
          if (_radar)
            for (var i = 0; i < _frames.length; i++)
              Opacity(
                key: ValueKey(_frames[i].urlTemplate),
                opacity: i == _frame ? .7 : 0,
                child: TileLayer(
                  urlTemplate: _frames[i].urlTemplate,
                  userAgentPackageName: osmUserAgent,
                  maxNativeZoom: 7,
                ),
              ),

          // Earthquake intensity rings (estimated) + tsunami travel-time rings
          if (sel != null)
            CircleLayer(circles: [
              if (QuakeIntensity.tsunamiPotential(sel))
                for (final minutes in const [120, 60, 30])
                  CircleMarker(
                    point: sel.latLng,
                    radius: QuakeIntensity.tsunamiSpeedKmh * minutes / 60 * 1000,
                    useRadiusInMeter: true,
                    color: Colors.transparent,
                    borderColor: blue.withValues(alpha: .8),
                    borderStrokeWidth: 2,
                  ),
              for (final m in const [3.0, 4.0, 5.0, 6.0, 7.0, 8.0])
                if (QuakeIntensity.radiusKm(sel.mag, sel.depthKm, m) > 0)
                  CircleMarker(
                    point: sel.latLng,
                    radius: QuakeIntensity.radiusKm(sel.mag, sel.depthKm, m) * 1000,
                    useRadiusInMeter: true,
                    color: QuakeIntensity.color(m).withValues(alpha: .13),
                    borderColor: QuakeIntensity.color(m).withValues(alpha: .7),
                    borderStrokeWidth: 1.2,
                  ),
            ]),
          if (sel != null && _shake.isNotEmpty)
            PolylineLayer(polylines: [
              for (final c in _shake)
                for (final line in c.lines)
                  Polyline(points: line, color: QuakeIntensity.color(c.mmi), strokeWidth: 2.5),
            ]),

          MarkerLayer(markers: [
            // historic quakes as small dots
            if (_quakes && _period == QuakePeriod.history)
              for (final q in quakes)
                Marker(
                  point: q.latLng,
                  width: 4 + (q.mag - 5) * 4,
                  height: 4 + (q.mag - 5) * 4,
                  child: GestureDetector(
                    onTap: () => _selectQuake(q, loc),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (q.mag >= 7 ? red : Colors.white).withValues(alpha: q.mag >= 7 ? .8 : .35),
                      ),
                    ),
                  ),
                )
            else
              for (final q in quakes)
                Marker(
                  point: q.latLng,
                  width: 14 + q.mag * 6,
                  height: 14 + q.mag * 6,
                  child: GestureDetector(
                    onTap: () => _selectQuake(q, loc),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (q.mag >= 5 ? red : amber).withValues(alpha: .35),
                        border: Border.all(color: sel?.id == q.id ? Colors.white : (q.mag >= 5 ? red : amber), width: sel?.id == q.id ? 3 : 2),
                      ),
                      child: Text(q.mag.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ),
            if (sel != null)
              Marker(point: sel.latLng, width: 30, height: 30, child: const Icon(Icons.star, color: Colors.white, size: 30)),

            // water stations
            if (_water)
              for (final w in s.waterStations)
                Marker(
                  point: w.latLng,
                  width: w.situation >= 4 ? 22 : 14,
                  height: w.situation >= 4 ? 22 : 14,
                  child: GestureDetector(
                    onTap: () => _showWater(w, loc),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: w.color,
                        border: Border.all(color: navy, width: 2),
                      ),
                    ),
                  ),
                ),

            // wind arrows
            if (_wind)
              for (final w in _windSamples)
                Marker(
                  point: LatLng(w.lat, w.lon),
                  width: 56,
                  height: 56,
                  child: _WindArrow(speed: w.speed, towardDeg: (w.fromDir + 180) % 360),
                ),

            if (_places)
              for (final p in _safePlaces.take(120))
                Marker(
                  point: p.latLng,
                  width: 36,
                  height: 36,
                  child: GestureDetector(onTap: () => _showPlace(p, loc), child: _MapPin(icon: p.icon, color: green)),
                ),

            // where rain cells are heading (700 hPa steering wind)
            if (_radar && steer != null && steer.speed >= 3)
              Marker(
                point: loc.latLng,
                width: 120,
                height: 120,
                child: IgnorePointer(
                  child: Transform.rotate(
                    angle: ((steer.fromDir + 180) % 360) * math.pi / 180,
                    child: const Align(
                      alignment: Alignment.topCenter,
                      child: Icon(Icons.navigation, color: Color(0xFF7FD1FF), size: 34),
                    ),
                  ),
                ),
              ),
            Marker(point: loc.latLng, width: 48, height: 48, child: const _MapPin(icon: Icons.person_pin_circle, color: blue, big: true)),
          ]),
          const RichAttributionWidget(attributions: [
            TextSourceAttribution('© OpenStreetMap contributors'),
            TextSourceAttribution('Radar: RainViewer'),
            TextSourceAttribution('Wind: Open-Meteo'),
            TextSourceAttribution('Earthquakes: USGS'),
            TextSourceAttribution('Water level: ThaiWater (HII)'),
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
              _frames.isNotEmpty && _radar ? 'เรดาร์ฝน ${hhmm(_frames[_frame].time)} น. • ${loc.name}' : loc.name,
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
        bottom: 150,
        child: SingleChildScrollView(
          child: Column(children: [
            _LayerButton(
              icon: Icons.sos,
              label: 'SOS',
              on: true,
              color: red,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SosPage())),
            ),
            _LayerButton(
              icon: Icons.water_drop,
              label: 'ฝน',
              on: _radar,
              onTap: () => setState(() {
                _radar = !_radar;
                if (!_radar) _stopPlay();
              }),
            ),
            _LayerButton(
              icon: Icons.air,
              label: 'ลม',
              on: _wind,
              loading: _loadingWind,
              onTap: () {
                setState(() => _wind = !_wind);
                if (_wind) _loadWind();
              },
            ),
            _LayerButton(
              icon: Icons.vibration,
              label: 'แผ่นดินไหว',
              on: _quakes,
              onTap: () => setState(() {
                _quakes = !_quakes;
                if (!_quakes) _selected = null;
              }),
            ),
            _LayerButton(icon: Icons.waves, label: 'ระดับน้ำ', on: _water, onTap: () => setState(() => _water = !_water)),
            _LayerButton(icon: Icons.health_and_safety, label: 'จุดปลอดภัย', on: _places, onTap: () => setState(() => _places = !_places)),
            _LayerButton(icon: Icons.my_location, label: 'ตำแหน่ง', on: false, onTap: () => _map.move(loc.latLng, 11)),
            _LayerButton(
              icon: Icons.refresh,
              label: 'รีเฟรช',
              on: false,
              onTap: () {
                _loadRadar();
                _loadPlaces(loc);
                if (_wind) _loadWind();
                s.waterUpdated = null;
                s.refresh();
              },
            ),
          ]),
        ),
      ),

      // ---- bottom panels ----
      Positioned(
        left: 12,
        right: 12,
        bottom: 12,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_quakes) _quakeBar(s, loc),
          if (_water) _waterBar(s),
          if (_wind) _windLegend(),
          if (_radar) _radarBar(steer),
          _placesBar(loc),
        ]),
      ),
    ]);
  }

  Widget _box({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: navy.withValues(alpha: .9), borderRadius: BorderRadius.circular(14)),
        child: child,
      );

  Widget _radarBar(({double speed, double fromDir})? steer) {
    final hasFrames = _frames.isNotEmpty;
    final f = hasFrames ? _frames[_frame] : null;
    return _box(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          InkWell(
            onTap: hasFrames ? _togglePlay : null,
            child: Icon(_playing ? Icons.pause_circle : Icons.play_circle, color: blue, size: 30),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: hasFrames
                ? SliderTheme(
                    data: SliderTheme.of(context).copyWith(trackHeight: 3, overlayShape: SliderComponentShape.noOverlay),
                    child: Slider(
                      value: _frame.toDouble(),
                      min: 0,
                      max: math.max(1, _frames.length - 1).toDouble(),
                      divisions: math.max(1, _frames.length - 1),
                      onChanged: (v) => setState(() {
                        _stopPlay();
                        _frame = v.round();
                      }),
                    ),
                  )
                : const Text('กำลังโหลดเรดาร์...', style: TextStyle(fontSize: 11)),
          ),
          const SizedBox(width: 8),
          Text(
            f == null ? '' : '${hhmm(f.time)}${f.nowcast ? ' คาดการณ์' : ''}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: f?.nowcast == true ? amber : Colors.white),
          ),
        ]),
        Row(children: [
          const Text('ฝน', style: TextStyle(fontSize: 10)),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: const LinearGradient(colors: [Color(0xFF88DDEE), Color(0xFF0099CC), Color(0xFF005588), Color(0xFFFFEE00), Color(0xFFFF4400), Color(0xFFC10000)]),
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Text('เบา → หนัก', style: TextStyle(fontSize: 10, color: Colors.white60)),
        ]),
        if (steer != null && steer.speed >= 3) ...[
          const SizedBox(height: 6),
          Row(children: [
            Transform.rotate(
              angle: ((steer.fromDir + 180) % 360) * math.pi / 180,
              child: const Icon(Icons.navigation, color: Color(0xFF7FD1FF), size: 18),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'กลุ่มฝน/เมฆกำลังเคลื่อนไปทาง${compassThai((steer.fromDir + 180) % 360)} ~${steer.speed.round()} กม./ชม. (ลมระดับ 3 กม.)',
                style: const TextStyle(fontSize: 11.5),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _windLegend() => _box(
        child: Row(children: [
          const Icon(Icons.air, size: 18, color: Colors.white70),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _windSamples.isEmpty ? 'กำลังโหลดลม...' : 'ลูกศร = ทิศที่ลมพัดไป (ลมผิวพื้น 10 ม.) • ตัวเลข กม./ชม. • เลื่อนแผนที่แล้วอัปเดตเอง',
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ]),
      );

  Widget _waterBar(AppState s) {
    final counts = <int, int>{};
    for (final w in s.waterStations) {
      counts[w.situation] = (counts[w.situation] ?? 0) + 1;
    }
    return _box(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(
          s.waterStations.isEmpty
              ? 'ยังโหลดระดับน้ำไม่ได้ — กดรีเฟรช'
              : 'ระดับน้ำ ${s.waterStations.length} สถานี • ล้นตลิ่ง ${counts[5] ?? 0} • น้ำมาก ${counts[4] ?? 0}'
                  '${s.waterUpdated != null ? ' • ${hhmm(s.waterUpdated)} น.' : ''}',
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        const Wrap(spacing: 10, children: [
          LegendDot(color: Color(0xFFFF5D52), label: 'ล้นตลิ่ง'),
          LegendDot(color: Color(0xFFFF9F43), label: 'น้ำมาก'),
          LegendDot(color: Color(0xFF55D68B), label: 'ปกติ'),
          LegendDot(color: Color(0xFFFFE066), label: 'น้ำน้อย'),
        ]),
      ]),
    );
  }

  Widget _quakeBar(AppState s, AppLocation loc) => _box(
        child: Row(children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final p in QuakePeriod.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      labelStyle: const TextStyle(fontSize: 11),
                      label: Text(switch (p) {
                        QuakePeriod.day => '24 ชม.',
                        QuakePeriod.week => '7 วัน',
                        QuakePeriod.month => '30 วัน',
                        QuakePeriod.history => 'ประวัติ 50 ปี',
                      }),
                      selected: _period == p,
                      onSelected: (_) => _setPeriod(p),
                    ),
                  ),
              ]),
            ),
          ),
          if (_loadingQuakes || _loadingShake)
            const Padding(padding: EdgeInsets.only(left: 6), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'พื้นที่เสี่ยง',
            onPressed: _showRiskInfo,
            icon: const Icon(Icons.info_outline, size: 20),
          ),
        ]),
      );

  Widget _placesBar(AppLocation loc) => Material(
        color: panel,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _safePlaces.isEmpty ? null : () => _showPlacesList(loc),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              _loadingPlaces
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.health_and_safety, color: green),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _loadingPlaces && _safePlaces.isEmpty
                      ? 'กำลังค้นหาจุดปลอดภัย...'
                      : _placesError ??
                          (_safePlaces.isEmpty
                              ? 'ไม่พบจุดปลอดภัยในรัศมี 20 กม.'
                              : 'จุดปลอดภัยใกล้คุณ ${_safePlaces.length} แห่ง • ใกล้สุด ${distanceText(haversine(loc.lat, loc.lon, _safePlaces.first.lat, _safePlaces.first.lon))}'),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              if (_safePlaces.isNotEmpty) const Text('ดูทั้งหมด', style: TextStyle(color: blue, fontSize: 12)),
              if (_placesError != null) TextButton(onPressed: () => _loadPlaces(loc), child: const Text('ลองใหม่')),
            ]),
          ),
        ),
      );
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.sub = '', this.color});
  final String label, value, sub;
  final Color? color;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white60)),
          Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color)),
          if (sub.isNotEmpty) Text(sub, style: const TextStyle(fontSize: 10, color: Colors.white54)),
        ]),
      );
}

class _WindArrow extends StatelessWidget {
  const _WindArrow({required this.speed, required this.towardDeg});
  final double speed, towardDeg;
  @override
  Widget build(BuildContext context) {
    final c = speed >= 40
        ? red
        : speed >= 25
            ? amber
            : speed >= 10
                ? const Color(0xFF7FD1FF)
                : Colors.white70;
    return IgnorePointer(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Transform.rotate(
          angle: towardDeg * math.pi / 180,
          child: Icon(Icons.navigation, color: c, size: 24, shadows: const [Shadow(color: Colors.black, blurRadius: 4)]),
        ),
        Text('${speed.round()}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: c, shadows: const [Shadow(color: Colors.black, blurRadius: 3)])),
      ]),
    );
  }
}

class _LayerButton extends StatelessWidget {
  const _LayerButton({required this.icon, required this.label, required this.on, required this.onTap, this.color = blue, this.loading = false});
  final IconData icon;
  final String label;
  final bool on, loading;
  final Color color;
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
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: on ? color : Colors.white12)),
              child: Column(children: [
                loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(icon, size: 22, color: on ? color : Colors.white70),
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
