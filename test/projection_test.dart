import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:rodru/logic/sky_projection.dart';

void main() {
  // Phone upright (portrait), back camera facing north; field dips 15° down.
  final o = DeviceOrientation3D.fromSensors([0, 9.8, 0], [0, -0.26, -0.97])!;

  test('camera direction is north and level', () {
    final d = o.cameraDirection;
    expect(d.$1 < 1 || d.$1 > 359, isTrue);
    expect(d.$2.abs(), lessThan(1));
  });

  test('projection: east is to the right, up is up, behind is null', () {
    final p = SkyProjector(orientation: o, size: const Size(400, 800), focalPx: 500);
    final center = p.project(0, 0)!;
    expect(center.dx, closeTo(200, .5));
    expect(center.dy, closeTo(400, .5));
    expect(p.project(10, 0)!.dx, greaterThan(200));
    expect(p.project(0, 10)!.dy, lessThan(400));
    expect(p.project(180, 0), isNull);
  });
}
