import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../app_state.dart';
import '../logic/format.dart';
import '../logic/suncalc.dart';
import '../theme.dart';
import '../widgets/common.dart';

class SkyPage extends StatefulWidget {
  const SkyPage({super.key});
  @override
  State<SkyPage> createState() => _SkyPageState();
}

class _SkyPageState extends State<SkyPage> {
  int _dayOffset = 0;
  Timer? _clock;
  DateTime _now = DateTime.now();

  List<MapEntry<DateTime, double>>? _tide;
  bool _tideLoading = false;
  bool _tideChecked = false;
  String? _tideFor;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final loc = AppScope.of(context).location;
    final key = '${loc.lat},${loc.lon}';
    if (_tideFor != key) {
      _tideFor = key;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadTide());
    }
  }

  Future<void> _loadTide() async {
    if (!mounted) return;
    final s = AppScope.read(context);
    setState(() => _tideLoading = true);
    try {
      final t = await s.api.fetchSeaLevel(s.location.lat, s.location.lon);
      if (mounted) setState(() => _tide = t);
    } catch (_) {
      if (mounted) setState(() => _tide = null);
    } finally {
      if (mounted) {
        setState(() {
          _tideLoading = false;
          _tideChecked = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppScope.of(context).location;
    final day = DateTime(_now.year, _now.month, _now.day).add(Duration(days: _dayOffset));
    final ref = _dayOffset == 0 ? _now : day.add(const Duration(hours: 12));
    final st = sunTimes(day, loc.lat, loc.lon);
    final sunNow = sunPosition(_now, loc.lat, loc.lon);
    final moonNow = moonPosition(_now, loc.lat, loc.lon);
    final illum = moonIllumination(ref);
    final mt = moonTimes(day, loc.lat, loc.lon);
    final riseAz = st.sunrise == null ? null : sunPosition(st.sunrise!, loc.lat, loc.lon).azimuth;
    final setAz = st.sunset == null ? null : sunPosition(st.sunset!, loc.lat, loc.lon).azimuth;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        PageHeader('ท้องฟ้า & ธรรมชาติ', subtitle: '${loc.name} • ${thaiDate(day)}'),
        Wrap(spacing: 8, children: [
          for (final o in const [0, 1, 2])
            ChoiceChip(
              label: Text(o == 0 ? 'วันนี้' : o == 1 ? 'พรุ่งนี้' : thaiShortDate(DateTime.now().add(Duration(days: o)))),
              selected: _dayOffset == o,
              onSelected: (_) => setState(() => _dayOffset = o),
            ),
        ]),
        const SizedBox(height: 10),

        // ---- sun ----
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(colors: [Color(0xFF315878), Color(0xFF3A2A45), Color(0xFF18243F)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          ),
          child: Column(children: [
            Row(children: [
              _TimeBox(label: 'พระอาทิตย์ขึ้น', time: st.sunrise, icon: Icons.wb_twilight, sub: riseAz == null ? null : 'ทิศ ${riseAz.round()}° ${compassShort(riseAz)}'),
              const Spacer(),
              _TimeBox(label: 'พระอาทิตย์ตก', time: st.sunset, icon: Icons.nights_stay, sub: setAz == null ? null : 'ทิศ ${setAz.round()}° ${compassShort(setAz)}', alignEnd: true),
            ]),
            SizedBox(
              height: 120,
              child: CustomPaint(
                size: Size.infinite,
                painter: _SunArcPainter(
                  fraction: _dayOffset != 0 || st.sunrise == null || st.sunset == null
                      ? null
                      : _now.difference(st.sunrise!).inSeconds / st.sunset!.difference(st.sunrise!).inSeconds,
                ),
              ),
            ),
            Text(
              _dayOffset == 0
                  ? (sunNow.altitude > 0
                      ? 'ตอนนี้ดวงอาทิตย์อยู่ทิศ${compassThai(sunNow.azimuth)} (${sunNow.azimuth.round()}°) สูง ${sunNow.altitude.round()}°'
                      : 'ดวงอาทิตย์อยู่ใต้ขอบฟ้า')
                  : 'กลางวันยาว ${st.dayLength?.inHours ?? '-'} ชม. ${(st.dayLength?.inMinutes ?? 0) % 60} นาที',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'แสงทอง เช้า ${hhmm(st.sunrise)}–${hhmm(st.goldenMorningEnd)} • เย็น ${hhmm(st.goldenEveningStart)}–${hhmm(st.sunset)}\n'
              'ฟ้าสาง ${hhmm(st.dawn)} • ฟ้ามืด ${hhmm(st.dusk)}',
              style: const TextStyle(color: amber, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ]),
        ),

        // ---- moon + tide ----
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Panel(
              child: Column(children: [
                SizedBox(width: 72, height: 72, child: CustomPaint(painter: _MoonPainter(illum.phase))),
                const SizedBox(height: 8),
                Text(illum.phaseName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center),
                Text('สว่าง ${(illum.fraction * 100).round()}%', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                Text(illum.thaiLunarDay, style: const TextStyle(fontSize: 10, color: Colors.white60)),
                const SizedBox(height: 4),
                Text('ขึ้น ${hhmm(mt.rise)} • ตก ${hhmm(mt.set)}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
              ]),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: _TideCard(series: _tide, loading: _tideLoading, checked: _tideChecked, day: day)),
        ]),

        // ---- compass ----
        const SectionTitle('เข็มทิศท้องฟ้า (Sky Compass)'),
        _SkyCompass(sunAz: sunNow.azimuth, sunAlt: sunNow.altitude, moonAz: moonNow.azimuth, moonAlt: moonNow.altitude),
        const Disclaimer('เวลาดวงอาทิตย์/ดวงจันทร์คำนวณในเครื่องจากพิกัด (คลาดเคลื่อน ~1–2 นาที) • ข้างขึ้น-ข้างแรมเป็นค่าประมาณทางดาราศาสตร์ อาจต่างจากปฏิทินจันทรคติไทย 1 วัน'),
      ],
    );
  }
}

class _TimeBox extends StatelessWidget {
  const _TimeBox({required this.label, required this.time, required this.icon, this.sub, this.alignEnd = false});
  final String label;
  final DateTime? time;
  final IconData icon;
  final String? sub;
  final bool alignEnd;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: amber, size: 18),
            const SizedBox(width: 6),
            Text(hhmm(time), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          ]),
          if (sub != null) Text(sub!, style: const TextStyle(fontSize: 10, color: Colors.white60)),
        ]),
      );
}

