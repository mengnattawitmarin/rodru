import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

/// Device orientation from gravity (accelerometer) + geomagnetic field,
/// following Android's SensorManager.getRotationMatrix().
///
/// Device axes: x → right edge, y → top edge, z → out of the screen.
/// The back camera looks along −z.
class DeviceOrientation3D {
  /// World axes expressed in device coordinates (unit vectors).
  final List<double> east, north, up;
  const DeviceOrientation3D(this.east, this.north, this.up);

  static DeviceOrientation3D? fromSensors(List<double> gravity, List<double> magnetic) {
    final a = gravity, e = magnetic;
    var hx = e[1] * a[2] - e[2] * a[1];
    var hy = e[2] * a[0] - e[0] * a[2];
    var hz = e[0] * a[1] - e[1] * a[0];
    final nh = math.sqrt(hx * hx + hy * hy + hz * hz);
    final na = math.sqrt(a[0] * a[0] + a[1] * a[1] + a[2] * a[2]);
    if (nh < 0.1 || na < 0.1) return null; // free fall or near magnetic pole
    hx /= nh;
    hy /= nh;
    hz /= nh;
    final ax = a[0] / na, ay = a[1] / na, az = a[2] / na;
    final mx = ay * hz - az * hy;
    final my = az * hx - ax * hz;
    final mz = ax * hy - ay * hx;
    return DeviceOrientation3D([hx, hy, hz], [mx, my, mz], [ax, ay, az]);
  }

  /// From W3C DeviceOrientation Euler angles (degrees). [alphaDeg] must be
  /// referenced to north (absolute); on iOS use 360 − webkitCompassHeading.
  static DeviceOrientation3D fromEuler(double alphaDeg, double betaDeg, double gammaDeg) {
    const d = math.pi / 180;
    final cA = math.cos(alphaDeg * d), sA = math.sin(alphaDeg * d);
    final cB = math.cos(betaDeg * d), sB = math.sin(betaDeg * d);
    final cG = math.cos(gammaDeg * d), sG = math.sin(gammaDeg * d);
    // Rows of the device→earth rotation matrix = earth axes in device coords.
    return DeviceOrientation3D(
      [cA * cG - sA * sB * sG, -cB * sA, cA * sG + cG * sA * sB],
      [cG * sA + cA * sB * sG, cA * cB, sA * sG - cA * cG * sB],
      [-cB * sG, sB, cB * cG],
    );
  }

  /// Converts a sky direction (compass azimuth°, altitude°) to device coords.
  List<double> toDevice(double azDeg, double altDeg) {
    final az = azDeg * math.pi / 180, alt = altDeg * math.pi / 180;
    final we = math.cos(alt) * math.sin(az);
    final wn = math.cos(alt) * math.cos(az);
    final wu = math.sin(alt);
    return [
      we * east[0] + wn * north[0] + wu * up[0],
      we * east[1] + wn * north[1] + wu * up[1],
      we * east[2] + wn * north[2] + wu * up[2],
    ];
  }

  /// Where the back camera points: (azimuth°, altitude°).
  (double, double) get cameraDirection {
    final e = -east[2], n = -north[2], u = -up[2];
    final az = (math.atan2(e, n) * 180 / math.pi + 360) % 360;
    final alt = math.asin(u.clamp(-1.0, 1.0)) * 180 / math.pi;
    return (az, alt);
  }
}

/// Pinhole projection onto the screen.
class SkyProjector {
  SkyProjector({required this.orientation, required this.size, required this.focalPx, this.azOffset = 0});

  final DeviceOrientation3D orientation;
  final Size size;
  final double focalPx;

  /// Compass error correction (deg): measured camera azimuth − true azimuth.
  /// Set by aiming at the real sun/moon (see the calibration sheet).
  final double azOffset;

  /// Focal length (px) for a preview that covers [screen] with the camera's
  /// vertical field of view [vFovDeg] along the long (portrait height) side.
  static double focalFor(Size screen, double vFovDeg, double previewPortraitAspect) {
    // preview is scaled to cover the screen ("BoxFit.cover")
    final previewH = math.max(screen.height, screen.width / previewPortraitAspect);
    return (previewH / 2) / math.tan(vFovDeg * math.pi / 360);
  }

  /// Screen point, or null if the direction is behind the camera.
  Offset? project(double azDeg, double altDeg) {
    final v = orientation.toDevice(azDeg + azOffset, altDeg);
    final depth = -v[2];
    if (depth < 0.05) return null;
    return Offset(size.width / 2 + focalPx * v[0] / depth, size.height / 2 - focalPx * v[1] / depth);
  }
}

/// Normalises an angle difference to (−180, 180].
double wrap180(double deg) {
  var d = deg % 360;
  if (d > 180) d -= 360;
  if (d <= -180) d += 360;
  return d;
}
