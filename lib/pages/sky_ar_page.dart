import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../app_state.dart';
import '../logic/format.dart';
import '../logic/sky_projection.dart';
import '../logic/suncalc.dart';
import '../theme.dart';

/// AR sky view: live camera + sun/moon paths for the chosen day,
/// hour markers, horizon, compass ticks and a time scrubber.
class SkyArPage extends StatefulWidget {
  const SkyArPage({super.key, this.initialDate});
  final DateTime? initialDate;
  @override
  State<SkyArPage> createState() => _SkyArPageState();
}

class _SkyArPageState extends State<SkyArPage> with WidgetsBindingObserver {
  CameraController? _cam;
  String? _camError;
  bool _camStarting = false;

  StreamSubscription<AccelerometerEvent>? _accSub;
  StreamSubscription<MagnetometerEvent>? _magSub;
  List<double>? _g, _m; // low-passed sensor vectors
  DeviceOrientation3D? _orient;
  bool _sensorsOk = true;

  late DateTime _day; // local midnight of the selected day
  late int _minute; // minute of day being shown
  bool _followNow = true;
  Timer? _clock;
  double _vFov = 62; // degrees, adjustable

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final now = widget.initialDate ?? DateTime.now();
    _day = DateTime(now.year, now.month, now.day);
    _minute = DateTime.now().hour * 60 + DateTime.now().minute;
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_followNow && mounted) {
        final n = DateTime.now();
        setState(() {
          _day = DateTime(n.year, n.month, n.day);
          _minute = n.hour * 60 + n.minute;
        });
      }
    });
    _startSensors();
    _startCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    _accSub?.cancel();
    _magSub?.cancel();
    _cam?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _cam;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      if (c != null) {
        _cam = null;
        c.dispose();
        if (mounted) setState(() {});
      }
    } else if (state == AppLifecycleState.resumed && _cam == null && _camError == null) {
      _startCamera();
    }
  }

  Future<void> _startCamera() async {
    if (_camStarting) return;
    _camStarting = true;
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) throw CameraException('none', 'ไม่พบกล้อง');
      final back = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cams.first);
      final c = CameraController(back, ResolutionPreset.high, enableAudio: false);
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _cam = c;
        _camError = null;
      });
    } on CameraException catch (e) {
      if (mounted) {
        setState(() => _camError = e.code.contains('Denied') || e.code.contains('denied')
            ? 'ไม่ได้รับอนุญาตให้ใช้กล้อง — เปิดสิทธิ์ได้ที่การตั้งค่าแอป (ยังดูแผนท้องฟ้าแบบไม่มีกล้องได้)'
            : 'เปิดกล้องไม่ได้ (${e.description ?? e.code}) — แสดงท้องฟ้าจำลองแทน');
      }
    } catch (e) {
      if (mounted) setState(() => _camError = 'เปิดกล้องไม่ได้ — แสดงท้องฟ้าจำลองแทน');
    } finally {
      _camStarting = false;
    }
  }

  void _startSensors() {
    const a = 0.12; // low-pass factor
    List<double> lp(List<double>? prev, List<double> next) =>
        prev == null ? next : [for (var i = 0; i < 3; i++) prev[i] + a * (next[i] - prev[i])];
    _accSub = accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen(
      (e) => _g = lp(_g, [e.x, e.y, e.z]),
      onError: (_) => setState(() => _sensorsOk = false),
      cancelOnError: true,
    );
    _magSub = magnetometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen(
      (e) {
        _m = lp(_m, [e.x, e.y, e.z]);
        if (_g == null || !mounted) return;
        final o = DeviceOrientation3D.fromSensors(_g!, _m!);
        if (o != null) setState(() => _orient = o);
      },
      onError: (_) => setState(() => _sensorsOk = false),
      cancelOnError: true,
    );
  }

  DateTime get _time => _day.add(Duration(minutes: _minute));

  void _shiftDay(int d) => setState(() {
        _followNow = false;
        _day = _day.add(Duration(days: d));
      });

  void _backToNow() {
    final n = DateTime.now();
    setState(() {
      _followNow = true;
      _day = DateTime(n.year, n.month, n.day);
      _minute = n.hour * 60 + n.minute;
    });
  }

  void _showFovSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('ปรับเทียบ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                '1) โบกโทรศัพท์เป็นเลข 8 เพื่อปรับเทียบเข็มทิศ  2) เล็งดวงอาทิตย์/ดวงจันทร์จริง แล้วปรับมุมกล้องจนวงกลมตรงกับของจริง',
                style: TextStyle(fontSize: 13, color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Text('มุมรับภาพแนวตั้งของกล้อง: ${_vFov.round()}°'),
              Slider(
                value: _vFov,
                min: 35,
                max: 90,
                onChanged: (v) {
                  setSheet(() {});
                  setState(() => _vFov = v);
                },
              ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppScope.of(context).location;
    final t = _time;
    final sun = sunPosition(t, loc.lat, loc.lon);
    final moon = moonPosition(t, loc.lat, loc.lon);
    final st = sunTimes(_day, loc.lat, loc.lon);
    final mt = moonTimes(_day, loc.lat, loc.lon);
    final illum = moonIllumination(t);
    final cam = _cam;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // camera (cover)
        Positioned.fill(
          child: cam != null && cam.value.isInitialized
              ? ClipRect(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: cam.value.previewSize?.height ?? 1080,
                      height: cam.value.previewSize?.width ?? 1440,
                      child: CameraPreview(cam),
                    ),
                  ),
                )
              : Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF0B1E3A), Color(0xFF1E3B5C), Color(0xFF0A1420)],
                    ),
                  ),
                ),
        ),
        // overlay
        Positioned.fill(
          child: LayoutBuilder(builder: (ctx, c) {
            final size = Size(c.maxWidth, c.maxHeight);
            final previewAspect = cam != null && cam.value.isInitialized ? 1 / cam.value.aspectRatio : 0.75;
            return CustomPaint(
              painter: _SkyArPainter(
                orientation: _orient,
                focal: SkyProjector.focalFor(size, _vFov, previewAspect),
                lat: loc.lat,
                lon: loc.lon,
                day: _day,
                time: t,
              ),
            );
          }),
        ),

        // top bar
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              IconButton.filledTonal(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back)),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(loc.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      _orient == null
                          ? (_sensorsOk ? 'กำลังอ่านเซนเซอร์...' : 'เครื่องนี้ไม่มีเซนเซอร์ทิศ')
                          : () {
                              final d = _orient!.cameraDirection;
                              return 'กล้องชี้ ${d.$1.round()}° ${compassShort(d.$1)} • มุมเงย ${d.$2.round()}°';
                            }(),
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(onPressed: _showFovSheet, icon: const Icon(Icons.tune)),
            ]),
          ),
        ),

        if (_camError != null)
          Positioned(
            left: 16,
            right: 16,
            top: 110,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
              child: Text(_camError!, style: const TextStyle(color: amber, fontSize: 12)),
            ),
          ),

        // bottom panel
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            color: Colors.black.withValues(alpha: .78),
            child: SafeArea(
              top: false,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                  child: Row(children: [
                    _Info('ดวงอาทิตย์', '${sun.azimuth.toStringAsFixed(1)}°', '${sun.altitude >= 0 ? '+' : ''}${sun.altitude.toStringAsFixed(1)}°', amber),
                    _Info(
                      'ขึ้น',
                      hhmm(st.sunrise),
                      st.sunrise == null ? '' : '${sunPosition(st.sunrise!, loc.lat, loc.lon).azimuth.toStringAsFixed(1)}°',
                      const Color(0xFFFF9F43),
                    ),
                    _Info(
                      'ตก',
                      hhmm(st.sunset),
                      st.sunset == null ? '' : '${sunPosition(st.sunset!, loc.lat, loc.lon).azimuth.toStringAsFixed(1)}°',
                      red,
                    ),
                    _Info('ดวงจันทร์', '${moon.azimuth.toStringAsFixed(1)}°', '${moon.altitude >= 0 ? '+' : ''}${moon.altitude.toStringAsFixed(1)}°', const Color(0xFF7FD1FF)),
                    _Info('จันทร์ขึ้น', hhmm(mt.rise), mt.rise == null ? '' : '${moonPosition(mt.rise!, loc.lat, loc.lon).azimuth.round()}°', const Color(0xFF7FD1FF)),
                    _Info('จันทร์ตก', hhmm(mt.set), '${(illum.fraction * 100).round()}% สว่าง', const Color(0xFF7FD1FF)),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(children: [
                    IconButton(onPressed: () => _shiftDay(-1), icon: const Icon(Icons.chevron_left)),
                    Expanded(
                      child: InkWell(
                        onTap: _backToNow,
                        child: Column(children: [
                          Text('${thaiShortDate(_day)} ${_day.year + 543}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                          Text(hhmm(t), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                          if (!_followNow) const Text('แตะเพื่อกลับเป็น "ตอนนี้"', style: TextStyle(fontSize: 10, color: amber)),
                        ]),
                      ),
                    ),
                    IconButton(onPressed: () => _shiftDay(1), icon: const Icon(Icons.chevron_right)),
                  ]),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(trackHeight: 6, activeTrackColor: amber, inactiveTrackColor: const Color(0xFF1E3B5C)),
                  child: Slider(
                    value: _minute.toDouble(),
                    min: 0,
                    max: 1439,
                    onChanged: (v) => setState(() {
                      _followNow = false;
                      _minute = v.round();
                    }),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Text('⚠️ อย่ามองดวงอาทิตย์ตรง ๆ ผ่านกล้องหรือด้วยตาเปล่า', style: TextStyle(fontSize: 10.5, color: Colors.white54)),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.v1, this.v2, this.color);
  final String label, v1, v2;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        width: 92,
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: color, width: 3)), color: Colors.white.withValues(alpha: .05)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          Text(v1, style: const TextStyle(fontSize: 12)),
          if (v2.isNotEmpty) Text(v2, style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ]),
      );
}