class _SunArcPainter extends CustomPainter {
  _SunArcPainter({this.fraction});
  final double? fraction; // 0..1 between sunrise and sunset, null = hide sun

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final baseY = h - 14;
    final horizon = Paint()
      ..color = Colors.white30
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, baseY), Offset(w, baseY), horizon);
    final rect = Rect.fromLTRB(w * .1, baseY - (h - 24), w * .9, baseY + (h - 24));
    final dash = Paint()
      ..color = Colors.white54
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    // dashed arc
    const segs = 30;
    for (var i = 0; i < segs; i += 2) {
      canvas.drawArc(rect, math.pi + math.pi * i / segs, math.pi / segs, false, dash);
    }
    final f = fraction;
    if (f != null && f >= 0 && f <= 1) {
      final a = math.pi + math.pi * f;
      final c = rect.center;
      final p = Offset(c.dx + rect.width / 2 * math.cos(a), c.dy + rect.height / 2 * math.sin(a));
      canvas.drawCircle(p, 14, Paint()..color = amber.withValues(alpha: .3));
      canvas.drawCircle(p, 8, Paint()..color = amber);
    }
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final e in [('E', w * .1), ('W', w * .9)]) {
      tp.text = TextSpan(text: e.$1, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold));
      tp.layout();
      tp.paint(canvas, Offset(e.$2 - tp.width / 2, baseY + 2));
    }
  }

  @override
  bool shouldRepaint(_SunArcPainter old) => old.fraction != fraction;
}

class _MoonPainter extends CustomPainter {
  _MoonPainter(this.phase);
  final double phase; // 0 new, .5 full

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = size.center(Offset.zero);
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF2A3346));
    // Lit region: semicircle on lit side + ellipse for terminator.
    final waxing = phase < .5;
    final k = math.cos(2 * math.pi * phase); // 1 new → -1 full
    final lit = Paint()..color = const Color(0xFFE9E4D4);
    // Semicircle on the lit side (right when waxing, as seen from Thailand).
    final semi = Rect.fromCircle(center: c, radius: r);
    final ell = Rect.fromCenter(center: c, width: 2 * r * k.abs(), height: 2 * r);
    final semiPath = Path()..addArc(semi, waxing ? -math.pi / 2 : math.pi / 2, math.pi);
    final ellPath = Path()..addOval(ell);
    final litPath = k > 0
        ? Path.combine(PathOperation.difference, semiPath, ellPath) // crescent
        : Path.combine(PathOperation.union, semiPath, ellPath); // gibbous
    canvas.drawPath(litPath, lit);
  }

  @override
  bool shouldRepaint(_MoonPainter old) => old.phase != phase;
}

