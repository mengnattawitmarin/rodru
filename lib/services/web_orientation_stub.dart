import 'dart:async';

/// One `deviceorientation` reading (degrees). [compassHeading] is iOS's
/// `webkitCompassHeading` (0 = north, clockwise) when available.
class WebOrientationReading {
  final double alpha, beta, gamma;
  final double? compassHeading;
  final bool absolute;
  const WebOrientationReading(this.alpha, this.beta, this.gamma, {this.compassHeading, this.absolute = false});
}

bool get webOrientationSupported => false;

/// Must be called from a user gesture on iOS. Returns true if granted.
Future<bool> requestWebOrientationPermission() async => false;

Stream<WebOrientationReading> webOrientationStream() => const Stream.empty();