class _SkyArPainter extends CustomPainter {
  _SkyArPainter({required this.orientation, required this.focal, required this.lat, required this.lon, required this.day, required this.time});
  final DeviceOrientation3D? orientation;
  final double focal, lat, lon;
  final DateTime day, time;

  static const sunColor = Color(0xFFFFC857);
  static const moonColor = Color(0xFF7FD1FF);

  @override
  void paint(Canvas canvas, Size size) {
    final o = orientation;
    if (o == null) return;
    final p = SkyProjector(orientation: o, size: size, focalPx: focal);
    final tp = TextPainter(textDirection: TextDirection.ltr);
    void label(String s, Offset at, {Color color = Colors.white, double fs = 13, bool bold = false, Offset shift = Offset.zero}) {
      tp.text = TextSpan(
        text: s,
        style: TextStyle(color: color, fontSize: fs, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, shadows: const [Shadow(color: Colors.black, blurRadius: 4)]),
      );
      tp.layout();
      tp.paint(canvas, at + shift - Offset(tp.width / 2, tp.height / 2));
    }

    // polyline helper that breaks when points go behind the camera or jump
    void path(List<Offset?> pts, Paint paint) {
      final path = Path();
      Offset? prev;
      for (final q in pts) {
        if (q == null || (prev != null && (q - prev).distance > size.longestSide)) {
          prev = null;
          if (q == null) continue;
        }
        if (prev == null) {
          path.moveTo(q.dx, q.dy);
        } else {
          path.lineTo(q.dx, q.dy);
        }
        prev = q;
      }
      canvas.drawPath(path, paint);
    }

    // altitude grid
    final grid = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (final alt in [30.0, 60.0]) {
      path([for (var az = 0.0; az <= 360; az += 3) p.project(az, alt)], grid);
    }
    // azimuth ticks + labels, horizon
    final horizon = Paint()
      ..color = const Color(0xFF55D68B)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    path([for (var az = 0.0; az <= 360; az += 2) p.project(az, 0)], horizon);
    const cardinals = {0: 'N', 45: 'NE', 90: 'E', 135: 'SE', 180: 'S', 225: 'SW', 270: 'W', 315: 'NW'};
    for (var az = 0; az < 360; az += 15) {
      final a = p.project(az.toDouble(), 0);
      final b = p.project(az.toDouble(), az % 45 == 0 ? 4 : 2);
      if (a != null && b != null) canvas.drawLine(a, b, horizon..strokeWidth = 2);
      final c = cardinals[az];
      if (c != null) {
        final l = p.project(az.toDouble(), -4);
        if (l != null) label(c, l, fs: 26, bold: true, color: c == 'N' ? red : Colors.white);
      } else if (az % 15 == 0) {
        final l = p.project(az.toDouble(), 6);
        if (l != null) label('$az°', l, fs: 15);
      }
    }
    horizon.strokeWidth = 3;

    // daily paths
    void bodyPath(Color color, ({double azimuth, double altitude}) Function(DateTime) pos, {required bool isSun}) {
      final line = Paint()
        ..color = color.withValues(alpha: .9)
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final pts = <Offset?>[];
      for (var m = 0; m <= 24 * 60; m += 10) {
        final q = pos(day.add(Duration(minutes: m)));
        pts.add(q.altitude < -8 ? null : p.project(q.azimuth, q.altitude));
      }
      path(pts, line);
      for (var hr = 0; hr <= 24; hr++) {
        final q = pos(day.add(Duration(hours: hr)));
        if (q.altitude < -8) continue;
        final at = p.project(q.azimuth, q.altitude);
        if (at == null) continue;
        canvas.drawCircle(at, 9, Paint()..color = color);
        canvas.drawCircle(at, 9, Paint()
          ..color = Colors.black54
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
        label('${hr.toString().padLeft(2, '0')}:00', at, color: color, fs: 14, bold: true, shift: Offset(isSun ? 30 : -30, -14));
      }
      final now = pos(time);
      final at = p.project(now.azimuth, now.altitude);
      if (at != null) {
        canvas.drawCircle(at, isSun ? 34 : 24, Paint()..color = color.withValues(alpha: isSun ? .55 : .5));
        canvas.drawCircle(at, isSun ? 34 : 24, Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
        label(isSun ? 'ดวงอาทิตย์' : 'ดวงจันทร์', at, fs: 12, bold: true, shift: Offset(0, isSun ? 46 : 36));
      }
    }

    bodyPath(moonColor, (t) {
      final q = moonPosition(t, lat, lon);
      return (azimuth: q.azimuth, altitude: q.altitude);
    }, isSun: false);
    bodyPath(sunColor, (t) {
      final q = sunPosition(t, lat, lon);
      return (azimuth: q.azimuth, altitude: q.altitude);
    }, isSun: true);

    // crosshair
    final c = size.center(Offset.zero);
    final ch = Paint()
      ..color = const Color(0xFF55D68B)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(c, 26, ch);
    canvas.drawLine(c - const Offset(40, 0), c + const Offset(40, 0), ch);
    canvas.drawLine(c - const Offset(0, 40), c + const Offset(0, 40), ch);
    final d = o.cameraDirection;
    label('${d.$1.toStringAsFixed(1)}° ${d.$2 >= 0 ? '+' : ''}${d.$2.toStringAsFixed(1)}°', c, fs: 14, bold: true, shift: const Offset(70, 34));
  }

  @override
  bool shouldRepaint(_SkyArPainter old) =>
      old.orientation != orientation || old.focal != focal || old.time != time || old.day != day || old.lat != lat;
}