class _TideCard extends StatelessWidget {
  const _TideCard({required this.series, required this.loading, required this.checked, required this.day});
  final List<MapEntry<DateTime, double>>? series;
  final bool loading, checked;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final s = series;
    Widget body;
    if (loading) {
      body = const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    } else if (s == null) {
      body = Text(
        checked ? 'ไม่มีข้อมูลระดับน้ำทะเลสำหรับพื้นที่นี้ (อาจอยู่ห่างชายฝั่ง)' : 'กำลังตรวจสอบ...',
        style: const TextStyle(fontSize: 12, color: Colors.white60),
      );
    } else {
      final dayPts = s.where((e) => e.key.year == day.year && e.key.month == day.month && e.key.day == day.day).toList();
      final extremes = <(DateTime, double, bool)>[];
      for (var i = 1; i < dayPts.length - 1; i++) {
        final a = dayPts[i - 1].value, b = dayPts[i].value, c = dayPts[i + 1].value;
        if (b > a && b >= c) extremes.add((dayPts[i].key, b, true));
        if (b < a && b <= c) extremes.add((dayPts[i].key, b, false));
      }
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(height: 60, child: CustomPaint(size: Size.infinite, painter: _TidePainter(dayPts.map((e) => e.value).toList()))),
        const SizedBox(height: 6),
        if (extremes.isEmpty) const Text('ไม่มีข้อมูลของวันนี้', style: TextStyle(fontSize: 12)),
        for (final e in extremes.take(4))
          Row(children: [
            Icon(e.$3 ? Icons.arrow_upward : Icons.arrow_downward, size: 16, color: e.$3 ? blue : red),
            const SizedBox(width: 4),
            Text(e.$3 ? 'น้ำขึ้น' : 'น้ำลง', style: const TextStyle(fontSize: 12)),
            const Spacer(),
            Text('${hhmm(e.$1)} (${e.$2 >= 0 ? '+' : ''}${e.$2.toStringAsFixed(2)} ม.)', style: TextStyle(fontSize: 12, color: e.$3 ? blue : red)),
          ]),
      ]);
    }
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('น้ำขึ้น-น้ำลง', style: TextStyle(fontWeight: FontWeight.bold, color: blue)),
        const SizedBox(height: 6),
        body,
        const SizedBox(height: 4),
        const Text('แบบจำลอง ±1 ชม. ไม่ใช่ตารางน้ำกรมอุทกศาสตร์', style: TextStyle(fontSize: 9, color: amber)),
      ]),
    );
  }
}

class _TidePainter extends CustomPainter {
  _TidePainter(this.values);
  final List<double> values;
  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final mn = values.reduce(math.min), mx = values.reduce(math.max);
    final span = (mx - mn).abs() < 1e-6 ? 1.0 : mx - mn;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - (values[i] - mn) / span * (size.height - 6) - 3;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = blue.withValues(alpha: .18));
    canvas.drawPath(path, Paint()
      ..color = blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    final now = DateTime.now();
    final nx = size.width * (now.hour + now.minute / 60) / 23;
    canvas.drawLine(Offset(nx, 0), Offset(nx, size.height), Paint()..color = Colors.white38);
  }

  @override
  bool shouldRepaint(_TidePainter old) => old.values != values;
}

/// Compass using magnetometer + accelerometer (tilt compensated).
class _SkyCompass extends StatefulWidget {
  const _SkyCompass({required this.sunAz, required this.sunAlt, required this.moonAz, required this.moonAlt});
  final double sunAz, sunAlt, moonAz, moonAlt;
  @override
  State<_SkyCompass> createState() => _SkyCompassState();
}

class _SkyCompassState extends State<_SkyCompass> {
  StreamSubscription<MagnetometerEvent>? _magSub;
  StreamSubscription<AccelerometerEvent>? _accSub;
  List<double> _acc = [0, 0, 9.8];
  double? _heading;
  bool _available = true;
  bool _active = false;

  void _start() {
    setState(() => _active = true);
    _accSub = accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen(
      (e) => _acc = [e.x, e.y, e.z],
      onError: (_) => setState(() => _available = false),
      cancelOnError: true,
    );
    _magSub = magnetometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen(
      (e) {
        final h = _computeHeading(_acc, [e.x, e.y, e.z]);
        if (h == null || !mounted) return;
        setState(() {
          if (_heading == null) {
            _heading = h;
          } else {
            // low-pass filter on the circle
            var d = h - _heading!;
            if (d > 180) d -= 360;
            if (d < -180) d += 360;
            _heading = (_heading! + d * .15 + 360) % 360;
          }
        });
      },
      onError: (_) => setState(() => _available = false),
      cancelOnError: true,
    );
  }

  void _stop() {
    _magSub?.cancel();
    _accSub?.cancel();
    setState(() {
      _active = false;
      _heading = null;
    });
  }

