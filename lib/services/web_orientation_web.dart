import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'web_orientation_stub.dart' show WebOrientationReading;

export 'web_orientation_stub.dart' show WebOrientationReading;

bool get webOrientationSupported => globalContext.has('DeviceOrientationEvent');

Future<bool> requestWebOrientationPermission() async {
  final doe = globalContext['DeviceOrientationEvent'];
  if (doe == null) return false;
  final obj = doe as JSObject;
  if (!obj.has('requestPermission')) return true; // Android/desktop browsers: no prompt needed
  try {
    final res = await (obj.callMethod<JSPromise<JSString>>('requestPermission'.toJS)).toDart;
    return res.toDart == 'granted';
  } catch (_) {
    return false;
  }
}

Stream<WebOrientationReading> webOrientationStream() {
  late StreamController<WebOrientationReading> c;
  JSFunction? jsHandler;
  void handler(web.Event e) {
    final o = e as web.DeviceOrientationEvent;
    final a = o.alpha, b = o.beta, g = o.gamma;
    if (a == null || b == null || g == null) return;
    final raw = e as JSObject;
    final h = raw['webkitCompassHeading'];
    final heading = h == null ? null : (h as JSNumber).toDartDouble;
    c.add(WebOrientationReading(a, b, g, compassHeading: heading, absolute: o.absolute));
  }

  c = StreamController<WebOrientationReading>(
    onListen: () {
      jsHandler = handler.toJS;
      // Prefer the absolute (north-referenced) event where the browser has it.
      web.window.addEventListener('deviceorientationabsolute', jsHandler);
      web.window.addEventListener('deviceorientation', jsHandler);
    },
    onCancel: () {
      if (jsHandler != null) {
        web.window.removeEventListener('deviceorientationabsolute', jsHandler);
        web.window.removeEventListener('deviceorientation', jsHandler);
      }
    },
  );
  return c.stream;
}
