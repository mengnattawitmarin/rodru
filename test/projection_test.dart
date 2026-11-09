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

  test('web Euler angles: upright facing north matches sensor orientation', () {
    final e = DeviceOrientation3D.fromEuler(0, 90, 0);
    final d = e.cameraDirection;
    expect(d.$1 < 1 || d.$1 > 359, isTrue);
    expect(d.$2.abs(), lessThan(1));
    // facing east: iOS heading 90 → alpha 270
    final east = DeviceOrientation3D.fromEuler(270, 90, 0).cameraDirection;
    expect(east.$1, closeTo(90, 1));
    // tilted up 30°
    expect(DeviceOrientation3D.fromEuler(0, 120, 0).cameraDirection.$2, closeTo(30, 1));
  });

  test('azimuth offset corrects a constant compass error', () {
    // compass reads 10° too high: phone thinks it faces 10°, really faces 0°
    final p = SkyProjector(orientation: o, size: const Size(400, 800), focalPx: 500, azOffset: -10);
    // a body truly at 350° should now be drawn at the centre... (o faces 0°, offset -10 → az 10 maps to centre)
    expect(p.project(10, 0)!.dx, closeTo(200, .5));
    expect(wrap180(350 - 0), closeTo(-10, .001));
    expect(wrap180(190), closeTo(-170, .001));
  });
}