  /// Android-style getRotationMatrix → azimuth of the device's top edge.
  static double? _computeHeading(List<double> a, List<double> e) {
    final hx = e[1] * a[2] - e[2] * a[1];
    final hy = e[2] * a[0] - e[0] * a[2];
    final hz = e[0] * a[1] - e[1] * a[0];
    final normH = math.sqrt(hx * hx + hy * hy + hz * hz);
    if (normH < 0.1) return null;
    final ax = a[0], ay = a[1], az = a[2];
    final normA = math.sqrt(ax * ax + ay * ay + az * az);
    if (normA == 0) return null;
    final invA = 1 / normA;
    final invH = 1 / normH;
    final hyN = hy * invH;
    final axN = ax * invA, azN = az * invA;
    final hxN = hx * invH, hzN = hz * invH;
    final my = azN * hxN - axN * hzN;
    final az0 = math.atan2(hyN, my) * 180 / math.pi;
    return (az0 + 360) % 360;
  }

  @override
  void dispose() {
    _magSub?.cancel();
    _accSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final heading = _heading ?? 0;
    return Panel(
      child: Column(children: [
        SizedBox(
          height: 230,
          child: CustomPaint(
            size: Size.infinite,
            painter: _CompassPainter(
              heading: heading,
              sunAz: widget.sunAz,
              sunUp: widget.sunAlt > 0,
              moonAz: widget.moonAz,
              moonUp: widget.moonAlt > 0,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (!_available)
          const Text('เครื่องนี้ไม่มีเซนเซอร์เข็มทิศ', style: TextStyle(color: amber))
        else if (_active)
          Column(children: [
            Text('หันไปทิศ${compassThai(heading)} ${heading.round()}°', style: const TextStyle(fontWeight: FontWeight.bold)),
            const Text('วางโทรศัพท์ราบ ห่างโลหะ • โบกเป็นเลข 8 เพื่อปรับเทียบ', style: TextStyle(fontSize: 11, color: Colors.white60)),
            TextButton(onPressed: _stop, child: const Text('ปิดเข็มทิศ')),
          ])
        else
          FilledButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.explore),
            label: const Text('เปิดเข็มทิศ หาทิศดวงอาทิตย์/ดวงจันทร์'),
          ),
      ]),
    );
  }
}

class _CompassPainter extends CustomPainter {
  _CompassPainter({required this.heading, required this.sunAz, required this.sunUp, required this.moonAz, required this.moonUp});
  final double heading, sunAz, moonAz;
  final bool sunUp, moonUp;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 8;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF0C1E31));
    canvas.drawCircle(c, r, Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);

    Offset at(double bearing, double radius) {
      final a = (bearing - heading - 90) * math.pi / 180;
      return Offset(c.dx + radius * math.cos(a), c.dy + radius * math.sin(a));
    }

    final tick = Paint()
      ..color = Colors.white38
      ..strokeWidth = 1.5;
    for (var d = 0; d < 360; d += 15) {
      canvas.drawLine(at(d.toDouble(), r), at(d.toDouble(), r - (d % 90 == 0 ? 12 : 6)), tick);
    }
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final e in const [('N', 0.0), ('E', 90.0), ('S', 180.0), ('W', 270.0)]) {
      tp.text = TextSpan(text: e.$1, style: TextStyle(color: e.$1 == 'N' ? red : Colors.white, fontWeight: FontWeight.bold, fontSize: 15));
      tp.layout();
      final p = at(e.$2, r - 26);
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }

    void body(double az, bool up, Color color, String label) {
      final p = at(az, r - 50);
      canvas.drawLine(c, p, Paint()
        ..color = color.withValues(alpha: up ? .7 : .25)
        ..strokeWidth = 2);
      canvas.drawCircle(p, 13, Paint()..color = color.withValues(alpha: up ? 1 : .35));
      tp.text = TextSpan(text: label, style: const TextStyle(fontSize: 10, color: Colors.white));
      tp.layout();
      tp.paint(canvas, p + Offset(-tp.width / 2, 15));
    }

    body(moonAz, moonUp, const Color(0xFFE9E4D4), moonUp ? 'ดวงจันทร์' : 'ดวงจันทร์ (ใต้ขอบฟ้า)');
    body(sunAz, sunUp, amber, sunUp ? 'ดวงอาทิตย์' : 'ดวงอาทิตย์ (ใต้ขอบฟ้า)');

    // device direction marker
    final top = Offset(c.dx, c.dy - r - 2);
    final path = Path()
      ..moveTo(top.dx, top.dy + 14)
      ..lineTo(top.dx - 8, top.dy)
      ..lineTo(top.dx + 8, top.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = blue);
    canvas.drawCircle(c, 4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_CompassPainter old) =>
      old.heading != heading || old.sunAz != sunAz || old.moonAz != moonAz || old.sunUp != sunUp || old.moonUp != moonUp;
}
